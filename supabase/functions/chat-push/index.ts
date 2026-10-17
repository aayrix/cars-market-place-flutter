import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'npm:@supabase/supabase-js@2';

type ChatMessageInsert = {
  type?: string;
  table?: string;
  schema?: string;
  record?: {
    id?: string;
    thread_id?: string;
    sender_id?: string;
    sender_name?: string;
  };
};

const encodeBase64Url = (value: Uint8Array | string) => {
  const bytes = typeof value === 'string' ? new TextEncoder().encode(value) : value;
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/, '');
};

const decodePem = (pem: string) => {
  const base64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s/g, '');
  const binary = atob(base64);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
};

async function getFcmAccessToken(account: {
  client_email: string;
  private_key: string;
}) {
  const now = Math.floor(Date.now() / 1000);
  const header = encodeBase64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claim = encodeBase64Url(JSON.stringify({
    iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${claim}`;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    decodePem(account.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${encodeBase64Url(new Uint8Array(signature))}`;
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  const result = await response.json();
  if (!response.ok || typeof result.access_token !== 'string') {
    throw new Error(`FCM OAuth failed (${response.status}).`);
  }
  return result.access_token as string;
}

function constantTimeEqual(left: string, right: string) {
  const a = new TextEncoder().encode(left);
  const b = new TextEncoder().encode(right);
  if (a.length !== b.length || a.length === 0) return false;
  let mismatch = 0;
  for (let i = 0; i < a.length; i++) mismatch |= a[i] ^ b[i];
  return mismatch === 0;
}

serve(async (request) => {
  if (request.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const webhookSecret = Deno.env.get('CHAT_WEBHOOK_SECRET') ?? '';
  if (!constantTimeEqual(request.headers.get('x-webhook-secret') ?? '', webhookSecret)) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const payload = await request.json() as ChatMessageInsert;
  if (
    payload.type !== 'INSERT' || payload.schema !== 'public' ||
    payload.table !== 'chat_messages' || !payload.record?.thread_id ||
    !payload.record.sender_id
  ) {
    return new Response(JSON.stringify({ ignored: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SERVICE_ROLE_KEY');
  const rawAccount = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON');
  if (!supabaseUrl || !serviceRoleKey || !rawAccount) {
    console.error('Chat push server secrets are not configured.');
    return new Response(JSON.stringify({ error: 'Push service is not configured.' }), {
      status: 503,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  try {
    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: thread, error: threadError } = await admin
      .from('chat_threads')
      .select('id,listing_id,listing_title,buyer_id,buyer_name,seller_id,seller_name')
      .eq('id', payload.record.thread_id)
      .maybeSingle();
    if (threadError) throw threadError;
    if (!thread) return new Response(JSON.stringify({ ignored: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });

    const senderId = payload.record.sender_id;
    const senderIsBuyer = senderId === thread.buyer_id;
    const senderIsSeller = senderId === thread.seller_id;
    if (!senderIsBuyer && !senderIsSeller) {
      return new Response(JSON.stringify({ ignored: true }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    }
    const recipientId = senderIsBuyer ? thread.seller_id : thread.buyer_id;
    const senderName = senderIsBuyer ? thread.buyer_name : thread.seller_name;
    const { data: devices, error: devicesError } = await admin
      .from('push_tokens')
      .select('token')
      .eq('user_id', recipientId);
    if (devicesError) throw devicesError;
    if (!devices?.length) return new Response(JSON.stringify({ sent: 0 }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });

    const account = JSON.parse(rawAccount) as {
      project_id: string;
      client_email: string;
      private_key: string;
    };
    const accessToken = await getFcmAccessToken(account);
    const notificationData = {
      thread_id: `${thread.id}`,
      listing_id: `${thread.listing_id}`,
      listing_title: `${thread.listing_title ?? 'Listing'}`,
      buyer_id: `${thread.buyer_id}`,
      buyer_name: `${thread.buyer_name ?? 'Buyer'}`,
      seller_id: `${thread.seller_id}`,
      seller_name: `${thread.seller_name ?? 'Seller'}`,
    };
    const invalidTokens: string[] = [];
    let sent = 0;

    for (const device of devices) {
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(account.project_id)}/messages:send`,
        {
          method: 'POST',
          headers: {
            authorization: `Bearer ${accessToken}`,
            'content-type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token: device.token,
              notification: {
                title: `New message from ${senderName || 'Apni Gari user'}`,
                body: `You have a new message about ${thread.listing_title || 'a listing'}.`,
              },
              data: notificationData,
              android: { priority: 'high', notification: { channel_id: 'chat_messages' } },
            },
          }),
        },
      );
      if (response.ok) {
        sent++;
      } else {
        const result = await response.json().catch(() => ({}));
        const code = result?.error?.details?.find?.(
          (item: { errorCode?: string }) => item.errorCode,
        )?.errorCode;
        if (code === 'UNREGISTERED' || response.status === 404) {
          invalidTokens.push(device.token);
        } else {
          console.error('FCM delivery failed:', response.status, result?.error?.status);
        }
      }
    }

    if (invalidTokens.length) {
      await admin.from('push_tokens').delete().in('token', invalidTokens);
    }
    return new Response(JSON.stringify({ sent }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('Could not send chat notification:', error);
    return new Response(JSON.stringify({ error: 'Could not send notification.' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});

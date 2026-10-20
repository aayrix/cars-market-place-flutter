import { createClient } from 'npm:@supabase/supabase-js@2';
import { RtcRole, RtcTokenBuilder } from 'npm:agora-token@2.0.7';

Deno.serve(async (request: Request) => {
  if (request.method !== 'POST') {
    return Response.json({ error: 'Method not allowed.' }, { status: 405 });
  }

  const authorization = request.headers.get('Authorization') ?? '';
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const appId = Deno.env.get('AGORA_APP_ID')?.trim();
  const appCertificate = Deno.env.get('AGORA_APP_CERTIFICATE')?.trim();

  if (!supabaseUrl || !anonKey || !serviceRoleKey || !appId || !appCertificate) {
    const missing = [
      ['SUPABASE_URL', supabaseUrl],
      ['SUPABASE_ANON_KEY', anonKey],
      ['SUPABASE_SERVICE_ROLE_KEY', serviceRoleKey],
      ['AGORA_APP_ID', appId],
      ['AGORA_APP_CERTIFICATE', appCertificate],
    ].filter(([, value]) => !value).map(([name]) => name);
    console.error('agora-call-token: required environment variables are missing', missing);
    return Response.json({ error: 'Agora call service is not configured.' }, { status: 503 });
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: { user }, error: authError } = await userClient.auth.getUser();
  if (authError || !user) {
    return Response.json({ error: 'Sign in to join this call.' }, { status: 401 });
  }

  let callId = '';
  try {
    const body = await request.json();
    callId = typeof body.call_id === 'string' ? body.call_id : '';
  } catch {
    return Response.json({ error: 'Invalid request.' }, { status: 400 });
  }
  if (!callId) return Response.json({ error: 'Call ID is required.' }, { status: 400 });

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: call, error } = await admin
    .from('chat_calls')
    .select('id,room_name,caller_id,callee_id,status')
    .eq('id', callId)
    .maybeSingle();

  if (error || !call || ![call.caller_id, call.callee_id].includes(user.id)) {
    console.error('agora-call-token: call lookup or participant check failed', error?.message ?? 'Call not found or user is not a participant');
    return Response.json({ error: 'Call not found.' }, { status: 404 });
  }
  if (!['ringing', 'accepted'].includes(call.status)) {
    return Response.json({ error: 'This call has ended.' }, { status: 409 });
  }

  try {
    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      appCertificate,
      call.room_name,
      0,
      RtcRole.PUBLISHER,
      3600,
      3600,
    );
    return Response.json({
      app_id: appId,
      channel_name: call.room_name,
      token,
    });
  } catch (error) {
    console.error('agora-call-token: Agora token creation failed', error);
    return Response.json({ error: 'Could not create Agora call access.' }, { status: 500 });
  }
});

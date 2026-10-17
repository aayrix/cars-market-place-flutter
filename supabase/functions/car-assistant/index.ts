import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { GoogleGenerativeAI } from 'https://esm.sh/@google/generative-ai@0.7.0';

/* ------------------------------------------------------------------ */
/*  CORS headers — allows the Flutter app to call this function       */
/* ------------------------------------------------------------------ */
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json',
};

/* ------------------------------------------------------------------ */
/*  System prompt — Pakistani car-buying assistant                    */
/* ------------------------------------------------------------------ */
const SYSTEM_PROMPT = `
You are Apni Gari Assistant, an AI car-buying helper for Mianwali, Pakistan.

Your job is to help users with:
- Car recommendations based on budget (in PKR)
- Comparisons between car models
- Fuel economy and maintenance advice
- Petrol, hybrid, automatic vs manual comparisons
- Advice for first-time buyers in Pakistan
- General questions about buying used cars

Rules:
1. Always use PKR (Pakistani Rupees) when mentioning prices.
2. Keep answers focused on the Pakistani market (Mianwali, Punjab, Pakistan).
3. Do NOT invent specific prices, specifications, or marketplace listings.
4. Do NOT claim to access live inventory unless you have real data.
5. If you don't know something, say so honestly.
6. Be helpful, concise, and friendly.
7. Suggest meeting in safe public places and verifying documents before payment.
`;

/* ------------------------------------------------------------------ */
/*  Main handler                                                      */
/* ------------------------------------------------------------------ */
serve(async (req) => {
  /* Handle CORS preflight */
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  /* Only allow POST */
  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed. Use POST.' }),
      { status: 405, headers: corsHeaders },
    );
  }

  try {
    /* Parse request body */
    const body = await req.json();
    const message: string = body?.message;

    if (!message || typeof message !== 'string' || message.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: 'A "message" field is required.' }),
        { status: 400, headers: corsHeaders },
      );
    }

    /* Guard against excessively long prompts */
    if (message.length > 2000) {
      return new Response(
        JSON.stringify({ error: 'Message is too long. Please keep it under 2000 characters.' }),
        { status: 400, headers: corsHeaders },
      );
    }

    /* Read Gemini API key from environment */
    const apiKey = Deno.env.get('GEMINI_API_KEY');
    if (!apiKey) {
      console.error('GEMINI_API_KEY is not set');
      return new Response(
        JSON.stringify({ error: 'Assistant is not configured on the server.' }),
        { status: 500, headers: corsHeaders },
      );
    }

    /* Call Gemini */
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

    const fullPrompt = `${SYSTEM_PROMPT}\n\nUser: ${message.trim()}`;

    const result = await model.generateContent(fullPrompt);
    const response = await result.response;
    const text = response.text();

    if (!text || text.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: 'The assistant returned an empty response.' }),
        { status: 502, headers: corsHeaders },
      );
    }

    /* Return the reply */
    return new Response(
      JSON.stringify({ reply: text.trim() }),
      { status: 200, headers: corsHeaders },
    );
  } catch (error: any) {
    console.error('car-assistant error:', error);

    /* Rate limit / quota from Gemini */
    if (error?.message?.includes('429') ||
        error?.message?.includes('quota') ||
        error?.message?.includes('rate limit')) {
      return new Response(
        JSON.stringify({ error: 'The assistant is busy. Please try again shortly.' }),
        { status: 429, headers: corsHeaders },
      );
    }

    return new Response(
      JSON.stringify({ error: 'The assistant encountered an error. Please try again.' }),
      { status: 500, headers: corsHeaders },
    );
  }
});

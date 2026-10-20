# Apni Gari voice and video calls with Agora

Voice and video calls use Agora, Supabase for call signaling, and a Supabase Edge
Function to issue short-lived Agora RTC tokens. The Agora App Certificate stays
in Supabase and is never included in the Flutter app.

## Agora setup

1. Create a project in the [Agora Console](https://console.agora.io/).
2. Copy that project's **App ID** and enable its **Primary Certificate**. Copy
   the **App Certificate** too. Keep both values private.
3. In Supabase Dashboard → Edge Functions → Secrets, add:
   - `AGORA_APP_ID` — the Agora project's App ID
   - `AGORA_APP_CERTIFICATE` — the matching App Certificate
4. From the linked project directory, deploy the token function:

   ```sh
   npx --yes supabase@latest functions deploy agora-call-token
   ```

5. Run `flutter pub get`, build the Android or iOS app, and install it on both
   callers' phones. Allow microphone access when asked.
6. To try a call, both people should sign in and open the same one-to-one chat.
   Tap the phone icon for voice or the video icon for video, then answer on the
   other phone. Allow camera access for video calls.

Agora's RTC token is scoped to the generated channel and expires after one hour.
The app requests a fresh token from the authenticated Edge Function when needed.
The function checks that the caller is a participant in an active call before
issuing any token.

## Existing Supabase call table

The existing `public.chat_calls` table and its Realtime policies continue to
handle ringing, answer/decline, and hang up. If the table has not been installed
in this Supabase project yet, run `supabase/voice_calls.sql` once in the SQL
Editor. Existing installations should also run the script again to add the
`call_type` column used to identify incoming video calls.

Incoming calls ring in the app while it is open, including when the recipient is
on a screen outside Chats. To receive a push notification while Apni Gari is in
the background, complete the Firebase/Supabase push setup in
`supabase/PUSH_NOTIFICATIONS_SETUP.md`, including its second database webhook
for `public.chat_calls`. Rebuild and install the app after configuring Firebase.

The push notification opens Apni Gari and displays the answer/decline prompt.
It is a standard notification; native full-screen incoming-call UI, CallKit,
and Android Telecom integration are not included.

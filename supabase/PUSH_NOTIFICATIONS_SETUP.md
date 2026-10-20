# Chat push notifications

The app registers Android FCM device tokens for signed-in users, displays a
system notification and an in-app popup for incoming messages, and opens the
conversation when an alert is tapped. The Chats tab shows the number of unread
messages and clears them when the conversation is opened. Background push
delivery requires the Firebase and Supabase server setup below.

## 1. Firebase Android app

Create a Firebase project and add an Android app with this exact application
ID (read from `android/app/build.gradle`):

`com.apnigari.one`

Download its `google-services.json` into `android/app/google-services.json`.
Do not rename the Firebase app package ID. Then build and install the app once;
on the first signed-in session Android will request notification permission and
the app will register its FCM token in Supabase.

Firebase setup follows the [official Flutter FCM setup](https://firebase.google.com/docs/flutter/setup)
and [message receiving guide](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).

## 2. Supabase schema and Edge Function

Run `supabase/message_push_and_public_sellers.sql` in Supabase SQL Editor. It
creates an owner-only `push_tokens` table and a narrow public seller view used
to show seller names, contact information, and avatar URLs on listings.
Run `supabase/motorcycles_and_chat.sql` as well to create the chat tables,
Realtime policies, and read receipts used for unread counts. If you previously
ran this SQL file, run the updated version again to add the `read_at` column and
its recipient-only update policy. Existing messages are marked read during this
one-time schema update. For account profile photos, run
`supabase/profile_avatar_url.sql` and `supabase/profile_avatar_policy.sql`; the
first adds the saved photo URL field and the second permits uploads only in the
signed-in user's profile folder in the existing `car-images` bucket.

In Firebase Project Settings, create a server service account with Firebase
Cloud Messaging send permission, download its JSON key, and keep it private.
In Supabase Edge Function secrets, set:

- `FCM_SERVICE_ACCOUNT_JSON`: the complete service-account JSON document.
- `CHAT_WEBHOOK_SECRET`: a new random secret used only by the database webhook.

The `chat-push` function sends both chat-message alerts and incoming call alerts.
It also uses Supabase's server-side `SUPABASE_URL` and
`SUPABASE_SERVICE_ROLE_KEY` environment values. These are used only inside the
Edge Function; never put them in Flutter or in this repository.

Deploy from the project root:

```sh
supabase functions deploy chat-push --no-verify-jwt
```

The function rejects requests without the shared custom header even though
platform JWT verification is disabled for the database webhook.

## 3. Database webhook

In Supabase Dashboard → Database → Webhooks, create an `INSERT` webhook for
`public.chat_messages` with:

- URL: `https://xfekygjwdxspwrgpemql.supabase.co/functions/v1/chat-push`
- Method: `POST`
- Header `Content-Type`: `application/json`
- Header `x-webhook-secret`: the same value as `CHAT_WEBHOOK_SECRET`

This server-side hook covers messages inserted by the app or another allowed
client. It looks up the thread recipient and sends one alert to each registered
device owned by that recipient. The notification preview contains the listing
name but not the private message text.

Create a second `INSERT` webhook for `public.chat_calls` using the same URL,
method, and headers. The updated function sends an incoming voice/video call
notification to the callee's registered devices. Tapping it opens the app and
shows the answer/decline prompt. Calls can ring in-app while the app is open;
the push alert handles background or closed-app delivery. This is a standard
push alert, not the native full-screen phone UI provided by CallKit or Android
Telecom.

## 4. Verify on devices

Sign in on two Android phones and allow notifications on both. Send a message
while the receiving phone is on another screen, then while Apni Gari is
in the background. Tap the alert and confirm it opens the correct conversation.
For call alerts, start a voice or video call from one phone while the other is
in the background, then tap the incoming-call notification and answer. Android
force-stop prevents FCM delivery until the app is opened again; this is an
operating-system restriction.

For iOS, add Push Notifications capability to the Runner target in Xcode and
upload an APNs authentication key in Firebase Project Settings → Cloud
Messaging. Install on a physical iPhone, sign in, and allow notifications.

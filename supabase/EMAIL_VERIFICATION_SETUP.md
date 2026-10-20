# Production email verification and authentication

Apni Gari uses Supabase Auth as its authentication backend. Supabase creates
accounts, hashes and checks passwords, issues single-use confirmation/reset
tokens, and establishes the signed-in session. Resend is only the SMTP delivery
provider. Do not send confirmation links from the Flutter app or create a
separate Resend verification endpoint: that would bypass Supabase's token and
session handling.

## 1. Configure Resend SMTP in Supabase

The domain `apnigari.online` is verified in Resend. In the Resend dashboard,
create an API key for SMTP and keep it private. In Supabase, open **Project
Settings → Authentication → SMTP Settings** (or **Authentication → SMTP
Settings**, depending on the dashboard layout) and enable custom SMTP:

| Setting | Value |
| --- | --- |
| Sender email | `no-reply@apnigari.online` (or another address on the verified domain) |
| Sender name | `Apni Gari` |
| Host | `smtp.resend.com` |
| Port | `465` |
| Username | `resend` |
| Password | The Resend SMTP API key |

Save the settings. Keep the Resend API key in Supabase's SMTP configuration;
never add it to Flutter, source control, or `supabase_config.dart`. Use a
separate Resend API key with only the access needed for SMTP, and monitor
Resend's delivery logs when troubleshooting.

## 2. Enable confirmation and set redirect URLs

In **Authentication → Sign In / Providers → Email**:

1. Enable email/password sign-ups.
2. Enable **Confirm email**. Do not disable it to work around delivery or login
   issues.
3. Open **Authentication → Emails → Email Templates → Confirm signup**.
   Set the subject to `Your Apni Gari verification code`, then replace the
   template body with the contents of
   [`templates/confirm_signup_code.html`](templates/confirm_signup_code.html).
   The template must include `{{ .Token }}` so Supabase sends the one-time code.
   Do not use `{{ .ConfirmationURL }}` for this code-entry flow.
4. In **Authentication → Sign In / Providers → Email**, set **Email OTP
   Length** to `6`. The app's verification screen accepts six-digit codes.

In **Authentication → URL Configuration**, add this exact redirect URL to the
allow list:

```text
com.apnigari.one://login-callback/
```

This must match `SupabaseConfig.authRedirectUrl` in
`lib/config/supabase_config.dart`. The Android app is registered to receive this
deep link. Also add any future iOS/web callback URLs there before using those
platforms for auth.

## 3. Enforce verified accounts for protected writes

Run [`email_confirmation_rls.sql`](email_confirmation_rls.sql) in the Supabase
SQL Editor. It adds restrictive RLS checks so an authenticated user must have
`auth.users.email_confirmed_at` set before creating or updating listings and
uploading car images. Existing owner policies remain in effect. Do not run
`disable_email_confirmation.sql` if verified accounts should be required.

Supabase Auth remains the authority for authentication. The SQL check adds a
database-side authorization gate too, so a modified client cannot bypass the
verified-email requirement for those writes.

## 4. App flows

- **Sign up:** Supabase creates the pending account and sends a six-digit
  confirmation code through Resend. The app asks for the code and offers a
  resend action with a cooldown.
- **Confirm:** The app submits the code to Supabase Auth as a signup OTP.
  Supabase validates it, marks the email confirmed, and establishes the session.
- **Sign in:** Supabase checks the password and rejects unconfirmed accounts.
- **Password recovery:** Supabase sends a reset link to the same callback; the
  app allows a new password after the recovery event.

Password recovery continues to use its existing reset link and callback. Resend's
verified domain only proves domain ownership. Delivery also depends on the SMTP
settings, an allowed sender address, and the confirmation template. Check
Supabase Auth logs and Resend email logs if messages do not arrive.

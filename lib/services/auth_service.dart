import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Thin wrapper around Supabase Auth.
///
/// All password handling stays inside Supabase — the app never stores or
/// transforms passwords, and no secret key is ever used.
class AuthService {
  SupabaseClient get _client => Supabase.instance.client;

  bool get isConfigured => SupabaseConfig.isConfigured;

  /// Currently authenticated user, or null when signed out.
  User? get currentUser {
    if (!isConfigured) return null;
    return _client.auth.currentUser;
  }

  String? get currentUserId => currentUser?.id;

  bool get isSignedIn => currentUserId != null;

  Stream<AuthState> get authStateChanges {
    if (!isConfigured) return const Stream<AuthState>.empty();
    return _client.auth.onAuthStateChange;
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    return _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: SupabaseConfig.authRedirectUrl,
      data: {
        if (fullName != null && fullName.trim().isNotEmpty)
          'full_name': fullName.trim(),
      },
    );
  }

  Future<void> resendSignupConfirmation(String email) async {
    await _client.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: SupabaseConfig.authRedirectUrl,
    );
  }

  Future<void> verifySignupCode({
    required String email,
    required String code,
  }) async {
    await _client.auth.verifyOTP(
      email: email.trim(),
      token: code.trim(),
      type: OtpType.signup,
    );
  }

  Future<void> requestPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: SupabaseConfig.authRedirectUrl,
    );
  }

  Future<void> setNewPassword(String password) async {
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  Future<Session> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final session = response.session;
    if (session == null) {
      throw const AuthException('Sign-in failed. Please try again.');
    }
    return session;
  }

  Future<void> signOut() async {
    if (!isConfigured) return;
    try {
      await _client.auth.signOut();
    } on AuthException {
      // Local session is already cleared; ignore server-side errors so the
      // user can always get back to the signed-out state.
    }
  }
}

import 'dart:async';

import 'package:app_links/app_links.dart';
import '../utils/error_messages.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/push_notification_service.dart';

/// Holds the current Supabase session and the matching `profiles` row.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._auth, this._profiles) {
    _subscription = _auth.authStateChanges.listen(
      _handleAuthEvent,
      onError: _handleAuthError,
    );
    if (_auth.isConfigured) {
      _deepLinkSubscription = _appLinks.uriLinkStream.listen(
        _inspectAuthCallback,
        onError: (Object error, StackTrace stackTrace) =>
            _handleAuthError(error, stackTrace),
      );
    }
  }

  final AuthService _auth;
  final ProfileService _profiles;
  late final StreamSubscription<AuthState> _subscription;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _deepLinkSubscription;

  UserProfile? _profile;
  bool _loaded = false;
  bool _busy = false;
  String? _pendingUserId;

  /// Name entered on the sign-up form, applied to `profiles` after sign-in.
  String? _pendingFullName;
  String? _authNotice;
  bool _passwordRecoveryPending = false;

  bool get isConfigured => _auth.isConfigured;
  bool get isSignedIn => _auth.isSignedIn;
  String? get userId => _auth.currentUserId;
  UserProfile? get profile => _profile;
  bool get isLoading => _busy;

  /// Null until the first auth state has been resolved.
  bool get isReady => _loaded;
  bool get passwordRecoveryPending => _passwordRecoveryPending;
  String? get authNotice => _authNotice;

  void clearAuthNotice() {
    _authNotice = null;
    notifyListeners();
  }

  void _handleAuthEvent(AuthState state) {
    if (state.event == AuthChangeEvent.passwordRecovery) {
      _passwordRecoveryPending = true;
      _authNotice = 'Set a new password to finish recovering your account.';
    }
    unawaited(_onAuthChanged());
  }

  void dismissPasswordRecovery() {
    _passwordRecoveryPending = false;
    notifyListeners();
  }

  Future<String?> requestPasswordReset(String email) async {
    if (!isConfigured) return _notConfigured;
    _busy = true;
    notifyListeners();
    try {
      await _auth.requestPasswordReset(email.trim());
      return null;
    } on AuthException catch (e) {
      return _authErrorMessage(e);
    } catch (_) {
      return 'Could not send the password reset email. Check your connection and retry.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<String?> setNewPassword(String password) async {
    if (!isConfigured) return _notConfigured;
    if (!_passwordRecoveryPending) {
      return 'Open the password reset link from your email first.';
    }
    _busy = true;
    notifyListeners();
    try {
      await _auth.setNewPassword(password);
      _passwordRecoveryPending = false;
      _authNotice = 'Your password has been changed.';
      return null;
    } on AuthException catch (e) {
      return _authErrorMessage(e);
    } catch (_) {
      return 'Could not update your password. Check your connection and retry.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void _handleAuthError(Object error, StackTrace stackTrace) {
    final text = error.toString().toLowerCase();
    if (text.contains('expired') || text.contains('invalid')) {
      _authNotice =
          'That authentication link is invalid or expired. Request a new link and open the latest email.';
    } else {
      _authNotice =
          'We could not complete that authentication link. Check your connection and try again.';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  /// Profile row for the signed-in user, guaranteed non-null after [isReady].
  UserProfile get safeProfile =>
      _profile ??
      UserProfile(id: userId ?? '', fullName: '', phone: '', city: '');

  Future<void> init() async {
    if (_auth.isConfigured) {
      try {
        final initialUri = await _appLinks.getInitialLink();
        if (initialUri != null) _inspectAuthCallback(initialUri);
      } catch (error, stackTrace) {
        _handleAuthError(error, stackTrace);
      }
    }
    await _onAuthChanged();
  }

  void _inspectAuthCallback(Uri uri) {
    final callback = Uri.parse(SupabaseConfig.authRedirectUrl);
    if (uri.scheme != callback.scheme || uri.host != callback.host) return;
    final params = <String, String>{...uri.queryParameters};
    if (uri.fragment.isNotEmpty) {
      try {
        params.addAll(Uri.splitQueryString(uri.fragment));
      } on FormatException {
        // The SDK handles valid session fragments; inspect callback errors.
      }
    }
    final description = params['error_description'];
    final code = params['error_code'];
    if (description != null || code != null) {
      _handleAuthError(
        AuthException(description ?? code ?? 'Authentication link failed.'),
        StackTrace.current,
      );
    }
  }

  Future<void> _onAuthChanged() async {
    final id = _auth.currentUserId;
    if (id == null) {
      _profile = null;
      _pendingUserId = null;
      _loaded = true;
      notifyListeners();
      return;
    }
    unawaited(PushNotificationService.instance.registerForUser(id));
    if (_pendingUserId == id && _profile != null) {
      _loaded = true;
      notifyListeners();
      return;
    }
    _pendingUserId = id;
    _busy = true;
    _loaded = true;
    notifyListeners();

    try {
      _profile = await _profiles.fetchOrCreate(id);
    } on PostgrestException catch (e) {
      debugLog('Profile load failed: $e');
      _profile = UserProfile(id: id);
    } catch (e) {
      debugLog('Profile load failed: $e');
      _profile = UserProfile(id: id);
    } finally {
      _busy = false;
      notifyListeners();
    }

    // A name typed on the sign-up form is saved when a session exists.
    final metadataName = _auth.currentUser?.userMetadata?['full_name'];
    final pending =
        _pendingFullName ?? (metadataName is String ? metadataName : null);
    if (pending != null && pending.trim().isNotEmpty) {
      _pendingFullName = null;
      final profile = _profile ?? UserProfile(id: id);
      final error = await _profiles.updateProfile(
        userId: id,
        fullName: pending,
        phone: profile.phone,
        city: profile.city,
      );
      if (error == null) {
        _profile = UserProfile(
          id: id,
          fullName: pending,
          phone: profile.phone,
          city: profile.city,
          avatarUrl: profile.avatarUrl,
        );
        notifyListeners();
      } else {
        debugLog('Could not save name from sign-up: $error');
      }
    }
  }

  Future<String?> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    if (!isConfigured) return _notConfigured;
    _busy = true;
    notifyListeners();
    try {
      final response = await _auth.signUp(
        email: email,
        password: password,
        fullName: fullName,
      );
      if (response.user == null) {
        return 'Sign-up did not complete. Please try again.';
      }
      final name = fullName?.trim();
      if (response.session == null) {
        return 'Account created. Enter the 6-digit verification code sent to your email.';
      }
      if (name != null && name.isNotEmpty) {
        _pendingFullName = name;
      }
      await _onAuthChanged();
      return null;
    } on AuthException catch (e) {
      return _authErrorMessage(e);
    } catch (e) {
      return 'Sign-up failed. Check your connection and try again.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<String?> resendSignupConfirmation(String email) async {
    if (!isConfigured) return _notConfigured;
    final address = email.trim();
    if (address.isEmpty) return 'Enter your email address first.';
    try {
      await _auth.resendSignupConfirmation(address);
      return null;
    } on AuthException catch (e) {
      return _authErrorMessage(e);
    } catch (_) {
      return 'Could not resend the confirmation email. Try again shortly.';
    }
  }

  Future<String?> verifySignupCode({
    required String email,
    required String code,
  }) async {
    if (!isConfigured) return _notConfigured;
    if (!RegExp(r'^\d{6}$').hasMatch(code.trim())) {
      return 'Enter the 6-digit code from your email.';
    }
    _busy = true;
    notifyListeners();
    try {
      await _auth.verifySignupCode(email: email, code: code);
      await _onAuthChanged();
      return null;
    } on AuthException catch (e) {
      return _authErrorMessage(e);
    } catch (_) {
      return 'Could not verify that code. Check your connection and try again.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    if (!isConfigured) return _notConfigured;
    _busy = true;
    notifyListeners();
    try {
      await _auth.signIn(email: email, password: password);
      await _onAuthChanged();
      return null;
    } on AuthException catch (e) {
      return _authErrorMessage(e);
    } catch (e) {
      return 'Sign-in failed. Check your connection and try again.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    final id = userId;
    if (id != null) {
      await PushNotificationService.instance.unregisterForUser(id);
    }
    await _auth.signOut();
    _profile = null;
    _pendingUserId = null;
    notifyListeners();
  }

  Future<String?> updateProfile({
    required String fullName,
    required String phone,
    required String city,
  }) async {
    final id = userId;
    if (id == null) return 'Sign in to update your profile.';
    final error = await _profiles.updateProfile(
      userId: id,
      fullName: fullName,
      phone: phone,
      city: city,
    );
    if (error == null) {
      _profile = UserProfile(
        id: id,
        fullName: fullName,
        phone: phone,
        city: city,
        avatarUrl: safeProfile.avatarUrl,
      );
    }
    notifyListeners();
    return error;
  }

  Future<String?> updateAvatar(XFile image) async {
    final id = userId;
    if (id == null) return 'Sign in to add a profile photo.';
    final oldUrl = safeProfile.avatarUrl;
    _busy = true;
    notifyListeners();
    String? newUrl;
    try {
      newUrl = await _profiles.uploadAvatar(id, image);
      final profile = safeProfile;
      final error = await _profiles.updateProfile(
        userId: id,
        fullName: profile.fullName,
        phone: profile.phone,
        city: profile.city,
        avatarUrl: newUrl,
      );
      if (error != null) {
        await _profiles.removeAvatar(newUrl);
        return error;
      }
      _profile = profile.copyWith(avatarUrl: newUrl);
      if (oldUrl.isNotEmpty && oldUrl != newUrl) {
        try {
          await _profiles.removeAvatar(oldUrl);
        } catch (e) {
          debugLog('Old profile photo cleanup failed: $e');
        }
      }
      return null;
    } catch (e) {
      if (newUrl != null) {
        try {
          await _profiles.removeAvatar(newUrl);
        } catch (_) {}
      }
      debugLog('Profile photo update failed: $e');
      return ErrorMessages.from(
        e,
        fallback: 'Could not save your photo. Please try again.',
      );
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  String get _notConfigured =>
      'Some app services are unavailable. Please try again later.';

  String _authErrorMessage(AuthException e) {
    return ErrorMessages.from(e);
  }
}

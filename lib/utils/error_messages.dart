import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'error_type_check.dart';

/// Safe, user-facing failures and debug-only diagnostics.
class ErrorMessages {
  ErrorMessages._();

  static const generic = 'Something went wrong. Please try again.';
  static const network = 'Check your internet connection and try again.';
  static const auth = 'We could not verify your account. Please try again.';
  static const upload = 'The upload could not be completed. Please try again.';

  static String from(Object error, {String fallback = generic}) {
    if (isNetworkException(error) || error is TimeoutException) {
      return network;
    }
    if (error is AuthException) {
      final message = error.message.toLowerCase();
      if (message.contains('invalid login credentials')) {
        return 'Incorrect email or password.';
      }
      if (message.contains('email not confirmed')) {
        return 'Please verify your email before signing in.';
      }
      if (message.contains('rate limit') || message.contains('too many')) {
        return 'Too many attempts. Wait a few minutes and try again.';
      }
      return auth;
    }
    if (error is StorageException) return upload;
    if (error is PostgrestException) return fallback;
    return fallback;
  }
}

void debugLog(Object? message, {int? wrapWidth}) {
  if (kDebugMode) debugPrint(message?.toString() ?? '', wrapWidth: wrapWidth);
}

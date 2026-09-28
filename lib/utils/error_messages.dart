import 'package:flutter/foundation.dart';

/// Maps a raw exception to a plain-English, user-safe message.
///
/// Raw exception text (`Exception: SocketException: Failed host lookup…`,
/// PostgREST error JSON, stack traces) must never reach a SnackBar or
/// dialog — it reads as a "developer error" and can leak server internals.
/// Every UI catch site routes through [friendlyError], keeping its own
/// short context prefix so the user still knows *what* failed.
///
/// The raw error is printed in debug builds only, so real diagnostics stay
/// available during development while release builds stay silent.
String friendlyError(Object error, {String? context}) {
  if (kDebugMode) {
    // ignore: avoid_print
    debugPrint('friendlyError [$context]: $error');
  }

  final raw = error.toString().toLowerCase();

  String reason;
  if (raw.contains('already registered') ||
      raw.contains('email address is already') ||
      raw.contains('duplicate key value') && raw.contains('email')) {
    reason = 'an account with this email already exists';
  } else if (raw.contains('invalid login credentials')) {
    reason = 'the email or password is incorrect';
  } else if ((raw.contains('password') && raw.contains('at least')) ||
      raw.contains('signup requires a valid password')) {
    reason = 'please choose a password of at least 6 characters';
  } else if (raw.contains('unable to validate email') ||
      raw.contains('invalid email')) {
    reason = 'that email address does not look valid';
  } else if (raw.contains('not configured')) {
    reason =
        'the app is not connected to its server — contact support if this persists';
  } else if (raw.contains('email not confirmed')) {
    reason = 'please confirm your email first (check your inbox)';
  } else if (raw.contains('rate limit') || raw.contains('too many')) {
    reason = 'too many attempts — wait a minute and try again';
  } else if (raw.contains('database error saving new user')) {
    reason =
        'the server had trouble creating the account — please try again shortly';
  } else if (raw.contains('jwt') ||
      raw.contains('401') ||
      raw.contains('permission denied') ||
      raw.contains('row-level security')) {
    reason = 'your session expired — sign in again and retry';
  } else if (raw.contains('quota') || raw.contains('plan limit')) {
    reason = 'your plan limit for this feature has been reached';
  } else if (raw.contains('socketexception') ||
      raw.contains('failed host lookup') ||
      raw.contains('xmlhttprequest error') ||
      raw.contains('network is unreachable') ||
      raw.contains('connection refused') ||
      raw.contains('clientexception')) {
    reason = 'no connection — check your internet and try again';
  } else if (raw.contains('timeout') || raw.contains('timed out')) {
    reason = 'the request timed out — please try again';
  } else if (raw.contains('platformexception')) {
    reason = 'the device blocked this action — check app permissions';
  } else if (raw.contains('no such file') ||
      raw.contains('filesystemexception') ||
      raw.contains('cannot open file')) {
    reason = 'the file could not be found on this device';
  } else if (raw.contains('formatexception') ||
      raw.contains('type cast') ||
      raw.contains('unexpected character')) {
    reason = 'the server sent data this app could not read';
  } else {
    reason = 'something went wrong — please try again';
  }

  final head = context == null ? '' : '$context — ';
  final sentence = context == null
      ? reason[0].toUpperCase() + reason.substring(1)
      : reason;
  return '$head$sentence.';
}

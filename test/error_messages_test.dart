import 'package:flutter_test/flutter_test.dart';
import 'package:finavig/utils/error_messages.dart';

void main() {
  group('friendlyError maps raw failures to user-safe text', () {
    test('network failures read as connection problems', () {
      expect(
        friendlyError(Exception('SocketException: Failed host lookup')),
        'No connection — check your internet and try again.',
      );
      expect(
        friendlyError(Exception('ClientException: Connection closed')),
        'No connection — check your internet and try again.',
      );
    });

    test('auth failures name the fix, not the server', () {
      expect(
        friendlyError(Exception('Invalid login credentials')),
        'The email or password is incorrect.',
      );
      expect(
        friendlyError(Exception('Email not confirmed')),
        'Please confirm your email first (check your inbox).',
      );
      expect(
        friendlyError(Exception('User already registered')),
        'An account with this email already exists.',
      );
      expect(
        friendlyError(Exception('Password should be at least 6 characters')),
        'Please choose a password of at least 6 characters.',
      );
      expect(
        friendlyError(Exception('Rate limit exceeded')),
        'Too many attempts — wait a minute and try again.',
      );
      expect(
        friendlyError(Exception('Database error saving new user')),
        'The server had trouble creating the account — please try again shortly.',
      );
    });

    test('session and quota failures avoid server jargon', () {
      expect(
        friendlyError(Exception('JWT expired')),
        'Your session expired — sign in again and retry.',
      );
      expect(
        friendlyError(Exception('permission denied for table docs')),
        'Your session expired — sign in again and retry.',
      );
      expect(
        friendlyError(Exception('Quota exceeded for AI summaries')),
        'Your plan limit for this feature has been reached.',
      );
    });

    test('device and file failures stay concrete', () {
      expect(
        friendlyError(Exception('PlatformException(camera_access_denied)')),
        'The device blocked this action — check app permissions.',
      );
      expect(
        friendlyError(Exception('FileSystemException: cannot open file')),
        'The file could not be found on this device.',
      );
    });

    test('timeouts and unparseable data get plain words', () {
      expect(
        friendlyError(Exception('Connection timed out')),
        'The request timed out — please try again.',
      );
      expect(
        friendlyError(FormatException('Unexpected character')),
        'The server sent data this app could not read.',
      );
    });

    test('unknown failures fall back without leaking internals', () {
      final msg = friendlyError(
        Exception('PostgREST 500 {\"message\":\"db crash at 0x7f3a\"}'),
      );
      expect(msg, 'Something went wrong — please try again.');
      expect(msg.contains('0x7f3a'), isFalse);
    });

    test('context prefix names the action and stays one sentence', () {
      expect(
        friendlyError(
          Exception('SocketException: network unreachable'),
          context: 'Could not renew',
        ),
        'Could not renew — no connection — check your internet and try again.',
      );
      expect(
        friendlyError(Exception('boom'), context: 'Could not share the file'),
        'Could not share the file — something went wrong — please try again.',
      );
    });
  });
}

import 'package:finavig/screens/app_lock_flows.dart';
import 'package:finavig/screens/app_lock_screen.dart';
import 'package:finavig/screens/profile/app_lock_section.dart';
import 'package:finavig/services/app_lock_service.dart';
import 'package:finavig/services/biometric_service.dart';
import 'package:finavig/widgets/app_lock_gate.dart';
import 'package:finavig/widgets/passcode_pad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory stand-in for the platform secure storage.
class _MemoryStore implements AppLockStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// Types a passcode on the on-screen keypad and lets the entry settle.
Future<void> _enterPin(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tester.tap(find.text(digit));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  final service = AppLockService.instance;
  late _MemoryStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // The biometric plugin has no channel handler in a test host, so pin the
    // probe to "unsupported" — the passcode paths never depend on it.
    BiometricService.instance.supportedOverride = false;
    store = _MemoryStore();
    service.useStoreForTesting(store);
    await service.disable();
    await service.init();
  });

  tearDown(() {
    BiometricService.instance.supportedOverride = null;
    BiometricService.instance.authenticateResultOverride = false;
  });

  group('AppLockService', () {
    test('starts disabled', () {
      expect(service.isEnabled, isFalse);
      expect(service.shouldBlock, isFalse);
    });

    test('enable stores only a salted hash, never the passcode', () async {
      await service.enable('123456');

      expect(service.isEnabled, isTrue);
      // A just-set passcode must not lock the user out of their own session.
      expect(service.isLocked, isFalse);

      final storedHash = store.values['applock.passcode.hash'];
      expect(storedHash, isNotNull);
      expect(storedHash, isNot('123456'));
      expect(store.values['applock.passcode.salt'], isNotNull);
    });

    test('verify accepts the right passcode and rejects the wrong one',
        () async {
      await service.enable('123456');

      expect(await service.verify('000000'), PasscodeResult.wrong);
      expect(await service.verify('123456'), PasscodeResult.success);
      expect(service.isLocked, isFalse);
    });

    test('a success clears accumulated failed attempts', () async {
      await service.enable('123456');
      await service.verify('000000');
      await service.verify('000000');
      await service.verify('123456');

      // Three more wrongs must not trip the 5-attempt lockout.
      expect(await service.verify('000000'), PasscodeResult.wrong);
      expect(await service.verify('000000'), PasscodeResult.wrong);
      expect(await service.verify('000000'), PasscodeResult.wrong);
      expect(service.lockoutSecondsRemaining, 0);
    });

    test('five wrong attempts trigger a lockout that blocks even the right '
        'passcode', () async {
      await service.enable('123456');

      for (var i = 0; i < AppLockService.maxAttempts - 1; i++) {
        expect(await service.verify('000000'), PasscodeResult.wrong);
      }
      expect(await service.verify('000000'), PasscodeResult.lockedOut);
      expect(service.lockoutSecondsRemaining, greaterThan(0));

      // Even the correct passcode is refused while locked out.
      expect(await service.verify('123456'), PasscodeResult.lockedOut);
      expect(service.shouldBlock, isFalse);
    });

    test('lockout survives a relaunch (persisted, not memory-only)', () async {
      await service.enable('123456');
      for (var i = 0; i < AppLockService.maxAttempts; i++) {
        await service.verify('000000');
      }
      expect(service.lockoutSecondsRemaining, greaterThan(0));

      // Simulate a cold start against the same persisted store.
      await service.init();
      expect(service.lockoutSecondsRemaining, greaterThan(0));
      expect(await service.verify('123456'), PasscodeResult.lockedOut);
    });

    test('disable erases the passcode and unlocks', () async {
      await service.enable('123456');
      service.lock();
      expect(service.shouldBlock, isTrue);

      await service.disable();

      expect(service.isEnabled, isFalse);
      expect(service.shouldBlock, isFalse);
      expect(store.values['applock.passcode.hash'], isNull);
      expect(store.values['applock.passcode.salt'], isNull);
    });

    test('biometric preference round-trips and survives relaunch', () async {
      await service.enable('123456', biometric: true);
      expect(service.biometricEnabled, isTrue);

      await service.init();
      expect(service.biometricEnabled, isTrue);

      await service.setBiometricEnabled(false);
      await service.init();
      expect(service.biometricEnabled, isFalse);
    });

    test('changePasscode keeps the biometric preference', () async {
      await service.enable('123456', biometric: true);
      await service.changePasscode('654321');

      expect(service.biometricEnabled, isTrue);
      expect(await service.verify('123456'), PasscodeResult.wrong);
      expect(await service.verify('654321'), PasscodeResult.success);
    });

    test('init starts locked when a passcode is set', () async {
      await service.enable('123456');
      await service.unlockViaBiometric();
      expect(service.shouldBlock, isFalse);

      await service.init();
      expect(service.shouldBlock, isTrue);
    });

    test('lock is a no-op without a passcode', () {
      service.lock();
      expect(service.shouldBlock, isFalse);
    });

    test('setup is offered until it has been shown once', () async {
      expect(service.shouldOfferSetup, isTrue);

      await service.markSetupOffered();
      expect(service.shouldOfferSetup, isFalse);

      await service.init();
      expect(service.shouldOfferSetup, isFalse); // persists across relaunch
    });

    test('no offer once a passcode exists', () async {
      await service.enable('123456');
      expect(service.shouldOfferSetup, isFalse);
    });

    test('isAcceptable enforces six digits', () {
      expect(AppLockService.isAcceptable('123456'), isTrue);
      expect(AppLockService.isAcceptable('12345'), isFalse);
      expect(AppLockService.isAcceptable('1234567'), isFalse);
      expect(AppLockService.isAcceptable('abcdef'), isFalse);
    });
  });

  group('PasscodeLockPanel', () {
    testWidgets('reports the completed passcode', (tester) async {
      String? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PasscodeLockPanel(
              title: 'Enter your passcode',
              onSubmit: (pin) async {
                submitted = pin;
                return null;
              },
            ),
          ),
        ),
      );

      await _enterPin(tester, '123456');
      expect(submitted, '123456');
    });

    testWidgets('a rejection surfaces the message', (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PasscodeLockPanel(
              title: 'Enter your passcode',
              onSubmit: (pin) async {
                attempts++;
                return 'Incorrect passcode';
              },
            ),
          ),
        ),
      );

      await _enterPin(tester, '123456');

      expect(attempts, 1);
      expect(find.text('Incorrect passcode'), findsOneWidget);
    });

    testWidgets('does not submit a passcode shorter than the required length',
        (tester) async {
      String? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PasscodeLockPanel(
              title: 'Enter your passcode',
              onSubmit: (pin) async {
                submitted = pin;
                return null;
              },
            ),
          ),
        ),
      );

      await _enterPin(tester, '12345');
      expect(submitted, isNull);

      // The sixth digit completes the entry.
      await tester.tap(find.text('6'));
      await tester.pumpAndSettle();
      expect(submitted, '123456');
    });
  });

  group('AppLockGate flow', () {
    Widget wrap(Widget child, {bool signedIn = true, VoidCallback? onSignedOut}) {
      return MaterialApp(
        builder: (context, inner) => AppLockGate(
          isSignedIn: () => signedIn,
          onSignedOut: onSignedOut,
          child: inner ?? const SizedBox.shrink(),
        ),
        home: child,
      );
    }

    testWidgets('locks on cold start and unlocks with the right passcode',
        (tester) async {
      await service.enable('123456');
      service.lock();

      await tester.pumpWidget(
        wrap(const Scaffold(body: Text('SECRET CONTENT'))),
      );
      await tester.pump();

      expect(find.text('Enter your passcode'), findsOneWidget);

      // Wrong passcode keeps the lock up and shows the error.
      await _enterPin(tester, '000000');
      expect(find.text('Incorrect passcode'), findsOneWidget);
      expect(find.text('Enter your passcode'), findsOneWidget);

      // Correct passcode releases it.
      await _enterPin(tester, '123456');
      expect(find.text('Enter your passcode'), findsNothing);
      expect(find.text('SECRET CONTENT'), findsOneWidget);
    });

    testWidgets('never locks while signed out', (tester) async {
      await service.enable('123456');
      service.lock();

      await tester.pumpWidget(
        wrap(const Scaffold(body: Text('LOGIN')), signedIn: false),
      );
      await tester.pump();

      expect(find.text('Enter your passcode'), findsNothing);
    });

    testWidgets('shows no lock when disabled', (tester) async {
      await tester.pumpWidget(
        wrap(const Scaffold(body: Text('CONTENT'))),
      );
      await tester.pump();

      expect(find.text('Enter your passcode'), findsNothing);
    });

    testWidgets('biometric button renders above the Navigator (no Overlay '
        'ancestor) without erroring', (tester) async {
      // The lock overlay lives in MaterialApp.builder, i.e. above the
      // Navigator's Overlay — a Tooltip there throws "No Overlay widget
      // found". Hardware is "available" so the button actually builds.
      BiometricService.instance.supportedOverride = true;
      await service.enable('123456', biometric: true);
      service.lock();

      await tester.pumpWidget(
        wrap(const Scaffold(body: Text('CONTENT'))),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.fingerprint_rounded), findsOneWidget);
      expect(find.text('Enter your passcode'), findsOneWidget);
    });

    testWidgets('"Forgot passcode" signs out, clears the lock and reveals '
        'the app', (tester) async {
      await service.enable('123456');
      service.lock();
      var signedOut = false;

      await tester.pumpWidget(
        wrap(
          const Scaffold(body: Text('CONTENT')),
          onSignedOut: () => signedOut = true,
        ),
      );
      await tester.pump();

      // The footer sits below the fold on the short test surface; the lock is
      // a scroll view, so bring it into view first (as a user would scroll).
      final forgot = find.text('Forgot passcode?');
      await tester.ensureVisible(forgot);
      await tester.pumpAndSettle();
      await tester.tap(forgot);
      await tester.pumpAndSettle();
      expect(find.text('Reset App Lock?'), findsOneWidget);

      await tester.tap(find.text('Sign out & reset'));
      await tester.pumpAndSettle();

      expect(signedOut, isTrue);
      expect(service.isEnabled, isFalse);
      expect(find.text('Enter your passcode'), findsNothing);
      expect(find.text('CONTENT'), findsOneWidget);
    });

    testWidgets('complete flow: post-login offer → cold-start lock → unlock',
        (tester) async {
      // 1. The one-time post-login offer appears and the user sets it up.
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => maybeOfferAppLockSetup(context),
                  child: const Text('after-login'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('after-login'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set up'));
      await tester.pumpAndSettle();
      await _enterPin(tester, '123456'); // choose
      await _enterPin(tester, '123456'); // confirm
      expect(service.isEnabled, isTrue);

      // 2. The next cold start comes up locked over the app content.
      service.lock();
      await tester.pumpWidget(
        wrap(const Scaffold(body: Text('SECRET CONTENT'))),
      );
      await tester.pump();
      expect(find.text('Enter your passcode'), findsOneWidget);

      // 3. The right passcode reveals the app.
      await _enterPin(tester, '123456');
      expect(find.text('Enter your passcode'), findsNothing);
      expect(find.text('SECRET CONTENT'), findsOneWidget);
    });

    testWidgets('five wrong attempts show the lockout overlay and block even '
        'the right passcode', (tester) async {
      await service.enable('123456');
      service.lock();

      await tester.pumpWidget(
        wrap(const Scaffold(body: Text('CONTENT'))),
      );
      await tester.pump();

      // The four attempts before the limit keep the overlay interactive.
      for (var i = 0; i < AppLockService.maxAttempts - 1; i++) {
        await _enterPin(tester, '000000');
        expect(find.text('Incorrect passcode'), findsOneWidget);
      }

      // The final attempt trips the lockout. Do not `pumpAndSettle` here: the
      // countdown ticker schedules a frame every second while it is active.
      for (final digit in '000000'.split('')) {
        await tester.tap(find.text(digit));
        await tester.pump();
      }
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Locked for now'), findsOneWidget);
      expect(find.textContaining('Too many incorrect attempts'), findsOneWidget);

      // Even the correct passcode is refused while locked out: the panel does
      // not dismiss, and the escape hatch is disabled too.
      expect(await service.verify('123456'), PasscodeResult.lockedOut);
      final forgot = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Forgot passcode?'),
          matching: find.byType(TextButton),
        ),
      );
      expect(forgot.onPressed, isNull);
      // The lock overlay stays up, now in its locked-out presentation.
      expect(find.text('Locked for now'), findsOneWidget);
    });

    testWidgets('a successful biometric match unlocks the cold start',
        (tester) async {
      BiometricService.instance.supportedOverride = true;
      BiometricService.instance.authenticateResultOverride = true;
      await service.enable('123456', biometric: true);
      service.lock();

      await tester.pumpWidget(
        wrap(const Scaffold(body: Text('SECRET CONTENT'))),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Enter your passcode'), findsNothing);
      expect(find.text('SECRET CONTENT'), findsOneWidget);
    });

    testWidgets('a cancelled biometric leaves the passcode lock in place and '
        'offers the button', (tester) async {
      BiometricService.instance.supportedOverride = true;
      BiometricService.instance.authenticateResultOverride = false;
      await service.enable('123456', biometric: true);
      service.lock();

      await tester.pumpWidget(
        wrap(const Scaffold(body: Text('SECRET CONTENT'))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Enter your passcode'), findsOneWidget);
      expect(find.byIcon(Icons.fingerprint_rounded), findsOneWidget);

      // The passcode remains the fallback and still works.
      await _enterPin(tester, '123456');
      expect(find.text('SECRET CONTENT'), findsOneWidget);
    });
  });

  group('PasscodeSetupScreen flow', () {
    Future<void> launch(WidgetTester tester, void Function(String?) onResult) {
      return tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    onResult(await PasscodeSetupScreen.push(context));
                  },
                  child: const Text('start'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('collects the passcode, confirms it and returns it',
        (tester) async {
      String? result;
      await launch(tester, (value) => result = value);

      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();
      expect(find.text('Create a passcode'), findsWidgets);

      await _enterPin(tester, '123456');
      expect(find.text('Confirm your passcode'), findsWidgets);

      await _enterPin(tester, '123456');
      expect(result, '123456');
    });

    testWidgets('rejects a mismatched confirmation', (tester) async {
      String? result;
      await launch(tester, (value) => result = value);

      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();

      await _enterPin(tester, '123456');
      await _enterPin(tester, '654321');

      expect(find.text("Passcodes didn't match — try again"), findsOneWidget);
      expect(result, isNull);
    });
  });

  group('ProfileSecuritySection', () {
    testWidgets('shows the App Lock tile and reflects the service state',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ProfileSecuritySection())),
      );

      expect(find.text('Security'), findsOneWidget);
      expect(find.text('App Lock'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

      await service.enable('123456');
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(find.text('Passcode required when reopening Finavig'),
          findsOneWidget);
    });

    testWidgets('tapping the switch on runs set-up and turns the lock on',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ProfileSecuritySection())),
      );

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Set-up flow opened; choose and confirm a passcode.
      expect(find.text('Create a passcode'), findsWidgets);
      await _enterPin(tester, '123456');
      expect(find.text('Confirm your passcode'), findsWidgets);
      await _enterPin(tester, '123456');

      expect(service.isEnabled, isTrue);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('tapping the switch off requires the passcode', (tester) async {
      await service.enable('123456');
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ProfileSecuritySection())),
      );
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      // Wrong passcode leaves the lock on and returns to the tile.
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await _enterPin(tester, '000000');
      expect(find.text('Incorrect passcode'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(service.isEnabled, isTrue);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      // Correct passcode turns it off and the switch follows.
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await _enterPin(tester, '123456');
      await tester.pumpAndSettle();
      expect(service.isEnabled, isFalse);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });
  });

  group('maybeOfferAppLockSetup (post-login)', () {
    Future<void> launch(WidgetTester tester) {
      return tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => maybeOfferAppLockSetup(context),
                  child: const Text('after-login'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('prompts once after login and can be declined', (tester) async {
      await launch(tester);

      await tester.tap(find.text('after-login'));
      await tester.pumpAndSettle();
      expect(find.text('Turn on App Lock?'), findsOneWidget);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(service.isEnabled, isFalse);
      expect(service.shouldOfferSetup, isFalse);

      // A second login must not prompt again.
      await tester.tap(find.text('after-login'));
      await tester.pumpAndSettle();
      expect(find.text('Turn on App Lock?'), findsNothing);
    });

    testWidgets('setting it up from the offer enables the lock', (tester) async {
      await launch(tester);

      await tester.tap(find.text('after-login'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set up'));
      await tester.pumpAndSettle();
      expect(find.text('Create a passcode'), findsWidgets);

      await _enterPin(tester, '123456'); // choose
      expect(find.text('Confirm your passcode'), findsWidgets);
      await _enterPin(tester, '123456'); // confirm

      expect(service.isEnabled, isTrue);
    });

    testWidgets('does not offer when a passcode already exists',
        (tester) async {
      await service.enable('123456');
      await launch(tester);

      await tester.tap(find.text('after-login'));
      await tester.pumpAndSettle();

      expect(find.text('Turn on App Lock?'), findsNothing);
    });
  });

  group('promptForPasscode', () {
    testWidgets('resolves true only for the correct passcode', (tester) async {
      await service.enable('123456');
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result =
                        await promptForPasscode(context, title: 'Confirm');
                  },
                  child: const Text('verify'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('verify'));
      await tester.pumpAndSettle();

      await _enterPin(tester, '000000');
      expect(find.text('Incorrect passcode'), findsOneWidget);
      expect(result, isNull);

      await _enterPin(tester, '123456');
      expect(result, isTrue);
    });
  });
}

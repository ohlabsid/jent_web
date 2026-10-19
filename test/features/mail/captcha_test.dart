import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jent_web/data/datasources/email_datasource.dart';
import 'package:jent_web/domain/entities/email_message.dart';
import 'package:jent_web/features/mail/captcha/hcaptcha.dart';

/// Captcha plumbing, exercised on the VM (where the stub is selected).
/// The web implementation needs a real DOM + hCaptcha JS API, so it is
/// verified by building for web, not here.
void main() {
  group('captcha stub (non-web)', () {
    test('is unsupported and never yields a token', () {
      final captcha = createHCaptcha();

      expect(captcha.isSupported, isFalse);
      expect(captcha.token, isNull);

      // Resetting a no-op captcha must stay harmless.
      captcha.reset();
      expect(captcha.token, isNull);
    });

    testWidgets('renders nothing, so the form keeps its space',
        (tester) async {
      final captcha = createHCaptcha();

      await tester.pumpWidget(
        MaterialApp(
          home: captcha.buildWidget(onToken: (_) {}),
        ),
      );

      expect(find.byType(HtmlElementView), findsNothing);
      expect(tester.getSize(find.byType(MaterialApp)), const Size(800, 600));
    });
  });

  group('Web3Forms payload', () {
    final datasource = EmailDatasource('user', 'pass', 'to@example.com');

    EmailMessage message({String? token}) => EmailMessage(
          name: 'Ada',
          from: 'ada@example.com',
          subject: 'Hello',
          body: 'Body text',
          captchaToken: token,
        );

    test('includes h-captcha-response when a token was solved', () {
      final payload = datasource.web3FormsPayload(message(token: 'token-abc'));

      expect(payload['h-captcha-response'], 'token-abc');
      // Key is a --dart-define, so only its presence is assertable here.
      expect(payload.containsKey('access_key'), isTrue);
      expect(payload['email'], 'ada@example.com');
    });

    test('omits the field when there is no token', () {
      final payload = datasource.web3FormsPayload(message());

      expect(payload.containsKey('h-captcha-response'), isFalse);
    });

    test('omits an empty token instead of sending a blank field', () {
      final payload = datasource.web3FormsPayload(message(token: ''));

      expect(payload.containsKey('h-captcha-response'), isFalse);
    });
  });
}

import 'dart:convert';

import 'package:flutter/foundation.dart';import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:jent_web/domain/entities/email_message.dart';
import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';

/// Sends the contact-form email.
///
/// - On **web**, browsers cannot open SMTP sockets, so the form is POSTed
///   to the Web3Forms API (free tier). Get a key at https://web3forms.com
///   and pass `--dart-define=WEB3FORMS_KEY=...` at build/run time.
/// - On **native** platforms the Gmail SMTP path below is used instead,
///   with credentials from `--dart-define`
///   (EMAIL_USERNAME / EMAIL_PASSWORD / EMAIL_RECIPIENT) so no secret
///   is committed to the repo.
@injectable
class EmailDatasource {
  static const _web3formsKey = String.fromEnvironment('WEB3FORMS_KEY');
  static const _web3formsEndpoint = 'https://api.web3forms.com/submit';

  final String _username;
  final String _password;
  final String _recipient;

  EmailDatasource(
    @Named('emailUsername') this._username,
    @Named('emailPassword') this._password,
    @Named('emailRecipient') this._recipient,
  );

  Future<void> send(EmailMessage message) async {
    if (kIsWeb) {
      await _sendViaWeb3Forms(message);
      return;
    }
    final smtpServer = gmail(_username, _password);
    final email = mailer.Message()
      ..from = mailer.Address(_username, message.name)
      ..recipients.add(_recipient)
      ..headers['Reply-To'] = message.from
      ..subject = message.subject.isEmpty ? '(no subject)' : message.subject
      ..text = 'From: ${message.name} <${message.from}>\n\n${message.body}';

    await mailer.send(email, smtpServer);
  }

  /// Web delivery via Web3Forms. The visitor's address is sent as the
  /// `email` field so your inbox shows it as the reply-to address.
  ///
  /// [EmailMessage.captchaToken] is sent as `h-captcha-response` when
  /// present: with hCaptcha enabled as the spam protection, Web3Forms
  /// rejects submissions that arrive without a valid token.
  Future<void> _sendViaWeb3Forms(EmailMessage message) async {
    if (_web3formsKey.isEmpty) {
      throw StateError(
        'WEB3FORMS_KEY is missing. Rebuild with '
        '--dart-define=WEB3FORMS_KEY=YOUR_KEY.',
      );
    }
    final response = await http.post(
      Uri.parse(_web3formsEndpoint),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(web3FormsPayload(message)),
    );
    if (response.statusCode != 200 ||
        !response.body.contains('"success":true')) {
      throw StateError(
        'Email delivery failed (HTTP ${response.statusCode}): ${response.body}',
      );
    }
  }

  /// Body for the Web3Forms POST. Public (and free of secrets beyond the
  /// access key) so tests can assert the captcha field without network.
  @visibleForTesting
  Map<String, dynamic> web3FormsPayload(EmailMessage message) {
    final token = message.captchaToken;
    return {
      'access_key': _web3formsKey,
      'name': message.name,
      'email': message.from,
      'subject': message.subject.isEmpty ? '(no subject)' : message.subject,
      'message':
          'From: ${message.name} <${message.from}>\n\n${message.body}',
      if (token != null && token.isNotEmpty) 'h-captcha-response': token,
    };
  }
}

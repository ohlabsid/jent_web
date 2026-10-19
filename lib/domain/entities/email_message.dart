class EmailMessage {
  final String name;
  final String from;
  final String subject;
  final String body;

  /// hCaptcha token for the Web3Forms submission. Null on native (SMTP
  /// needs no captcha) and when the form is sent without one.
  final String? captchaToken;

  const EmailMessage({
    required this.name,
    required this.from,
    required this.subject,
    required this.body,
    this.captchaToken,
  });

  bool get canSend =>
      subject.trim().isNotEmpty || body.trim().isNotEmpty;
}

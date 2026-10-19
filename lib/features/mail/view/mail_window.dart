import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jent_web/core/theme/app_colors.dart';
import 'package:jent_web/core/theme/app_dimens.dart';
import 'package:jent_web/core/widgets/window/window_title_bar.dart';
import 'package:jent_web/features/mail/bloc/mail_bloc.dart';
import 'package:jent_web/features/mail/bloc/mail_event.dart';
import 'package:jent_web/features/mail/bloc/mail_state.dart';
import 'package:jent_web/features/mail/captcha/hcaptcha.dart';
import 'package:jent_web/features/mail/view/labeled_text_field.dart';
import 'package:jent_web/l10n/app_localizations.dart';

class MailWindow extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onMinimize;
  final VoidCallback onExpand;
  final Size size;
  final ValueChanged<Offset> onDragDelta;
  final ValueChanged<MailDraft> onSend;

  const MailWindow({
    super.key,
    required this.onClose,
    required this.onMinimize,
    required this.onExpand,
    required this.size,
    required this.onDragDelta,
    required this.onSend,
  });

  @override
  State<MailWindow> createState() => _MailWindowState();
}

class MailDraft {
  final String name;
  final String from;
  final String subject;
  final String body;

  /// hCaptcha token, or null where the form has no captcha (native).
  final String? captchaToken;

  const MailDraft({
    required this.name,
    required this.from,
    required this.subject,
    required this.body,
    this.captchaToken,
  });

  bool get canSend => subject.trim().isNotEmpty || body.trim().isNotEmpty;
}

class _MailWindowState extends State<MailWindow> {
  final _nameController = TextEditingController();
  final _fromController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();

  /// Real hCaptcha on web, no-op on native (SMTP needs no captcha).
  final HCaptcha _captcha = createHCaptcha();

  /// Fades the sent/error banner out again a beat after it appears.
  Timer? _statusTimer;

  /// Mirrors the bloc status so the status banner helper can read it.
  EmailStatus _emailStatus = EmailStatus.idle;

  MailDraft get _draft => MailDraft(
    name: _nameController.text,
    from: _fromController.text,
    subject: _subjectController.text,
    body: _bodyController.text,
    captchaToken: _captcha.token,
  );

  /// Clears the draft so the same window can compose the next message,
  /// then lets the banner fade. The window itself stays open.
  void _onStatusChanged(MailState state) {
    if (state.emailStatus != EmailStatus.sent) return;
    _nameController.clear();
    _fromController.clear();
    _subjectController.clear();
    _bodyController.clear();
    _statusTimer?.cancel();
    _statusTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) context.read<MailBloc>().add(ResetEmailStatus());
    });
  }

  @override
  void initState() {
    super.initState();
    for (final c in [
      _nameController,
      _fromController,
      _subjectController,
      _bodyController,
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _nameController.dispose();
    _fromController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _handleSend() {
    final draft = _draft;
    if (!draft.canSend) return;
    widget.onSend(draft);
    // Tokens are single-use and expire quickly, so drop the solved
    // challenge right after handing it over: a failed send then shows
    // a fresh checkbox instead of a silently rejected token.
    _captcha.reset();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final emailStatus = context.select<MailBloc, EmailStatus>(
      (b) => b.state.emailStatus,
    );
    _emailStatus = emailStatus;
    final sending = emailStatus == EmailStatus.sending;
    // With spam protection on, Web3Forms rejects untokened submissions,
    // so Send stays disabled until the challenge is solved.
    final captchaSolved = !_captcha.isSupported || _captcha.token != null;
    final canSend = _draft.canSend && captchaSolved && !sending;

    return BlocListener<MailBloc, MailState>(
      listenWhen: (prev, curr) => prev.emailStatus != curr.emailStatus,
      listener: (context, state) => _onStatusChanged(state),
      child: Material(
        elevation: 24,
        borderRadius: BorderRadius.circular(AppDimens.windowRadius),
        clipBehavior: Clip.antiAlias,
        color: AppColors.deepWaterColor,
        child: SizedBox(
          width: widget.size.width,
          height: widget.size.height,
          child: Column(
            children: [
              WindowTitleBar(
                onClose: widget.onClose,
                onMinimize: widget.onMinimize,
                onExpand: widget.onExpand,
                onPanUpdate: widget.onDragDelta,
              ),
              const Divider(height: 1),
              LabeledTextField(
                label: '${localizations.textName}:',
                controller: _nameController,
                hint: localizations.textNameHint,
              ),
              const Divider(height: 1, indent: 16),
              LabeledTextField(
                label: '${localizations.textFrom}:',
                controller: _fromController,
                hint: localizations.textFromHint,
              ),
              const Divider(height: 1, indent: 16),
              LabeledTextField(
                label: '${localizations.textSubject}:',
                controller: _subjectController,
                hint: localizations.textSubjectHint,
              ),
              const Divider(height: 1, indent: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _bodyController,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: InputDecoration(
                      hintText: localizations.textWriteYourMessageHint,
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(fontSize: AppDimens.bodyFontSize),
                  ),
                ),
              ),
              if (_captcha.isSupported) ...[
                const Divider(height: 1),
                _buildCaptchaPanel(localizations, captchaSolved),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _buildStatusBanner(localizations),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          AppDimens.buttonRadius,
                        ),
                        color: canSend
                            ? AppColors.sendButtonEnabled
                            : AppColors.sendButtonDisabled,
                      ),
                      child: TextButton(
                        onPressed: canSend ? _handleSend : null,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 12,
                          ),
                          foregroundColor: Colors.white,
                        ),
                        child: sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                localizations.textSend,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// macOS-style spam panel: a titled section at the foot of the form,
  /// mirroring the security row in Mail's compose window. Green once
  /// the visitor solves the challenge.
  Widget _buildCaptchaPanel(AppLocalizations localizations, bool solved) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final captcha = SizedBox(
                width: 303,
                height: 78,
                child: _captcha.buildWidget(onToken: (_) => setState(() {})),
              );
              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [captcha],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Sent/error feedback, icon-led like the rest of the desktop and
  /// invisible while idle so the row stays clean.
  Widget _buildStatusBanner(AppLocalizations localizations) {
    final (key, icon, color, label) = switch (_emailStatus) {
      EmailStatus.sent => (
        ValueKey('sent'),
        Icons.check_circle_rounded,
        AppColors.captchaVerified,
        localizations.textSentWithIcon,
      ),
      EmailStatus.error => (
        ValueKey('error'),
        Icons.error_rounded,
        AppColors.errorRed,
        localizations.textSendError,
      ),
      _ => (ValueKey('idle'), Icons.circle_outlined, AppColors.subtleText, ''),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: label.isEmpty
          ? const SizedBox.shrink(key: ValueKey('idle'))
          : Row(
              key: key,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
    );
  }
}

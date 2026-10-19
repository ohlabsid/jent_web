import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:jent_web/features/mail/captcha/hcaptcha.dart';
import 'package:web/web.dart' as web;

/// Web3Forms' shared hCaptcha site key, used by every free-plan form
/// (https://docs.web3forms.com/.../spam-protection/hcaptcha). It is
/// public by design — it ships to every visitor. Paid plans can pass
/// their own key with `--dart-define=HCAPTCHA_SITE_KEY=...`.
const String _web3FormsSiteKey = '50b2fe65-b00b-4b9e-ad62-3ba471098be2';

/// Renders the real hCaptcha widget into a DOM element that Flutter
/// hosts as a platform view, then hands the solved token back to Dart.
///
/// Requires `<script src="...api.js?render=explicit">` in
/// `web/index.html`: `render=explicit` stops the script from
/// auto-mounting and exposes `window.hcaptcha` for us to call.
class HCaptchaWeb implements HCaptcha {
  static const String siteKey = String.fromEnvironment(
    'HCAPTCHA_SITE_KEY',
    defaultValue: _web3FormsSiteKey,
  );

  static int _nextViewType = 0;

  /// Unique per controller: one platform view per challenge, and a
  /// stable type so rebuilds don't recreate (and re-register) it.
  late final String _viewType = 'hcaptcha-${_nextViewType++}';

  bool _registered = false;
  String? _token;
  JSAny? _widgetId;
  ValueChanged<String?>? _onToken;

  @override
  bool get isSupported => true;

  @override
  String? get token => _token;

  @override
  Widget buildWidget({required ValueChanged<String?> onToken}) {
    // Keep the newest callback: the DOM element outlives rebuilds, so
    // the JS handler must not close over a stale one.
    _onToken = onToken;
    // The factory must be registered BEFORE the HtmlElementView mounts;
    // doing it from `onPlatformViewCreated` throws
    // `unregistered_view_type`. Registering here (guarded) means the
    // factory hands back the very element hCaptcha renders into.
    if (!_registered) {
      _registered = true;
      final container = web.document.createElement('div')
        as web.HTMLDivElement;
      container.style
        ..width = '100%'
        ..height = '100%';
      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (_) => container,
      );
      unawaited(_renderInto(container));
    }
    return HtmlElementView(viewType: _viewType);
  }

  Future<void> _renderInto(web.HTMLDivElement container) async {
    final api = await _whenApiReady();
    if (api == null) return;

    // Option names are hCaptcha's own (two are kebab-case), so they
    // can't be Dart named parameters — build the literal by hand.
    final options = JSObject();
    options.setProperty('sitekey'.toJS, siteKey.toJS);
    // Required by Web3Forms: their token is only accepted from the
    // native hCaptcha widget, not the reCAPTCHA-compatible one.
    options.setProperty('reCaptchaCompat'.toJS, false.toJS);
    // Default ('normal') size matches the 303x78 box the mail window
    // reserves; 'compact' renders a different box.
    options.setProperty('theme'.toJS, 'light'.toJS);
    options.setProperty(
      'callback'.toJS,
      ((String token) {
        _token = token;
        _onToken?.call(token);
      }).toJS,
    );
    // Tokens expire in ~2 minutes: drop ours so the send button locks
    // again instead of posting a stale token.
    options.setProperty(
      'expired-callback'.toJS,
      (() {
        _token = null;
        _onToken?.call(null);
      }).toJS,
    );
    options.setProperty(
      'error-callback'.toJS,
      (() {
        _token = null;
        _onToken?.call(null);
      }).toJS,
    );

    _widgetId = api.callMethod<JSAny?>('render'.toJS, container, options);
  }

  /// `api.js` loads with `async`, so `window.hcaptcha` may not exist yet
  /// when the window first opens. Poll briefly instead of giving up.
  Future<JSObject?> _whenApiReady() async {
    for (var attempt = 0; attempt < 50; attempt++) {
      final api = _api;
      if (api != null) return api;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return null;
  }

  JSObject? get _api {
    final window = web.window as JSObject;
    return window.has('hcaptcha')
        ? window.getProperty<JSObject?>('hcaptcha'.toJS)
        : null;
  }

  @override
  void reset() {
    // `reset()` with no id resets the first widget on the page.
    final api = _api;
    if (api != null) {
      api.callMethodVarArgs<JSAny?>('reset'.toJS, [
        if (_widgetId != null) _widgetId,
      ]);
    }
    _token = null;
    _onToken?.call(null);
  }
}

HCaptcha createHCaptcha() => HCaptchaWeb();

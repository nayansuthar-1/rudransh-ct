import 'dart:async';
import 'dart:js_interop';
// For `setProperty`: Turnstile's option keys are hyphenated, so an object
// literal constructor cannot name them.
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// The `turnstile` global the Cloudflare script installs. It is absent until
/// that script has loaded, which is why [_whenReady] waits for it.
@JS('turnstile')
external _TurnstileApi? get _turnstileApi;

extension type _TurnstileApi._(JSObject _) implements JSObject {
  external String render(web.Element element, JSObject options);
  external void remove(String widgetId);
}

/// Cloudflare's own widget, 300×65 at its smallest, plus room for the error
/// line it shows in place of the tick.
const _widgetHeight = 72.0;

/// The script is loaded with `async defer` in `web/index.html`, so it may not
/// be there yet on a cold load. Give it a while rather than failing at once;
/// the page is unusable without it either way.
const _readyTimeout = Duration(seconds: 15);

Future<_TurnstileApi?> _whenReady() async {
  final deadline = DateTime.now().add(_readyTimeout);
  while (DateTime.now().isBefore(deadline)) {
    final api = _turnstileApi;
    if (api != null) return api;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return null;
}

/// Renders the Turnstile checkbox and reports its token.
///
/// One `<div>` per widget, held in a platform view. Cloudflare draws into it
/// and calls back with a token that is good for one lookup, so the token is
/// cleared once it expires and the page asks for a new one.
class TurnstileWidget extends StatefulWidget {
  const TurnstileWidget({
    super.key,
    required this.siteKey,
    required this.onToken,
    this.dark = false,
  });

  final String siteKey;

  /// Called with a fresh token, and with an empty string when one expires or
  /// the check fails.
  final ValueChanged<String> onToken;
  final bool dark;

  @override
  State<TurnstileWidget> createState() => _TurnstileWidgetState();
}

class _TurnstileWidgetState extends State<TurnstileWidget> {
  static int _nextId = 0;

  late final String _viewType = 'turnstile-${_nextId++}';
  late final web.HTMLDivElement _host;

  String? _widgetId;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _host = web.document.createElement('div') as web.HTMLDivElement;
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int _) => _host,
    );
    unawaited(_render());
  }

  Future<void> _render() async {
    final api = await _whenReady();
    if (!mounted) return;
    if (api == null) {
      setState(() => _failed = true);
      widget.onToken('');
      return;
    }

    final options = JSObject();
    options.setProperty('sitekey'.toJS, widget.siteKey.toJS);
    options.setProperty('theme'.toJS, (widget.dark ? 'dark' : 'light').toJS);
    // Cloudflare hands the token to `callback`, and calls the others when it
    // goes stale or the check fails. An empty token disables the button.
    options.setProperty(
      'callback'.toJS,
      ((JSString token) {
        if (mounted) widget.onToken(token.toDart);
      }).toJS,
    );
    options.setProperty('expired-callback'.toJS, (() {
      if (mounted) widget.onToken('');
    }).toJS);
    options.setProperty('error-callback'.toJS, (() {
      if (mounted) widget.onToken('');
    }).toJS);

    _widgetId = api.render(_host, options);
  }

  @override
  void dispose() {
    final id = _widgetId;
    if (id != null) _turnstileApi?.remove(id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      // Saying nothing here would leave a blank gap above a button that can
      // never work.
      return const Text(
        'The security check could not load. Check your connection and '
        'reload the page.',
        style: TextStyle(fontSize: 13),
      );
    }
    return SizedBox(
      height: _widgetHeight,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}

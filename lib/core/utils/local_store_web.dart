import 'package:web/web.dart' as web;

/// A small per-browser preference. Storage can be blocked (private mode,
/// cleared site data), so a failure reads as "nothing saved" and never throws.
String? readLocal(String key) {
  try {
    return web.window.localStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

void writeLocal(String key, String value) {
  try {
    web.window.localStorage.setItem(key, value);
  } catch (_) {}
}

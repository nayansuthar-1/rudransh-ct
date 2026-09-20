library;

/// Cloudflare Turnstile for the public lookup (IMPLEMENTATION_PLAN Phase 15,
/// switched on in Phase 17).
///
/// The widget only exists on the web build, which is the only build the trust
/// ships. Everywhere else — widget tests, a desktop debug run — the stub below
/// renders nothing and hands back an empty token, and the Edge Function
/// refuses the lookup. That is the safe direction: no widget means no token
/// means no answer, rather than an unprotected lookup.
export 'turnstile_stub.dart'
    if (dart.library.js_interop) 'turnstile_web.dart';

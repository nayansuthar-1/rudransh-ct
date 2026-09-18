/// Build-time configuration, passed with `--dart-define`:
///
/// ```sh
/// flutter run -d chrome \
///   --dart-define=SUPABASE_URL=https://xyz.supabase.co \
///   --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
/// ```
///
/// Certificate uploads also need `CLOUDINARY_CLOUD_NAME` and
/// `CLOUDINARY_UPLOAD_PRESET`.
///
/// A legacy `SUPABASE_ANON_KEY` is also accepted. Never commit real values.
/// Without them the app runs in demo mode on an empty in-memory store, login
/// bypassed.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const _publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Public client key. Safe in the browser; row-level security guards data.
  static String get supabaseKey =>
      _publishableKey.isNotEmpty ? _publishableKey : _anonKey;

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  static bool get demoMode => !hasSupabase;

  /// Cloudinary account and unsigned upload preset for death certificates
  /// (IMPLEMENTATION_PLAN Phase 13). Public values; the preset limits what
  /// can be uploaded. See docs/RUNBOOK.md.
  static const cloudinaryCloudName =
      String.fromEnvironment('CLOUDINARY_CLOUD_NAME');
  static const cloudinaryUploadPreset =
      String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET');

  static bool get hasCloudinary =>
      cloudinaryCloudName.isNotEmpty && cloudinaryUploadPreset.isNotEmpty;

  /// Cloudflare Turnstile site key for the public member lookup
  /// (IMPLEMENTATION_PLAN Phase 15). Public by design; the matching secret
  /// lives in the `member_lookup` Edge Function. See docs/RUNBOOK.md §1.7.
  static const turnstileSiteKey = String.fromEnvironment('TURNSTILE_SITE_KEY');

  static bool get hasTurnstile => turnstileSiteKey.isNotEmpty;

  /// The trust's UPI address, shown to members paying from the portal. Empty
  /// hides the UPI option; members can still pay through their agent.
  static const upiId = String.fromEnvironment('UPI_ID');

  /// Name shown beside the UPI address in a payment app.
  static const upiPayee = String.fromEnvironment('UPI_PAYEE');

  static bool get hasUpi => upiId.isNotEmpty;

  /// Demo mode only: which screens to open without a login, to preview them.
  /// `owner` (default), `staff`, `agent` or `member`:
  /// `flutter run -d chrome --dart-define=DEMO_ROLE=agent`
  static const demoRole = String.fromEnvironment('DEMO_ROLE');
}

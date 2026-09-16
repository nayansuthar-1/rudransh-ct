import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Clean URLs (`/members` instead of `/#/members`).
  usePathUrlStrategy();
  if (Env.hasSupabase) {
    // Restores a saved session before the first frame, so a page reload
    // keeps the admin signed in.
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseKey,
    );
  }
  runApp(const ProviderScope(child: RudranshAdminApp()));
}

// Opens the agent screens (`/agent`) on sample data, signed in as an agent,
// so they can be tried without a Supabase login — agents cannot sign in to
// the live app until Release 2. Nothing is saved: a page reload starts over.
//
//   flutter run -d chrome -t tool/agent_preview/main.dart
//
// It lives outside `lib/` and borrows the test dataset, so the shipped app
// still carries no sample records.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:rudransh_ct/app.dart';
import 'package:rudransh_ct/data/models/models.dart';
import 'package:rudransh_ct/state/providers.dart';

import '../../test/support/seed_data.dart';
import '../../test/support/signed_in.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  final repo = seededRepository(latency: const Duration(milliseconds: 260));

  // The active agent with the most members, so every screen has rows.
  int membersOf(Agent a) =>
      repo.membersView.where((m) => m.agentId == a.id).length;
  final agent = repo.agentsView
      .where((a) => a.isActive)
      .reduce((a, b) => membersOf(b) > membersOf(a) ? b : a);

  await repo.postAnnouncement(
    title: 'Closing dues by 30 September',
    body: 'Collect this month\'s closing dues from your members by 30 Sep.',
  );

  runApp(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(repo),
      signedInAs(UserRole.agent, agentId: agent.id),
    ],
    child: const RudranshAdminApp(),
  ));
}

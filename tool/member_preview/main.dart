// Opens the member portal (`/me`) on sample data, signed in as a member, so
// its screens can be tried without a Supabase login. Nothing is saved: a page
// reload starts over.
//
//   flutter run -d chrome -t tool/member_preview/main.dart \
//     --dart-define=UPI_ID=trust@upi --dart-define=UPI_PAYEE="Rudransh CT"
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

  // The active member with the most unpaid closings, so Dues has rows.
  final dues = repo.allDues().where((d) => d.due > 0);
  final member = repo.membersView
      .where((m) => m.status == MemberStatus.active)
      .reduce((a, b) => dues.where((d) => d.memberId == b.id).length >
              dues.where((d) => d.memberId == a.id).length
          ? b
          : a);
  repo.portalMemberId = member.id;

  await repo.postAnnouncement(
    title: 'वार्षिक सभा 12 अक्टूबर को',
    body: 'सभी सदस्य सुबह 10 बजे ट्रस्ट कार्यालय पहुँचें।',
  );
  await repo.postAnnouncement(
    title: 'Closing dues by 30 September',
    body: 'Pay through your agent, UPI, or online from this app.',
    yojnaId: member.yojnaId,
  );

  runApp(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(repo),
      signedInAs(UserRole.member, memberId: member.id),
    ],
    child: const RudranshAdminApp(),
  ));
}

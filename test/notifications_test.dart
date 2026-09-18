import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rudransh_ct/app.dart';
import 'package:rudransh_ct/core/l10n/strings.dart';
import 'package:rudransh_ct/core/router/app_router.dart';
import 'package:rudransh_ct/core/router/routes.dart';
import 'package:rudransh_ct/data/models/models.dart';
import 'package:rudransh_ct/data/repositories/in_memory_trust_repository.dart';
import 'package:rudransh_ct/data/repositories/trust_repository.dart';
import 'package:rudransh_ct/state/auth_controller.dart';
import 'package:rudransh_ct/state/providers.dart';
import 'package:rudransh_ct/widgets/notifications_button.dart';

import 'support/seed_data.dart';
/// Mirrors `supabase/tests/notifications_test.sql`: the same events, in memory.
void main() {
  group('notifications', () {
    late InMemoryTrustRepository repo;

    setUp(() => repo = seededRepository());

    /// A member with a payment waiting for approval.
    Future<Payment> pendingPayment() async {
      final member = await _anyActiveMember(repo);
      return repo.createPayment(
        Payment(
          id: '',
          receiptNo: '',
          memberId: member.id,
          yojnaId: member.yojnaId,
          amount: 100,
          date: DateTime.now(),
          status: PaymentStatus.pending,
          kind: PaymentKind.contribution,
          agentId: member.agentId,
        ),
      );
    }

    test('nothing to start with', () async {
      expect(await repo.fetchNotifications(), isEmpty);
      expect(await repo.fetchUnreadCount(), 0);
    });

    test('approving a payment writes one notification', () async {
      final p = await pendingPayment();
      await repo.approvePayment(p.id);

      final list = await repo.fetchNotifications();
      expect(list, hasLength(1));
      expect(list.first.kind, NotificationKind.paymentApproved);
      expect(list.first.title, 'Payment approved');
      expect(list.first.link, AppRoutes.agentCollections);
      expect(list.first.isUnread, isTrue);
      expect(await repo.fetchUnreadCount(), 1);
    });

    test('rejecting carries the reason', () async {
      final p = await pendingPayment();
      await repo.rejectPayment(p.id, 'Amount does not match the receipt');

      final list = await repo.fetchNotifications();
      expect(list.first.kind, NotificationKind.paymentRejected);
      expect(list.first.body, contains('Amount does not match the receipt'));
    });

    test('newest first', () async {
      final a = await pendingPayment();
      await repo.approvePayment(a.id);
      final b = await pendingPayment();
      await repo.rejectPayment(b.id, 'Wrong member');

      final list = await repo.fetchNotifications();
      expect(list, hasLength(2));
      expect(list.first.kind, NotificationKind.paymentRejected,
          reason: 'the newest is on top');
    });

    test('marking one read lowers the count, twice is harmless', () async {
      final p = await pendingPayment();
      await repo.approvePayment(p.id);
      final first = (await repo.fetchNotifications()).first;

      await repo.markNotificationRead(first.id);
      expect(await repo.fetchUnreadCount(), 0);
      expect((await repo.fetchNotifications()).first.readAt, isNotNull);

      await repo.markNotificationRead(first.id);
      expect(await repo.fetchUnreadCount(), 0);
    });

    test('mark all read returns how many changed', () async {
      for (var i = 0; i < 2; i++) {
        final p = await pendingPayment();
        await repo.approvePayment(p.id);
      }
      expect(await repo.markAllNotificationsRead(), 2);
      expect(await repo.fetchUnreadCount(), 0);
      expect(await repo.markAllNotificationsRead(), 0,
          reason: 'nothing left to mark');
    });

    test('moving members tells the receiving agent', () async {
      final agents = (await repo.fetchAgents()).where((a) => a.isActive).toList();
      final moved = await repo.reassignMembers(agents[0].id, agents[1].id);

      final list = await repo.fetchNotifications();
      expect(list, hasLength(moved));
      expect(list.first.kind, NotificationKind.memberAssigned);
      expect(list.first.link, AppRoutes.agentMembers);
    });
  });

  group('announcements', () {
    late InMemoryTrustRepository repo;

    setUp(() => repo = seededRepository());

    test('posting and reading back', () async {
      await repo.postAnnouncement(
        title: 'Office closed on Monday',
        body: 'Diwali holiday.',
      );
      final list = await repo.fetchAnnouncements();
      expect(list, hasLength(1));
      expect(list.first.title, 'Office closed on Monday');
      expect(list.first.isForEveryone, isTrue);
      expect(list.first.yojnaName, isEmpty);
    });

    test('a Yojna notice carries its name', () async {
      final yojna = (await repo.fetchYojnas()).first;
      await repo.postAnnouncement(title: 'Rate change', yojnaId: yojna.id);

      final first = (await repo.fetchAnnouncements()).first;
      expect(first.isForEveryone, isFalse);
      expect(first.yojnaName, yojna.name);
    });

    test('a title is required', () async {
      expect(
        () => repo.postAnnouncement(title: '   '),
        throwsA(isA<RepositoryException>().having(
          (e) => e.message,
          'message',
          contains('title'),
        )),
      );
    });

    test('deleting twice complains', () async {
      final id = await repo.postAnnouncement(title: 'Temporary');
      await repo.deleteAnnouncement(id);
      expect(await repo.fetchAnnouncements(), isEmpty);
      expect(
        () => repo.deleteAnnouncement(id),
        throwsA(isA<RepositoryException>()),
      );
    });
  });

  group('screens', () {
    // The repository's `Future.delayed` never fires on the fake clock, so
    // every repository call inside a widget test goes through `runAsync`.
    Future<(ProviderContainer, InMemoryTrustRepository)> pump(
      WidgetTester tester,
      Size size, {
      required UserRole role,
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);

      final repo = seededRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            authControllerProvider.overrideWith(() => _Auth(role)),
          ],
          child: const RudranshAdminApp(),
        ),
      );
      await tester.pumpAndSettle();
      return (
        ProviderScope.containerOf(
          tester.element(find.byType(RudranshAdminApp)),
        ),
        repo,
      );
    }

    for (final size in [const Size(390, 844), const Size(1440, 900)]) {
      testWidgets('announcements page lays out at ${size.width.toInt()} px',
          (tester) async {
        final (container, repo) =
            await pump(tester, size, role: UserRole.owner);
        await tester.runAsync(
          () => repo.postAnnouncement(
            title: 'Office closed on Monday',
            body: 'Diwali holiday.',
          ),
        );
        container.read(routerProvider).go(AppRoutes.announcements);
        await tester.pumpAndSettle();

        expect(find.text('Office closed on Monday'), findsOneWidget);
        expect(find.text(S.forEveryYojna), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('an admin posts from the page', (tester) async {
      final (container, repo) =
          await pump(tester, const Size(1440, 900), role: UserRole.owner);
      container.read(routerProvider).go(AppRoutes.announcements);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, S.newAnnouncement));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'Contribution due by Friday',
      );
      await tester.tap(find.widgetWithText(FilledButton, S.post));
      await tester.pumpAndSettle();

      expect(
        await tester.runAsync(repo.fetchAnnouncements),
        hasLength(1),
      );
      expect(find.text('Contribution due by Friday'), findsOneWidget);
    });

    testWidgets('a blank title is refused', (tester) async {
      final (container, repo) =
          await pump(tester, const Size(1440, 900), role: UserRole.owner);
      container.read(routerProvider).go(AppRoutes.announcements);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, S.newAnnouncement));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, S.post));
      await tester.pumpAndSettle();

      expect(find.text('Give the announcement a title.'), findsOneWidget);
      expect(await tester.runAsync(repo.fetchAnnouncements), isEmpty);
    });

    testWidgets('the bell shows a badge and the panel marks read',
        (tester) async {
      final (container, repo) =
          await pump(tester, const Size(1440, 900), role: UserRole.owner);

      await tester.runAsync(() async {
        final member = await _anyActiveMember(repo);
        final payment = await repo.createPayment(
          Payment(
            id: '',
            receiptNo: '',
            memberId: member.id,
            yojnaId: member.yojnaId,
            amount: 100,
            date: DateTime.now(),
            status: PaymentStatus.pending,
            kind: PaymentKind.contribution,
            agentId: member.agentId,
          ),
        );
        await repo.approvePayment(payment.id);
      });
      container.read(dataRevisionProvider.notifier).bump();
      await tester.pumpAndSettle();

      expect(container.read(unreadCountProvider), 1);

      await tester.tap(find.byType(NotificationsButton));
      await tester.pumpAndSettle();
      expect(find.text('Payment approved'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, S.markAllRead));
      await tester.pumpAndSettle();
      expect(container.read(unreadCountProvider), 0);
    });

    testWidgets('an empty panel says so', (tester) async {
      await pump(tester, const Size(1440, 900), role: UserRole.owner);

      await tester.tap(find.byType(NotificationsButton));
      await tester.pumpAndSettle();
      expect(find.text(S.noNotificationsHint), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // On a phone the header has no room for the bell, so it moves into the
    // avatar menu. Without this the panel would be unreachable on the screen
    // size most agents use.
    testWidgets('a phone reaches the panel from the avatar menu',
        (tester) async {
      await pump(tester, const Size(390, 844), role: UserRole.owner);
      expect(find.byType(NotificationsButton), findsNothing);

      await tester.tap(find.byTooltip('user@test.local'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.notifications).last);
      await tester.pumpAndSettle();

      expect(find.text(S.noNotificationsHint), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class _Auth extends AuthController {
  _Auth(this.role);

  final UserRole role;

  @override
  AuthState build() => AuthState(
        stage: AuthStage.signedIn,
        email: 'user@test.local',
        user: AppUser(
          id: 'user-1',
          name: 'Test User',
          email: 'user@test.local',
          role: role,
        ),
      );
}

/// The seeded demo data always has active members; any one of them will do.
Future<Member> _anyActiveMember(InMemoryTrustRepository repo) async {
  final page = await repo.fetchMembersPage(
    const MemberQuery(status: MemberStatus.active),
    offset: 0,
    limit: 20,
  );
  return page.items.first;
}

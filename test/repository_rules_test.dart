import 'package:flutter_test/flutter_test.dart';
import 'package:rudransh_ct/data/repositories/supabase_trust_repository.dart';
import 'package:rudransh_ct/data/repositories/trust_repository.dart';
import 'support/seed_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

void main() {
  group('delete rules match the database', () {
    test('a member with receipts cannot be deleted', () async {
      final repo = seededRepository();
      final payment = (await repo.fetchPayments()).first;

      await expectLater(
        repo.deleteMember(payment.memberId),
        throwsA(isA<RepositoryException>()),
      );
      expect(
        (await repo.fetchMembers()).any((m) => m.id == payment.memberId),
        isTrue,
      );
    });

    test('a scheme with members cannot be deleted', () async {
      final repo = seededRepository();
      final member = (await repo.fetchMembers()).first;

      await expectLater(
        repo.deleteYojna(member.yojnaId),
        throwsA(isA<RepositoryException>()),
      );
    });
  });

  group('describePostgrestError', () {
    String describe(String code, String message) =>
        SupabaseTrustRepository.describePostgrestError(
          PostgrestException(message: message, code: code),
        );

    test('explains a blocked member delete', () {
      expect(
        describe('23503',
            'update or delete on table "members" violates foreign key constraint "payments_member_id_fkey" on table "payments"'),
        contains('Inactive'),
      );
    });

    test('names the duplicate field', () {
      expect(
        describe('23505',
            'duplicate key value violates unique constraint "yojnas_code_key"'),
        contains('Yojna code'),
      );
    });

    test('explains a bad phone number', () {
      expect(
        describe('23514',
            'new row for relation "members" violates check constraint "members_primary_phone_check"'),
        contains('10 digits'),
      );
    });

    test('falls back to the server message', () {
      expect(describe('XX000', 'boom'), contains('boom'));
    });
  });
}

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'trust_repository.dart' show RepositoryException;

/// App logins for agents and members (IMPLEMENTATION_PLAN Phase 11).
abstract class AccessRepository {
  /// Agent id → whether their login profile is switched on. Agents who were
  /// never invited are absent.
  Future<Map<String, bool>> fetchAgentAccess();

  /// Emails [agent] an invite and gives them an agent login. Owner only.
  Future<void> inviteAgent(Agent agent);

  /// Member id → whether their login profile is switched on. Members who were
  /// never invited are absent.
  Future<Map<String, bool>> fetchMemberAccess();

  /// Emails [member] an invite at [email] and gives them a member login.
  /// Members have no email on their record, so the office supplies it. Owner
  /// only.
  Future<void> inviteMember(Member member, String email);
}

class SupabaseAccessRepository implements AccessRepository {
  SupabaseAccessRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, bool>> fetchAgentAccess() async {
    try {
      final rows = await _client
          .from('profiles')
          .select('agent_id, is_active')
          .eq('role', 'agent');
      return {
        for (final r in rows) r['agent_id'] as String: r['is_active'] as bool,
      };
    } on PostgrestException catch (e) {
      // Database without the roles migration yet.
      if (e.code == 'PGRST205' || e.code == '42P01') return const {};
      throw RepositoryException(e.message);
    }
  }

  @override
  Future<void> inviteAgent(Agent agent) async {
    try {
      await _client.functions.invoke('invite_user', body: {
        'role': 'agent',
        'agent_id': agent.id,
        'email': agent.email.trim().toLowerCase(),
        'name': agent.name,
      });
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map ? details['error'] as String? : null;
      throw RepositoryException(
        message ?? 'Could not send the invite (${e.status}). Try again later.',
      );
    }
  }

  @override
  Future<Map<String, bool>> fetchMemberAccess() async {
    try {
      final rows = await _client
          .from('profiles')
          .select('member_id, is_active')
          .eq('role', 'member');
      return {
        for (final r in rows) r['member_id'] as String: r['is_active'] as bool,
      };
    } on PostgrestException catch (e) {
      // Database without the roles migration yet.
      if (e.code == 'PGRST205' || e.code == '42P01') return const {};
      throw RepositoryException(e.message);
    }
  }

  @override
  Future<void> inviteMember(Member member, String email) async {
    try {
      await _client.functions.invoke('invite_user', body: {
        'role': 'member',
        'member_id': member.id,
        'email': email.trim().toLowerCase(),
        'name': member.name,
      });
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map ? details['error'] as String? : null;
      throw RepositoryException(
        message ?? 'Could not send the invite (${e.status}). Try again later.',
      );
    }
  }
}

/// Demo mode and widget tests: remembers invites in memory.
class InMemoryAccessRepository implements AccessRepository {
  final _agents = <String, bool>{};
  final _members = <String, bool>{};

  @override
  Future<Map<String, bool>> fetchAgentAccess() async => Map.of(_agents);

  @override
  Future<void> inviteAgent(Agent agent) async {
    if (_agents.containsKey(agent.id)) {
      throw const RepositoryException('This agent already has app access.');
    }
    _agents[agent.id] = true;
  }

  @override
  Future<Map<String, bool>> fetchMemberAccess() async => Map.of(_members);

  @override
  Future<void> inviteMember(Member member, String email) async {
    if (member.status == MemberStatus.pending) {
      throw const RepositoryException('Approve the member before inviting them.');
    }
    if (_members.containsKey(member.id)) {
      throw const RepositoryException('This member already has app access.');
    }
    _members[member.id] = true;
  }
}

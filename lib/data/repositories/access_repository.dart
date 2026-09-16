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
}

/// Demo mode and widget tests: remembers invites in memory.
class InMemoryAccessRepository implements AccessRepository {
  final _agents = <String, bool>{};

  @override
  Future<Map<String, bool>> fetchAgentAccess() async => Map.of(_agents);

  @override
  Future<void> inviteAgent(Agent agent) async {
    if (_agents.containsKey(agent.id)) {
      throw const RepositoryException('This agent already has app access.');
    }
    _agents[agent.id] = true;
  }
}

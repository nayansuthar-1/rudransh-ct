import 'dart:math';

import 'package:rudransh_ct/data/models/models.dart';
import 'package:rudransh_ct/data/repositories/in_memory_trust_repository.dart';

/// Deterministic dataset for the test suite only.
///
/// It lives under `test/` on purpose: the app ships no sample records, so a
/// demo build and a fresh Supabase project both start empty.
/// Use [seededRepository] to get an [InMemoryTrustRepository] holding it.
class SeedData {
  SeedData._();

  static final _rng = Random(20260823);
  static final _now = DateTime(2026, 8, 23);

  static final List<Yojna> yojnas = [
    Yojna(
      id: 'y_ssy',
      name: 'सुरक्षा सहयोग योजना',
      code: 'SSY',
      description:
          'सदस्य की मृत्यु पर वारिसदार को सहयोग राशि प्रदान की जाती है।',
      claimAmount: 200000,
      registrationFee: 500,
      createdAt: DateTime(2023, 4, 12),
    ),
    Yojna(
      id: 'y_mamera',
      name: 'मामेरा (मायरा) सहयोग योजना',
      code: 'MSY',
      description:
          'पुत्री के विवाह पर मामेरा हेतु सामूहिक सहयोग राशि।',
      claimAmount: 101000,
      registrationFee: 300,
      createdAt: DateTime(2024, 1, 8),
    ),
    Yojna(
      id: 'y_shadi',
      name: 'शादी सहयोग योजना',
      code: 'SHY',
      description: 'सदस्य परिवार में विवाह पर सहयोग राशि।',
      claimAmount: 75000,
      registrationFee: 251,
      createdAt: DateTime(2024, 9, 21),
    ),
  ];

  // What each Yojna's members pay per closing.
  static const _contribution = {
    'y_ssy': 100.0,
    'y_mamera': 60.0,
    'y_shadi': 51.0,
  };

  static const _firstNames = [
    'रामलाल', 'मोहन', 'सुरेश', 'कैलाश', 'भंवर', 'गोपाल', 'महेश', 'दिनेश',
    'प्रकाश', 'हरीश', 'नारायण', 'शंकर', 'बाबूलाल', 'जगदीश', 'ओमप्रकाश',
    'सुशीला', 'गीता', 'कमला', 'सुनीता', 'मंजू', 'राधा', 'सीता', 'अनीता',
  ];

  static const _fatherNames = [
    'हीरालाल', 'छगनलाल', 'मांगीलाल', 'देवीलाल', 'रूपचंद', 'नाथूराम',
    'पन्नालाल', 'तेजाराम', 'भैरूलाल', 'चुन्नीलाल', 'गंगाराम', 'सोहनलाल',
  ];

  static const _surnames = [
    'सुथार', 'जाट', 'मीणा', 'गुर्जर', 'शर्मा', 'प्रजापत', 'सैनी', 'माली',
    'कुमावत', 'राजपूत', 'बिश्नोई', 'चौधरी',
  ];

  static const _jatis = [
    'सुथार', 'जाट', 'मीणा', 'गुर्जर', 'ब्राह्मण', 'प्रजापत', 'सैनी', 'माली',
    'कुमावत', 'राजपूत',
  ];

  static const _gotras = [
    'कश्यप', 'भारद्वाज', 'गौतम', 'वत्स', 'पराशर', 'सांखला', 'चौहान', '',
  ];

  static const _relations = ['पुत्र', 'पुत्री', 'पत्नी', 'पति', 'भाई', 'माता'];

  static const _villages = [
    'बगड़', 'चिड़ावा', 'सूरजगढ़', 'नवलगढ़', 'उदयपुरवाटी', 'खेतड़ी',
    'मुकुंदगढ़', 'बिसाऊ', 'मंडावा', 'गुढ़ा',
  ];

  static const _tehsils = ['झुंझुनूं', 'चिड़ावा', 'नवलगढ़', 'खेतड़ी', 'सूरजगढ़'];
  static const _districts = ['झुंझुनूं', 'सीकर', 'चूरू', 'नागौर'];

  /// Every seeded district is in Rajasthan, so the certificate's राज्य line
  /// matches the address above it.
  static const _state = 'राजस्थान';

  static const _agentNames = [
    'रमेश कुमार सुथार',
    'विकास चौधरी',
    'सुनील कुमार मीणा',
    'अनिल प्रजापत',
    'पूजा शर्मा',
    'महावीर सिंह राजपूत',
  ];

  static T _pick<T>(List<T> list) => list[_rng.nextInt(list.length)];

  static String _phone() =>
      '${_pick(const ['6', '7', '8', '9'])}'
      '${List.generate(9, (_) => _rng.nextInt(10)).join()}';

  static String _aadhaar() =>
      List.generate(12, (_) => _rng.nextInt(10)).join();

  static List<Agent> agents() {
    return List.generate(_agentNames.length, (i) {
      return Agent(
        id: 'a_${i + 1}',
        code: 'AG-${(i + 1).toString().padLeft(3, '0')}',
        name: _agentNames[i],
        phone: _phone(),
        email:
            'agent${i + 1}@rudranshct.org',
        area: _villages[i % _villages.length],
        district: _districts[i % _districts.length],
        commissionPercent: [2.0, 2.5, 3.0, 1.5][i % 4],
        yojnaIds: i.isEven
            ? yojnas.map((y) => y.id).toList()
            : [yojnas[i % yojnas.length].id],
        isActive: i != 5,
        joinDate: DateTime(2024, 1 + (i % 12), 5 + (i % 20)),
      );
    });
  }

  static List<Member> members(List<Agent> agentList) {
    final result = <Member>[];
    final counters = <String, int>{for (final y in yojnas) y.id: 0};

    for (var i = 0; i < 148; i++) {
      // Weighted so सुरक्षा सहयोग योजना holds the majority of members.
      const weights = [0, 0, 0, 0, 1, 1, 2];
      final yojna = yojnas[weights[i % weights.length]];
      final n = (counters[yojna.id] ?? 0) + 1;
      counters[yojna.id] = n;

      final joinYear = 2024 + (i % 3);
      final join = DateTime(joinYear, 1 + (i % 12), 1 + (i % 27));
      final name = '${_pick(_firstNames)} ${_pick(_surnames)}';

      // ~8% of members are closed cases, ~12% inactive.
      final roll = _rng.nextInt(100);
      final status = roll < 8
          ? MemberStatus.closed
          : (roll < 20 ? MemberStatus.inactive : MemberStatus.active);

      final closingDate = status == MemberStatus.closed
          ? _now.subtract(Duration(days: _rng.nextInt(240) + 5))
          : null;

      result.add(
        Member(
          id: 'm_${i + 1}',
          yojnaId: yojna.id,
          regNo:
              '${yojna.code}-$joinYear-${n.toString().padLeft(4, '0')}',
          name: name,
          fatherOrHusbandName: '${_pick(_fatherNames)} ${_pick(_surnames)}',
          jati: _pick(_jatis),
          gotra: _pick(_gotras),
          dob: DateTime(1950 + _rng.nextInt(50), 1 + _rng.nextInt(12),
              1 + _rng.nextInt(28)),
          warisName: '${_pick(_firstNames)} ${_pick(_surnames)}',
          warisRelation: _pick(_relations),
          gender: i % 7 == 0 ? Gender.female : Gender.male,
          primaryPhone: _phone(),
          altPhone: i % 4 == 0 ? _phone() : '',
          aadhaar: _aadhaar(),
          village: _pick(_villages),
          tehsil: _pick(_tehsils),
          district: _pick(_districts),
          state: _state,
          pincode: '3330${_rng.nextInt(10)}${_rng.nextInt(10)}',
          agentId: agentList[i % agentList.length].id,
          joinDate: join,
          status: status,
          contributionAmount: _contribution[yojna.id]!,
          closingDate: closingDate,
          closingGroup: closingDate == null
              ? null
              : 'Group-${8 + (i % 9)}',
        ),
      );
    }
    return result;
  }

  static List<ClosingCase> closingCases(List<Member> memberList) {
    final closed = memberList.where((m) => m.isClosed).toList()
      ..sort((a, b) => b.closingDate!.compareTo(a.closingDate!));

    return List.generate(closed.length, (i) {
      final m = closed[i];
      final yojna = yojnas.firstWhere((y) => y.id == m.yojnaId);
      final collectedRatio = [1.0, 1.0, 0.62, 0.35, 0.0][i % 5];
      final collected = yojna.claimAmount * collectedRatio;
      final payStatus = collectedRatio >= 1
          ? ClosingPayStatus.paid
          : (collectedRatio > 0
              ? ClosingPayStatus.partial
              : ClosingPayStatus.unpaid);

      return ClosingCase(
        id: 'c_${i + 1}',
        memberId: m.id,
        yojnaId: m.yojnaId,
        closingDate: m.closingDate!,
        closingGroup: m.closingGroup ?? 'Group-1',
        claimAmount: yojna.claimAmount,
        collectedAmount: collected,
        payStatus: payStatus,
        nomineeName: m.warisName,
      );
    });
  }

  static List<Payment> payments(List<Member> memberList) {
    final result = <Payment>[];
    final active =
        memberList.where((m) => m.status != MemberStatus.inactive).toList();
    var receipt = 1000;

    for (var monthsAgo = 7; monthsAgo >= 0; monthsAgo--) {
      final base = DateTime(_now.year, _now.month - monthsAgo, 1);
      final count = 40 + _rng.nextInt(25);
      for (var i = 0; i < count; i++) {
        final member = active[_rng.nextInt(active.length)];
        final yojna = yojnas.firstWhere((y) => y.id == member.yojnaId);
        final day = 1 + _rng.nextInt(26);
        final date = DateTime(base.year, base.month, day);
        if (date.isAfter(_now)) continue;

        final kindRoll = _rng.nextInt(100);
        final kind = kindRoll < 10
            ? PaymentKind.registration
            : PaymentKind.contribution;
        final amount = kind == PaymentKind.registration
            ? yojna.registrationFee
            : member.contributionAmount * (1 + _rng.nextInt(4));

        final statusRoll = _rng.nextInt(100);
        result.add(
          Payment(
            id: 'p_${result.length + 1}',
            receiptNo: 'RCP-${++receipt}',
            memberId: member.id,
            yojnaId: member.yojnaId,
            amount: amount,
            date: date,
            mode: PaymentMode.values[_rng.nextInt(PaymentMode.values.length)],
            status: statusRoll < 88
                ? PaymentStatus.paid
                : (statusRoll < 97
                    ? PaymentStatus.pending
                    : PaymentStatus.failed),
            kind: kind,
            agentId: member.agentId,
            reference: '',
          ),
        );
      }
    }

    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }
}

/// An in-memory repository preloaded with the dataset above.
InMemoryTrustRepository seededRepository({
  Duration latency = Duration.zero,
}) {
  final repo = InMemoryTrustRepository(latency: latency);
  final agents = SeedData.agents();
  final members = SeedData.members(agents);
  repo.loadFixture(
    yojnas: SeedData.yojnas,
    agents: agents,
    members: members,
    closingCases: SeedData.closingCases(members),
    payments: SeedData.payments(members),
  );
  return repo;
}

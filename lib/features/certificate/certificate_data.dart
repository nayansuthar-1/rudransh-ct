import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';

/// Everything the membership certificate prints, flattened out of the member,
/// their Yojna, their agent and their registration payment.
///
/// Kept free of Flutter and of the repositories so the HTML template can be
/// built and tested on its own (docs/MEMBERSHIP_CERTIFICATE_PLAN.md §2).
@immutable
class CertificateData {
  const CertificateData({
    required this.regNo,
    required this.issuedOn,
    required this.name,
    this.fatherOrHusbandName = '',
    this.yojnaName = '',
    this.yojnaStartedOn,
    this.yojnaShortName = '',
    this.contributionAmount = 0,
    this.payoutNote = '',
    this.gotra = '',
    this.jati = '',
    this.dob,
    this.village = '',
    this.district = '',
    this.state = '',
    this.address = '',
    this.phone = '',
    this.warisName = '',
    this.warisRelation = '',
    this.agentName = '',
    this.photoUrl = '',
  });

  /// Pulls the certificate together for one member. The amount is the
  /// member's own: members of one Yojna pay different amounts. Anything
  /// unknown is left empty and prints as a blank dotted line.
  ///
  /// [agentName] is for the agent screens, which know the signed-in agent's
  /// name but not their `Agent` record; it wins over [agent].
  factory CertificateData.forMember({
    required Member member,
    Yojna? yojna,
    Agent? agent,
    DateTime? issuedOn,
    String agentName = '',
  }) {
    return CertificateData(
      regNo: member.regNo,
      issuedOn: issuedOn ?? DateTime.now(),
      name: member.name,
      fatherOrHusbandName: member.fatherOrHusbandName,
      yojnaName: yojna?.name ?? '',
      yojnaStartedOn: yojna?.startDate ?? yojna?.createdAt,
      yojnaShortName: yojna?.shortName ?? '',
      contributionAmount: member.contributionAmount,
      payoutNote: yojna?.description ?? '',
      gotra: member.gotra,
      jati: member.jati,
      dob: member.dob,
      village: member.village,
      district: member.district,
      state: member.state,
      address: member.address,
      phone: member.primaryPhone,
      warisName: member.warisName,
      warisRelation: member.warisRelation,
      agentName: agentName.isNotEmpty ? agentName : (agent?.name ?? ''),
      photoUrl: member.photoUrl,
    );
  }

  /// `सदस्यता क्रमांक`.
  final String regNo;

  /// `दिनांक` — the day the certificate is printed.
  final DateTime issuedOn;

  final String name;
  final String fatherOrHusbandName;

  /// The scheme and its start date.
  final String yojnaName;
  final DateTime? yojnaStartedOn;

  /// The Yojna's word for the सहयोग राशि label, e.g. `शादी`. Empty takes it
  /// from [yojnaName].
  final String yojnaShortName;

  /// What the member pays for each closing.
  final double contributionAmount;

  /// The `नोंध` line: what the nominee is paid and when.
  final String payoutNote;

  final String gotra;
  final String jati;
  final DateTime? dob;
  final String village;
  final String district;
  final String state;
  final String address;
  final String phone;

  /// Nominee and their relation to the member.
  final String warisName;
  final String warisRelation;

  /// `कार्यकर्ता` — the agent who enrolled the member.
  final String agentName;

  final String photoUrl;

  /// Name as the certificate writes it: the member's own name followed by
  /// their father's or husband's, as on the sample.
  String get fullName =>
      [name, fatherOrHusbandName].where((p) => p.trim().isNotEmpty).join(' ');

  /// The सहयोग राशि label, naming the Yojna: `प्रत्येक शादी सहयोग राशि`.
  String get contributionLabel =>
      Yojna.certificateLabel(name: yojnaName, shortName: yojnaShortName);
}

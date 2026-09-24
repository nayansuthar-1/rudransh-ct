import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/member_text.dart';
import '../core/utils/local_store.dart';

const _storeKey = 'rudransh.member_lang';

/// The member side's language: Hindi unless this browser chose English
/// before. Remembered per browser, since members sign in rarely or never.
class MemberLangNotifier extends Notifier<MemberLang> {
  @override
  MemberLang build() =>
      readLocal(_storeKey) == MemberLang.en.name ? MemberLang.en : MemberLang.hi;

  void toggle() => set(state == MemberLang.hi ? MemberLang.en : MemberLang.hi);

  void set(MemberLang lang) {
    state = lang;
    writeLocal(_storeKey, lang.name);
  }
}

final memberLangProvider =
    NotifierProvider<MemberLangNotifier, MemberLang>(MemberLangNotifier.new);

/// The member screens' words in the chosen language.
final memberTextProvider =
    Provider<MemberText>((ref) => MemberText(ref.watch(memberLangProvider)));

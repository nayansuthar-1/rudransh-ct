import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/member_lang.dart';

/// हिंदी | English switch for the member screens and the public lookup. It
/// names the language it switches to, so a member who reads only one of the
/// two can always find their way back.
class MemberLangToggle extends ConsumerWidget {
  const MemberLangToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(memberTextProvider);
    return Tooltip(
      message: t.switchTooltip,
      child: TextButton.icon(
        onPressed: () => ref.read(memberLangProvider.notifier).toggle(),
        icon: const Icon(Icons.translate_rounded, size: 17),
        label: Text(t.switchLabel),
      ),
    );
  }
}

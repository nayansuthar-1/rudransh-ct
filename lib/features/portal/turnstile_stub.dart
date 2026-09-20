import 'package:flutter/widgets.dart';

/// Non-web builds: nothing to render and no token to give.
///
/// A configured deployment then refuses the lookup, which is what should
/// happen — the check is missing, so the answer is withheld.
class TurnstileWidget extends StatelessWidget {
  const TurnstileWidget({
    super.key,
    required this.siteKey,
    required this.onToken,
    this.dark = false,
  });

  final String siteKey;

  /// Called with a fresh token, and with an empty string when one expires or
  /// the check fails.
  final ValueChanged<String> onToken;
  final bool dark;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/responsive/breakpoints.dart';

/// Export CSV beside a page's main button. On a phone it is the icon alone,
/// so the two still fit beside the page title.
class ExportCsvButton extends StatelessWidget {
  const ExportCsvButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const icon = Icon(Icons.download_outlined, size: 17);
    if (context.isMobile) {
      return IconButton.outlined(
        tooltip: S.exportCsv,
        onPressed: onPressed,
        icon: icon,
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: const Text(S.exportCsv),
    );
  }
}

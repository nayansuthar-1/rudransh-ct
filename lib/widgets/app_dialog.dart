import 'package:flutter/material.dart';

import '../core/l10n/strings.dart';
import '../core/responsive/breakpoints.dart';
import '../core/theme/app_colors.dart';

/// Dialog shell that becomes a full-screen sheet on phones and a centred
/// panel on larger screens. Header and footer stay pinned while the body
/// scrolls.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.maxWidth = 900,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final double maxWidth;
  final IconData? icon;

  /// Convenience wrapper around [showDialog] with the right insets per size.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) {
    final fullScreen = context.isMobile;
    return showDialog<T>(
      context: context,
      barrierDismissible: !fullScreen,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (context) => Dialog(
        insetPadding: fullScreen
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(fullScreen ? 0 : 18),
        ),
        child: builder(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fullScreen = context.isMobile;
    final media = MediaQuery.sizeOf(context);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: fullScreen ? media.width : maxWidth,
        maxHeight: fullScreen ? media.height : media.height * 0.9,
        minWidth: fullScreen ? media.width : 0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(
              fullScreen ? 14 : 22,
              fullScreen ? 12 : 18,
              fullScreen ? 8 : 14,
              fullScreen ? 12 : 18,
            ),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(bottom: BorderSide(color: c.border)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Close',
                  style: IconButton.styleFrom(foregroundColor: c.textSecondary),
                ),
                const SizedBox(width: 4),
                if (icon != null) ...[
                  Icon(icon, size: 20, color: c.brand),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: fullScreen ? 16 : 18,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: c.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body
          Flexible(
            child: Container(
              width: double.infinity,
              color: c.surface,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: fullScreen ? 14 : 22,
                  vertical: fullScreen ? 16 : 20,
                ),
                child: child,
              ),
            ),
          ),

          // Footer
          if (actions.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: fullScreen ? 14 : 22,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: c.surfaceMuted,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    if (fullScreen)
                      Expanded(child: actions[i])
                    else
                      actions[i],
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Yes/no confirmation, used before destructive actions.
Future<bool> confirmDialog(
  BuildContext context, {
  String title = S.confirmDelete,
  String message = S.confirmDeleteBody,
  String confirmLabel = S.delete,
  bool destructive = true,
}) async {
  final c = context.colors;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 17)),
      content: Text(
        message,
        style: TextStyle(fontSize: 13.5, color: c.textSecondary),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(S.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: c.danger)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// One-line feedback toast.
void showToast(BuildContext context, String message, {bool error = false}) {
  final c = context.colors;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              size: 18,
              color: error ? c.danger : c.success,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(seconds: 3),
        width: context.isMobile ? null : 420,
        margin: context.isMobile ? const EdgeInsets.all(12) : null,
      ),
    );
}

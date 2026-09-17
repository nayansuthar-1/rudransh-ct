import 'package:flutter/material.dart';

import '../core/l10n/strings.dart';
import '../core/responsive/breakpoints.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

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
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final double maxWidth;

  /// Convenience wrapper around [showDialog] with the right insets per size.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) {
    final fullScreen = context.isMobile;
    return showDialog<T>(
      context: context,
      barrierDismissible: !fullScreen,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (context) => Dialog(
        insetPadding: fullScreen
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        clipBehavior: Clip.antiAlias,
        shape: fullScreen
            ? const RoundedRectangleBorder()
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.dialog),
                side: BorderSide(color: context.colors.border),
              ),
        child: builder(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fullScreen = context.isMobile;
    final media = MediaQuery.of(context);
    final gutter = fullScreen ? 16.0 : 24.0;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: fullScreen ? media.size.width : maxWidth,
        maxHeight: fullScreen ? media.size.height : media.size.height * 0.9,
        minWidth: fullScreen ? media.size.width : 0,
        minHeight: fullScreen ? media.size.height : 0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(
              gutter,
              (fullScreen ? media.padding.top : 0) + (fullScreen ? 12 : 20),
              fullScreen ? 8 : 14,
              fullScreen ? 12 : 16,
            ),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(bottom: BorderSide(color: c.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w400,
                          color: c.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: c.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close, size: 19),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          // Body. Material, not a coloured box, so list tiles in forms can
          // paint their ink on it.
          Flexible(
            fit: fullScreen ? FlexFit.tight : FlexFit.loose,
            child: Material(
              color: c.surface,
              child: SizedBox(
                width: double.infinity,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(gutter, Space.xl, gutter, Space.xxl),
                  child: child,
                ),
              ),
            ),
          ),

          // Footer
          if (actions.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                gutter,
                Space.md,
                gutter,
                Space.md + (fullScreen ? media.padding.bottom : 0),
              ),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: Space.sm),
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

/// Spinner sized for a filled button while it saves.
class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: context.colors.onBrand,
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
    barrierColor: Colors.black.withValues(alpha: 0.32),
    builder: (context) => AlertDialog(
      constraints: const BoxConstraints(maxWidth: 420),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Text(title),
      content: Text(
        message,
        style: TextStyle(fontSize: 13.5, color: c.textSecondary, height: 1.5),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(S.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: c.danger,
                  foregroundColor: Colors.white,
                )
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
              size: 17,
              color: error ? c.dangerSoft : c.successSoft,
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

/// Runs a delete (or other one-shot action) and reports the outcome as a
/// toast, including database refusals such as "member has receipts".
Future<void> runWithToast(
  BuildContext context,
  Future<void> Function() action, {
  required String success,
}) async {
  try {
    await action();
    if (context.mounted) showToast(context, success);
  } catch (e) {
    if (context.mounted) showToast(context, '$e', error: true);
  }
}

/// Asks for a short reason (reject, cancel). Returns null when dismissed.
Future<String?> reasonDialog(
  BuildContext context, {
  required String title,
  String message = '',
  String confirmLabel = S.reject,
  bool destructive = true,
}) {
  final c = context.colors;
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();

  void submit(BuildContext dialogContext) {
    if (formKey.currentState?.validate() ?? false) {
      Navigator.of(dialogContext).pop(controller.text.trim());
    }
  }

  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    builder: (dialogContext) => AlertDialog(
      constraints: const BoxConstraints(maxWidth: 420),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Text(title),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.isNotEmpty) ...[
              Text(
                message,
                style: TextStyle(
                  fontSize: 13.5,
                  color: c.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: controller,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(hintText: S.reason),
              validator: (v) => (v ?? '').trim().isEmpty ? S.required : null,
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text(S.cancel),
        ),
        FilledButton(
          onPressed: () => submit(dialogContext),
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: c.danger,
                  foregroundColor: Colors.white,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

import 'package:flutter/material.dart';

import '../core/responsive/breakpoints.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';

/// Hairline-bordered panel. The only boxed container in the app: tables,
/// lists and stat strips sit inside one, directly on the white canvas.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.onTap,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const radius = BorderRadius.all(Radius.circular(Radii.panel));
    final content = Padding(padding: padding, child: child);

    return Material(
      color: c.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: borderColor ?? c.border),
      ),
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, hoverColor: c.hover, child: content),
    );
  }
}

/// Title, optional subtitle and trailing actions.
///
/// The default size heads a page; [dense] heads a section inside a page.
/// Actions sit to the right while they fit and move under the title on
/// narrow screens, so nothing is ever pushed off the edge.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mobile = context.isMobile;

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 8)],
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: dense ? 16 : (mobile ? 22 : 24),
                  fontWeight: dense ? FontWeight.w600 : FontWeight.w700,
                  color: c.textPrimary,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          SizedBox(height: dense ? 2 : Space.xs),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: dense ? 13 : 14,
              color: c.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ],
    );

    if (actions.isEmpty) return titleBlock;

    final actionWrap = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: actions,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Actions are one or two short buttons, so they stay beside the title
        // down to phone width; the title wraps first.
        if (constraints.maxWidth < 330) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleBlock, const SizedBox(height: 12), actionWrap],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 12),
            actionWrap,
          ],
        );
      },
    );
  }
}

enum PillTone { neutral, success, warning, danger, info, brand }

/// Small status label used across tables.
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.tone = PillTone.neutral});

  final String label;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (fg, bg) = switch (tone) {
      PillTone.success => (c.success, c.successSoft),
      PillTone.warning => (c.warning, c.warningSoft),
      PillTone.danger => (c.danger, c.dangerSoft),
      PillTone.info => (c.info, c.infoSoft),
      PillTone.brand => (c.onBrandSoft, c.brandSoft),
      PillTone.neutral => (c.textSecondary, c.surfaceMuted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: fg,
          height: 1.35,
        ),
      ),
    );
  }
}

/// Neutral initials avatar.
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.name, this.size = 32});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        shape: BoxShape.circle,
        border: Border.all(color: c.border),
      ),
      child: Text(
        Fmt.initials(name),
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w600,
          color: c.textSecondary,
          height: 1,
        ),
      ),
    );
  }
}

/// Placeholder shown when a list resolves to nothing.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    this.compact = false,
  });

  final String message;
  final IconData icon;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 28 : 56, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 20 : 24, color: c.textMuted),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 13.5),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.height = 200});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class ErrorStateView extends StatelessWidget {
  const ErrorStateView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: c.danger, size: 22),
          const SizedBox(height: 10),
          Text(
            '$error',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 13),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Key/value row used inside detail sheets. Stacks label over value when the
/// sheet is too narrow for two columns.
class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final labelText = Text(
      label,
      style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.4),
    );
    final valueText = Text(
      value.isEmpty ? '—' : value,
      style: TextStyle(
        fontSize: 13.5,
        color: c.textPrimary,
        fontWeight: FontWeight.w500,
        height: 1.4,
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 380) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [labelText, const SizedBox(height: 2), valueText],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 160, child: labelText),
                const SizedBox(width: 12),
                Expanded(child: valueText),
              ],
            );
          },
        ),
      ),
    );
  }
}

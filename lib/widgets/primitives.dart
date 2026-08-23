import 'package:flutter/material.dart';

import '../core/responsive/breakpoints.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';

/// Bordered white panel used for every section of the panel.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final content = Padding(
      padding: padding ?? EdgeInsets.all(context.responsive(mobile: 14.0, tablet: 18.0)),
      child: child,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor ?? c.border),
      ),
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onTap,
                child: content,
              ),
            ),
    );
  }
}

/// Title + optional subtitle and trailing actions for a card or page section.
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
                  fontSize: dense ? 15 : 17,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitle!,
            style: TextStyle(fontSize: 12.5, color: c.textSecondary),
          ),
        ],
      ],
    );

    if (actions.isEmpty) return titleBlock;

    // A Wrap keeps the actions on the same line while they fit and drops them
    // to their own line — never overflowing — once they do not.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        titleBlock,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: actions,
        ),
      ],
    );
  }
}

enum PillTone { neutral, success, warning, danger, info, brand }

/// Small rounded status label used across tables.
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.tone = PillTone.neutral, this.icon});

  final String label;
  final PillTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (fg, bg) = switch (tone) {
      PillTone.success => (c.success, c.successSoft),
      PillTone.warning => (c.warning, c.warningSoft),
      PillTone.danger => (c.danger, c.dangerSoft),
      PillTone.info => (c.info, c.infoSoft),
      PillTone.brand => (c.brand, c.brandSoft),
      PillTone.neutral => (c.textSecondary, c.surfaceMuted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: fg,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular initials avatar.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.size = 36,
    this.color,
  });

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Stable per-name hue so the same person keeps the same swatch.
    const palette = [
      Color(0xFF2563EB),
      Color(0xFF7C3AED),
      Color(0xFF0891B2),
      Color(0xFFDB2777),
      Color(0xFF16A34A),
      Color(0xFFEA580C),
    ];
    final base = color ?? palette[name.hashCode.abs() % palette.length];

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: base.withValues(alpha: 0.25)),
      ),
      child: Text(
        Fmt.initials(name),
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: c.brightnessIsDark ? base.lighten() : base,
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
      padding: EdgeInsets.symmetric(vertical: compact ? 26 : 48, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 42 : 56,
            height: compact ? 42 : 56,
            decoration: BoxDecoration(
              color: c.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: compact ? 20 : 26, color: c.textMuted),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 13.5),
          ),
          if (action != null) ...[const SizedBox(height: 14), action!],
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
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.4),
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
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: c.danger, size: 28),
          const SizedBox(height: 10),
          Text(
            '$error',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 13),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
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

/// Key/value row used inside detail sheets.
class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: c.textSecondary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(
                fontSize: 13.5,
                color: c.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension on AppColors {
  bool get brightnessIsDark =>
      ThemeData.estimateBrightnessForColor(surface) == Brightness.dark;
}

extension on Color {
  Color lighten([double amount = 0.3]) {
    final hsl = HSLColor.fromColor(this);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }
}

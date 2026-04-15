import 'package:flutter/material.dart';

/// Section header: xs font-bold uppercase tracking-[2px] text-primary.
class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
      // Wrap with Semantics so TalkBack/VoiceOver reads the natural-case title
      // rather than spelling out the uppercase letters individually.
      child: Semantics(
        label: title,
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// Settings group card: bg-surface-container-lowest rounded-2xl p-2.
class SettingsCard extends StatelessWidget {
  const SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: children,
      ),
    );
  }
}

/// Settings row with a title/subtitle label and a control placed on the right.
///
/// Falls back to a vertical layout (label on top, control right-aligned below)
/// on narrow widths so long selection values never crush the title.
class SettingsControlRow extends StatelessWidget {
  const SettingsControlRow({
    super.key,
    required this.title,
    required this.control,
    this.subtitle,
    this.breakpoint = 360,
  });

  final String title;
  final String? subtitle;
  final Widget control;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: theme.textTheme.bodyLarge),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = constraints.maxWidth < breakpoint;
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label,
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: control,
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: label),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: control,
              ),
            ],
          );
        },
      ),
    );
  }
}

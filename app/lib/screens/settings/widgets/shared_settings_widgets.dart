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

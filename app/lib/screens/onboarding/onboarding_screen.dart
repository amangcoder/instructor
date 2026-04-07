import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/screens/onboarding/widgets/template_picker_sheet.dart';

// ── Page data ─────────────────────────────────────────────────────────────────

class _PageData {
  const _PageData({
    required this.illustrationIcon,
    required this.illustrationColor,
    required this.title,
    required this.subtitle,
  });

  final IconData illustrationIcon;
  final Color illustrationColor;
  final String title;
  final String subtitle;
}

const List<_PageData> _pages = [
  _PageData(
    illustrationIcon: Icons.playlist_add_check_rounded,
    illustrationColor: Color(0xFF5B6BE8),
    title: 'Create Plans',
    subtitle:
        'Build timed scripts of voice instructions, notifications, and audio '
        'for anything in your life.',
  ),
  _PageData(
    illustrationIcon: Icons.headphones_rounded,
    illustrationColor: Color(0xFF7C5CBF),
    title: 'Runs in Background',
    subtitle:
        'Press play and put your phone away. Instructions come through your '
        'speaker or headphones.',
  ),
  _PageData(
    illustrationIcon: Icons.library_books_rounded,
    illustrationColor: Color(0xFF38A169),
    title: 'Start with Templates',
    subtitle:
        'Choose from 15 ready-made Plans or build your own from scratch.',
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

/// First-launch onboarding screen.
///
/// Displays a 3-page [PageView] carousel that explains the core concept of the
/// Instructor app.  After the last page the "Get Started" button opens a
/// [TemplatePickerSheet] so the user can choose a starter Plan or begin from
/// scratch.
///
/// Completing the flow (choosing a template or starting from scratch) writes
/// [AppSettingsKeys.hasCompletedOnboarding] = `'true'` to the Drift database
/// so the onboarding is not shown again on subsequent launches.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── Navigation helpers ────────────────────────────────────────────────────

  bool get _isLastPage => _currentPage == _pages.length - 1;

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _skip() {
    _pageController.animateToPage(
      _pages.length - 1,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _getStarted() async {
    await showTemplatePickerSheet(context);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip button ───────────────────────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: AnimatedOpacity(
                opacity: _isLastPage ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 8),
                  child: TextButton(
                    onPressed: _isLastPage ? null : _skip,
                    child: const Text('Skip'),
                  ),
                ),
              ),
            ),

            // ── PageView ──────────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  return _OnboardingPage(data: _pages[index]);
                },
              ),
            ),

            // ── Dot indicators ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: _DotIndicator(
                count: _pages.length,
                current: _currentPage,
              ),
            ),

            // ── Action buttons ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _isLastPage
                    ? SizedBox(
                        key: const ValueKey('get-started'),
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _getStarted,
                          child: const Text('Get Started'),
                        ),
                      )
                    : SizedBox(
                        key: const ValueKey('next'),
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _nextPage,
                          child: const Text('Next'),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Single onboarding page ────────────────────────────────────────────────────

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _PageData data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration area
          _IllustrationPlaceholder(
            icon: data.illustrationIcon,
            color: data.illustrationColor,
          ),
          const SizedBox(height: 40),

          // Title
          Text(
            data.title,
            style: textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Subtitle
          Text(
            data.subtitle,
            style: textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.55,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Illustration placeholder ──────────────────────────────────────────────────

/// Placeholder illustration shown on each onboarding page.
///
/// When real illustration assets are added to `assets/images/onboarding/`,
/// replace this widget with an [Image.asset] call.
class _IllustrationPlaceholder extends StatelessWidget {
  const _IllustrationPlaceholder({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.25),
            color.withValues(alpha: 0.08),
          ],
          radius: 0.8,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          icon,
          size: 96,
          color: color,
        ),
      ),
    );
  }
}

// ── Dot indicator ─────────────────────────────────────────────────────────────

/// A row of animated dot indicators showing the current [PageView] position.
class _DotIndicator extends StatelessWidget {
  const _DotIndicator({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Page ${current + 1} of $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (index) {
          final isActive = index == current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}

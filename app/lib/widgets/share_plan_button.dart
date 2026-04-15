import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:instructor/services/plan_sharing_service.dart';

/// An [IconButton] (share icon) that generates a share link for a plan and
/// invokes the native OS share sheet via the `share_plus` package.
///
/// Usage — place this in an [AppBar]'s `actions` list:
/// ```dart
/// actions: [
///   SharePlanButton(
///     planId: widget.planId!,
///     planName: _name,
///     planDescription: _description,
///   ),
/// ]
/// ```
///
/// Behaviour:
/// 1. User taps the share icon.
/// 2. [PlanSharingService.sharePlan] is called to get a short URL.
/// 3. The native OS share sheet opens with the URL and plan description.
/// 4. On error, a [SnackBar] with a user-friendly message is shown.
class SharePlanButton extends ConsumerStatefulWidget {
  const SharePlanButton({
    super.key,
    required this.planId,
    required this.planName,
    this.planDescription,
  });

  /// The server-assigned UUID of the plan to share.
  final String planId;

  /// Human-readable plan name, shown as the share subject.
  final String planName;

  /// Optional plan description, included in the share text body.
  final String? planDescription;

  @override
  ConsumerState<SharePlanButton> createState() => _SharePlanButtonState();
}

class _SharePlanButtonState extends ConsumerState<SharePlanButton> {
  bool _isSharing = false;

  Future<void> _share() async {
    if (_isSharing) return;
    SemanticsService.announce('Generating share link', TextDirection.ltr);
    setState(() => _isSharing = true);
    try {
      final service = ref.read(planSharingServiceProvider);
      final shareUrl = await service.sharePlan(widget.planId);

      // Build share text: "Plan Name — Description\n\nhttps://instructor.app/s/abc123"
      final desc = widget.planDescription?.trim();
      final shareText = (desc != null && desc.isNotEmpty)
          ? '${widget.planName} — $desc\n\n$shareUrl'
          : '${widget.planName}\n\n$shareUrl';

      if (!mounted) return;

      await Share.share(
        shareText,
        subject: widget.planName,
      );
    } on PlanSharingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.userMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to share plan. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSharing) {
      return Semantics(
        label: 'Sharing plan, please wait',
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    return IconButton(
      icon: const Icon(Icons.share),
      tooltip: 'Share plan',
      onPressed: _share,
    );
  }
}

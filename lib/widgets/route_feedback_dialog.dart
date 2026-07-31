import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service_impl.dart';
import '../theme/app_theme.dart';

class RouteFeedbackDialog extends StatefulWidget {
  final String destinationName;
  final double endLat;
  final double endLng;
  final VoidCallback? onSubmitted;

  const RouteFeedbackDialog({
    super.key,
    required this.destinationName,
    required this.endLat,
    required this.endLng,
    this.onSubmitted,
  });

  @override
  State<RouteFeedbackDialog> createState() => _RouteFeedbackDialogState();
}

class _RouteFeedbackDialogState extends State<RouteFeedbackDialog> {
  int _rating = 5;
  final Set<String> _selectedTags = {'Well-lit street', 'Felt safe'};
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _availableTags = [
    {'name': 'Well-lit street', 'isPositive': true},
    {'name': 'Busy & crowded', 'isPositive': true},
    {'name': 'Security / Police nearby', 'isPositive': true},
    {'name': 'Felt safe', 'isPositive': true},
    {'name': 'Poor lighting', 'isPositive': false},
    {'name': 'Isolated street', 'isPositive': false},
    {'name': 'Suspicious activity', 'isPositive': false},
    {'name': 'Unsafe area', 'isPositive': false},
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    setState(() => _isSubmitting = true);
    try {
      await ApiService.submitRouteFeedback(
        rating: _rating.toDouble(),
        tags: _selectedTags.toList(),
        comments: _commentController.text.trim(),
        lat: widget.endLat,
        lng: widget.endLng,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onSubmitted?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Thank you! Your feedback helps keep the community safe.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        Navigator.pop(context);
        widget.onSubmitted?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withAlpha((0.2 * 255).round()),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.success,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Destination Reached! 🎉',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.destinationName.isNotEmpty
                            ? widget.destinationName
                            : 'Arrived at your location',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ).animate().fadeIn().scale(),

            const SizedBox(height: 24),
            const Text(
              'How safe did you feel on this route?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // Star Rating
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  final starVal = index + 1;
                  return IconButton(
                    onPressed: () => setState(() => _rating = starVal),
                    icon: Icon(
                      starVal <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                      color: starVal <= _rating ? Colors.amber : AppTheme.textSecondary,
                      size: 36,
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              'Select Safety Highlights',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),

            // Tags
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableTags.map((tag) {
                final String name = tag['name'] as String;
                final bool isPos = tag['isPositive'] as bool;
                final bool isSelected = _selectedTags.contains(name);
                final Color activeColor = isPos ? AppTheme.success : AppTheme.sosRed;

                return ChoiceChip(
                  label: Text(
                    name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: activeColor.withAlpha((0.6 * 255).round()),
                  backgroundColor: AppTheme.card,
                  side: BorderSide(
                    color: isSelected ? activeColor : AppTheme.divider,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTags.add(name);
                      } else {
                        _selectedTags.remove(name);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 20),
            // Comments field
            Container(
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider),
              ),
              child: TextField(
                controller: _commentController,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Add safety observations or comments (optional)...',
                  hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(14),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Submit Safety Feedback',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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

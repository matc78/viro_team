import 'dart:async';
import 'package:flutter/material.dart';

class SlideToConfirm extends StatefulWidget {
  final String label;
  final Color color;
  final IconData icon;
  final Future<void> Function() onConfirmed;
  final double height;
  final double maxWidth;

  const SlideToConfirm({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
    required this.onConfirmed,
    this.height = 52, // Un peu plus haut pour une meilleure ergonomie
    this.maxWidth = 280,
  });

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm>
    with SingleTickerProviderStateMixin {
  double _dragX = 0;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > widget.maxWidth
            ? widget.maxWidth
            : constraints.maxWidth;
        final knobSize = widget.height - 8;
        final maxDrag = width - knobSize - 8;
        final progress = (_dragX / maxDrag).clamp(0.0, 1.0);

        return Center(
          child: Container(
            width: width,
            height: widget.height,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(widget.height / 2),
              border: Border.all(
                color: widget.color.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Texte avec effet de fondu (disparaît quand on slide)
                Center(
                  child: Opacity(
                    opacity: (1 - progress * 2).clamp(0.0, 1.0),
                    child: Text(
                      widget.label.toUpperCase(),
                      style: TextStyle(
                        color: widget.color,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),

                // La zone de remplissage colorée
                Container(
                  width: _dragX + knobSize + 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.color.withValues(alpha: 0.1),
                        widget.color.withValues(alpha: 0.3),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(widget.height / 2),
                  ),
                ),

                // Le bouton coulissant (Knob)
                Positioned(
                  left: 4 + _dragX,
                  child: GestureDetector(
                    onHorizontalDragUpdate: _isLoading
                        ? null
                        : (details) {
                            setState(() {
                              _dragX = (_dragX + details.delta.dx).clamp(
                                0.0,
                                maxDrag,
                              );
                            });
                          },
                    onHorizontalDragEnd: _isLoading
                        ? null
                        : (details) async {
                            if (_dragX >= maxDrag * 0.8) {
                              _handleConfirm(maxDrag);
                            } else {
                              _reset();
                            }
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: knobSize,
                      height: knobSize,
                      decoration: BoxDecoration(
                        color: widget.color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _isLoading
                          ? Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            )
                          : Icon(widget.icon, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleConfirm(double maxDrag) async {
    setState(() {
      _dragX = maxDrag;
      _isLoading = true;
    });

    await widget.onConfirmed();

    if (mounted) {
      setState(() => _isLoading = false);
      _reset();
    }
  }

  void _reset() {
    setState(() => _dragX = 0);
  }
}

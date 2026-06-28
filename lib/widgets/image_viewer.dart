import 'package:flutter/material.dart';

/// Standalone full-screen image viewer with pinch-zoom, double-tap to reset,
/// and a dismiss-on-tap-background gesture.
class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  const FullScreenImageViewer({super.key, required this.imageUrl});

  static void show(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => FullScreenImageViewer(imageUrl: imageUrl),
    );
  }

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer>
    with SingleTickerProviderStateMixin {
  final TransformationController _controller = TransformationController();
  late AnimationController _animController;
  Animation<Matrix4>? _resetAnimation;

  bool _showHint = true;

  @override
  void initState() {
    super.initState();
    _animController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 250),
        )..addListener(() {
          if (_resetAnimation != null) {
            _controller.value = _resetAnimation!.value;
          }
        });

    // Hide the hint after 2 s
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showHint = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onDoubleTap(TapDownDetails details) {
    if (_controller.value != Matrix4.identity()) {
      // Already zoomed — reset
      _resetAnimation =
          Matrix4Tween(
            begin: _controller.value,
            end: Matrix4.identity(),
          ).animate(
            CurvedAnimation(parent: _animController, curve: Curves.easeOut),
          );
      _animController.forward(from: 0);
    } else {
      // Zoom in 2.5× centred on the tap point
      final pos = details.localPosition;
      final matrix = Matrix4.identity()
        ..translate(-pos.dx * 1.5, -pos.dy * 1.5)
        ..scale(2.5);
      _resetAnimation = Matrix4Tween(begin: _controller.value, end: matrix)
          .animate(
            CurvedAnimation(parent: _animController, curve: Curves.easeOut),
          );
      _animController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Tap background to dismiss
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const ColoredBox(color: Colors.transparent),
          ),

          // Zoomable image
          GestureDetector(
            onDoubleTapDown: _onDoubleTap,
            onDoubleTap: () {}, // required for onDoubleTapDown to fire
            child: InteractiveViewer(
              transformationController: _controller,
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(40),
              minScale: 0.8,
              maxScale: 5.0,
              child: Center(
                child: Image.network(
                  widget.imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 80,
                  ),
                ),
              ),
            ),
          ),

          // Close button
          Positioned(
            top: 48,
            right: 16,
            child: SafeArea(
              child: Material(
                color: Colors.black45,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          ),

          // Double-tap hint
          if (_showHint)
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _showHint ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 400),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Double-tap to zoom • Pinch to zoom • Tap outside to close',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

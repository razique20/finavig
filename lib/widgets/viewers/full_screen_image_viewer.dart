import 'dart:io';

import 'package:flutter/material.dart';

import '../attachment_thumbnail.dart';

/// Full-screen black-out image viewer with pinch-to-zoom (1×–5×),
/// double-tap-to-zoom at the tapped point, and an optional one-tap share
/// action. Extracted from `document_detail_screen.dart` so any screen that
/// displays an attachment (detail sheet, records, expiry list, chat) reuses
/// one implementation, rendered on top of the shared [AttachmentImage]
/// pipeline (downsampled thumbnails, disk-cached cloud fetches).
class FullScreenImageViewer extends StatefulWidget {
  /// Title shown in the app bar (file or document name).
  final String name;

  /// Local file path or http(s) URL of the image.
  final String path;

  /// True when [path] is an http(s) URL (cloud attachment).
  final bool isNetwork;

  /// Local file when [isNetwork] is false; required in that case.
  final File? localFile;

  /// Invoked from the app-bar share button after the viewer pops. When null
  /// the share button is hidden.
  final VoidCallback? onShare;

  const FullScreenImageViewer({
    super.key,
    required this.name,
    required this.path,
    required this.isNetwork,
    this.localFile,
    this.onShare,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  final TransformationController _transform =
      TransformationController(Matrix4.identity());
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  /// Zoom into the double-tapped point (or back out if already zoomed).
  void _handleDoubleTap(TapDownDetails details) {
    const double tapScale = 2.5;
    final position = details.localPosition;

    if (_transform.value.getMaxScaleOnAxis() > 1.0) {
      _transform.value = Matrix4.identity();
    } else {
      _transform.value = Matrix4(
        tapScale, 0, 0, 0,
        0, tapScale, 0, 0,
        0, 0, 1, 0,
        tapScale - tapScale * position.dx,
        tapScale - tapScale * position.dy,
        0, 1,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.name,
          style: const TextStyle(color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (widget.onShare != null)
            IconButton(
              tooltip: 'Share document file',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () {
                Navigator.of(context).pop();
                widget.onShare!();
              },
            ),
        ],
      ),
      body: InteractiveViewer(
        clipBehavior: Clip.none,
        transformationController: _transform,
        minScale: 1.0,
        maxScale: 5.0,
        panEnabled: true,
        onInteractionStart: (_) => _doubleTapDetails = null,
        child: Center(
          child: GestureDetector(
            onDoubleTapDown: (details) => _doubleTapDetails = details,
            onDoubleTap: () {
              if (_doubleTapDetails != null) {
                _handleDoubleTap(_doubleTapDetails!);
              }
            },
            child: AttachmentImage(
              path: widget.path,
              isNetwork: widget.isNetwork,
              localFile: widget.localFile,
              // No targetWidth: full-resolution decode for crisp zoom.
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the viewer full-screen with a fade-in, on the root navigator so it
/// covers the floating bottom nav pill. Image-only — call sites are
/// responsible for gating non-image files to an info sheet.
void showFullScreenImageViewer(
  BuildContext context, {
  required String name,
  required String path,
  required bool isNetwork,
  File? localFile,
  VoidCallback? onShare,
}) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => FullScreenImageViewer(
        name: name,
        path: path,
        isNetwork: isNetwork,
        localFile: localFile,
        onShare: onShare,
      ),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

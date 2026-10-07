import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../theme/app_theme.dart';

/// Shared attachment image pipeline for document scans — extracted from the
/// raw `Image.file` / `Image.network` usage in `document_detail_screen.dart`.
///
/// * **Local files** are decoded *downsampled*: [cacheWidth] is derived from
///   [targetWidth] (the layout size in logical pixels) × device pixel ratio,
///   so a 12 MP phone scan never decodes at full resolution inside a card
///   or list row.
/// * **Cloud (URL) attachments** go through `cached_network_image`, whose
///   disk cache survives app restarts — no re-downloading the same scan on
///   every screen open. The placeholder mirrors the shimmer aesthetic.
/// * The full-screen viewer passes no cache bounds (`targetWidth` null), so
///   it decodes at native resolution for crisp pinch-to-zoom.
class AttachmentImage extends StatelessWidget {
  /// Local file path or http(s) URL of the attachment.
  final String path;

  /// True when [path] is an http(s) URL (cloud attachment).
  final bool isNetwork;

  /// Local file when [isNetwork] is false; required in that case.
  final File? localFile;

  /// Layout width in logical pixels. When null, no downsample bound is
  /// applied (full-resolution decode — used by the full-screen viewer).
  final double? targetWidth;

  final BoxFit fit;

  const AttachmentImage({
    super.key,
    required this.path,
    required this.isNetwork,
    this.localFile,
    this.targetWidth,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    if (isNetwork) {
      return CachedNetworkImage(
        imageUrl: path,
        fit: fit,
        memCacheWidth: _memCacheWidth(context),
        placeholder: (_, __) => const _AttachmentPlaceholder(),
        errorWidget: (_, __, ___) => const _AttachmentError(
          message: 'Error loading cloud image.',
        ),
      );
    }

    final file = localFile ?? File(path);
    return Image.file(
      file,
      fit: fit,
      cacheWidth: _memCacheWidth(context),
      errorBuilder: (_, __, ___) => const _AttachmentError(
        message: 'Error loading local image file.',
      ),
      frameBuilder: (context, child, frame, wasSyncLoaded) {
        if (wasSyncLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 180),
          child: child,
        );
      },
    );
  }

  /// Decode target in pixels: the requested layout width × device pixel
  /// ratio, clamped to sane codec bounds. Null when [targetWidth] is null
  /// (full-resolution decode).
  int? _memCacheWidth(BuildContext context) {
    if (targetWidth == null) return null;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    return (targetWidth! * dpr).round().clamp(1, 4096);
  }
}

/// Pulsating placeholder matching the app's shimmer aesthetic.
class _AttachmentPlaceholder extends StatelessWidget {
  const _AttachmentPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.brightness == Brightness.dark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.05);
    final highlight = theme.brightness == Brightness.dark
        ? Colors.white.withOpacity(0.14)
        : Colors.black.withOpacity(0.09);
    return Container(
      color: base,
      alignment: Alignment.center,
      child: _PulseDot(base: highlight),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color base;

  const _PulseDot({required this.base});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 0.9).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: widget.base,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _AttachmentError extends StatelessWidget {
  final String message;

  const _AttachmentError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 32,
            color: FinavigColors.adaptiveIcon(context, Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}

/// Builds the exact image provider [AttachmentImage] would use, so
/// pre-warming guarantees a cache hit when the widget builds.
ImageProvider? attachmentImageProvider({
  required String path,
  required bool isNetwork,
  File? localFile,
  double? targetWidth,
  BuildContext? context,
}) {
  if (isNetwork) {
    return CachedNetworkImageProvider(path);
  }
  final file = localFile ?? File(path);
  if (!file.existsSync()) return null;

  int? cacheWidth;
  if (targetWidth != null && context != null) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    cacheWidth = (targetWidth * dpr).round().clamp(1, 4096);
  }
  // ResizeImage mirrors what `Image.file(cacheWidth: …)` builds internally,
  // so a precache with the same width is a guaranteed cache hit later.
  if (cacheWidth != null) {
    return ResizeImage(
      FileImage(file),
      width: cacheWidth,
      allowUpscaling: false,
    );
  }
  return FileImage(file);
}

/// Pre-warms the image caches for an attachment before it becomes visible.
///
/// Call this when a document row scrolls into view (or right before opening
/// the detail screen) so the first paint of the card/viewer is instant:
/// * Local file: decodes into Flutter's shared image cache via
///   [precacheImage] — the later `Image.file` serves from that cache.
/// * Cloud URL: fetches into `cached_network_image`'s disk cache so the
///   widget later hits the disk instead of the network.
///
/// When [targetWidth] is given (thumbnail use case), the local decode is
/// downsampled to that logical width × device pixel ratio. For the
/// full-resolution viewer warmup, omit it.
Future<void> prewarmAttachmentImage(
  BuildContext context,
  String path, {
  required bool isNetwork,
  File? localFile,
  double? targetWidth,
}) async {
  try {
    if (isNetwork) {
      // Disk-cache the file for later; precache is a no-op if cached.
      await DefaultCacheManager().downloadFile(path);
      return;
    }
    final provider = attachmentImageProvider(
      path: path,
      isNetwork: false,
      localFile: localFile,
      targetWidth: targetWidth,
      context: context,
    );
    if (provider == null) return;
    await precacheImage(provider, context);
  } catch (_) {
    // Pre-warming is best-effort — never surface errors from warmup.
  }
}

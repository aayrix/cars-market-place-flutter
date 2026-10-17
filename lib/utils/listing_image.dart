import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'local_file_image_io.dart'
    if (dart.library.html) 'local_file_image_web.dart';

/// Renders a network/blob URL or a local file path (mobile/desktop only).
///
/// Uses [CachedNetworkImage] so images are cached to disk and memory —
/// scrolling the feed no longer re-downloads every photo.
Widget listingImageThumbnail(
  BuildContext context,
  String pathOrUrl, {
  required double width,
  required double height,
  BoxFit fit = BoxFit.contain,
  Widget Function(BuildContext)? placeholder,
}) {
  final trimmed = pathOrUrl.trim();

  if (trimmed.isEmpty) {
    return SizedBox(
      width: width,
      height: height,
      child: Center(child: _brokenImageIcon()),
    );
  }

  if (_isDisplayableUrl(trimmed)) {
    return CachedNetworkImage(
      imageUrl: trimmed,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.low,
      errorWidget: (context, url, error) =>
          placeholder?.call(context) ?? _brokenImageIcon(),
      placeholder: (context, url) => SizedBox(
        width: width,
        height: height,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      fadeInCurve: Curves.easeInOut,
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: Duration.zero,
      httpHeaders: const {
        // Ask Supabase CDN to cache aggressively at the edge.
        'Cache-Control': 'public, max-age=604800',
      },
    );
  }

  if (kIsWeb) {
    return SizedBox(
      width: width,
      height: height,
      child: Center(child: _brokenImageIcon()),
    );
  }

  return localFileImage(
    trimmed,
    width: width,
    height: height,
    fit: fit,
    placeholder: _brokenImageIcon(),
  );
}

bool _isDisplayableUrl(String value) =>
    value.startsWith('http://') ||
    value.startsWith('https://') ||
    value.startsWith('blob:');

Widget _brokenImageIcon() =>
    Icon(Icons.broken_image_outlined, color: Colors.grey.shade600);

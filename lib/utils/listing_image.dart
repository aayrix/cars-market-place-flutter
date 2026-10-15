import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'local_file_image_io.dart'
    if (dart.library.html) 'local_file_image_web.dart';

/// Renders a network/blob URL or a local file path (mobile/desktop only).
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
    return Image.network(
      trimmed,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.high,
      // Decode large camera uploads near their rendered size instead of
      // keeping a full-resolution bitmap for every scrolling thumbnail.
      cacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).round(),
      cacheHeight: (height * MediaQuery.devicePixelRatioOf(context)).round(),
      errorBuilder: (context, error, stackTrace) =>
          placeholder?.call(context) ?? _brokenImageIcon(),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return SizedBox(
          width: width,
          height: height,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
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

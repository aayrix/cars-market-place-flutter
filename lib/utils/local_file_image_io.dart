import 'dart:io';

import 'package:flutter/material.dart';

bool localFileExists(String path) => File(path).existsSync();

Widget localFileImage(
  String path, {
  required double width,
  required double height,
  BoxFit fit = BoxFit.cover,
  Widget? placeholder,
}) {
  return Image.file(
    File(path),
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (context, error, stackTrace) =>
        placeholder ?? Icon(Icons.broken_image_outlined, color: Colors.grey.shade600),
  );
}

import 'package:flutter/material.dart';

bool localFileExists(String path) => false;

Widget localFileImage(
  String path, {
  required double width,
  required double height,
  BoxFit fit = BoxFit.cover,
  Widget? placeholder,
}) {
  return placeholder ??
      Icon(Icons.broken_image_outlined, color: Colors.grey.shade600);
}

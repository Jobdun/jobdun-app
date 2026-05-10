import 'package:flutter/material.dart';

abstract final class AppGradients {
  /// Brand flame gradient — used as ShaderMask on wordmarks/logos.
  /// Direction: topLeft → bottomRight. Stops: warm yellow → deep orange.
  static const brandFlame = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFF176),
      Color(0xFFFFB300),
      Color(0xFFF97316),
      Color(0xFFE64A19),
      Color(0xFFBF360C),
    ],
  );
}

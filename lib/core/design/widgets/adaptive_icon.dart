import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AdaptiveIcon extends StatelessWidget {
  const AdaptiveIcon({
    super.key,
    required this.iconsax,
    this.cupertino,
    this.size,
    this.color,
  });

  final IconData iconsax;
  final IconData? cupertino;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final icon = Platform.isIOS && cupertino != null ? cupertino! : iconsax;
    return Icon(icon, size: size, color: color);
  }
}

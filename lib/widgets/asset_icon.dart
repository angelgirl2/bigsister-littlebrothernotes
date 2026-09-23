import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AssetIcon extends StatelessWidget {
  const AssetIcon(
    this.asset, {
    super.key,
    this.size = 26,
    this.color,
    this.fit = BoxFit.contain,
  });

  final String asset;
  final double size;
  final Color? color;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      fit: fit,
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
    );
  }
}

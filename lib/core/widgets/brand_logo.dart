import 'package:flutter/material.dart';

import '../config/brand_assets.dart';
import '../theme/app_colors.dart';

/// The company seal, cropped to a circle (the source image has a white
/// square background). Falls back to an initial if the asset is missing.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 36, this.fallbackInitial = 'B'});

  final double size;
  final String fallbackInitial;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipOval(
      child: Container(
        width: size,
        height: size,
        color: Colors.white,
        child: Image.asset(
          BrandAssets.logo,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            alignment: Alignment.center,
            color: AppColors.accent,
            child: Text(
              fallbackInitial,
              style: TextStyle(
                color: AppColors.sidebar,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.5,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

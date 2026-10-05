import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.email, this.size = 40});

  final String email;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.sidebar, AppColors.gradientEnd],
        ),
      ),
      child: Text(
        email.isEmpty ? '?' : email[0].toUpperCase(),
        style: TextStyle(
          color: AppColors.accent,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.42,
        ),
      ),
    ),
  );
}

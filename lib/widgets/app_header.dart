import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  final bool showBackButton;
  final String? title;
  final VoidCallback? onStatsPressed;
  final VoidCallback? onSettingsPressed;
  final VoidCallback? onProfilePressed;

  const AppHeader({
    super.key,
    this.showBackButton = false,
    this.title,
    this.onStatsPressed,
    this.onSettingsPressed,
    this.onProfilePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
      ),
      child: Row(
        children: [
          if (showBackButton)
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Color(0xFF23345F)),
              padding: EdgeInsets.zero,
            )
          else
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo SOCIAL + X
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/logo_alveslima.png',
                        width: 120,             
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ],
              ),
          
          if (title != null) ...[
            const Spacer(),
            Text(
              title!,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF23345F),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          
          const Spacer(),
          
          if (!showBackButton)
            Row(
              children: [
                if (onStatsPressed != null)
                  IconButton(
                    onPressed: onStatsPressed,
                    icon: const Icon(Icons.bar_chart, color: Color(0xFF23345F)),
                  ),
                if (onSettingsPressed != null)
                  IconButton(
                    onPressed: onSettingsPressed,
                    icon: const Icon(Icons.settings, color: Color(0xFF23345F)),
                  ),
                if (onProfilePressed != null)
                  IconButton(
                    onPressed: onProfilePressed,
                    icon: const Icon(Icons.person, color: Color(0xFF23345F)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
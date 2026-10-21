import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ui/theme/app_colors.dart';
import '../ui/theme/app_spacing.dart';
import '../ui/theme/app_typography.dart';

class Contact extends StatelessWidget {
  const Contact({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Got complains/suggestions?',
          style: AppTypography.bodyMd.copyWith(color: c.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: () async {
            //Open prefilled mail
            final Uri emailUri = Uri(
              scheme: 'mailto',
              path: 'kinyuanexus@gmail.com',
              query: 'subject=Feedback / Inquiry',
            );

            if (await canLaunchUrl(emailUri)) {
              launchUrl(emailUri);
            } else {
              debugPrint('Could not launch email client');
            }
          },
          child: Text(
            'kinyuanexus@gmail.com',
            style: AppTypography.bodyMd.copyWith(color: c.primary),
          ),
        ),
      ],
    );
  }
}

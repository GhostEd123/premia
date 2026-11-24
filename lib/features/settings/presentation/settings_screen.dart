import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../application/settings_notifier.dart';

/// App preferences, support, and legal screen opened from the Marquee menu icon.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _openEmailSupport(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'hello@watchpremia.com',
      queryParameters: {'subject': 'Premia Support Inquiry'},
    );
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.surfaceHigh,
          content: Text('Contact us at hello@watchpremia.com'),
        ),
      );
    }
  }

  void _showLegalSheet(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const Divider(color: AppColors.border, height: 24),
            Text(
              content,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);
    final notifier = ref.read(settingsNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              // --- Toggles Card ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    _SwitchRow(
                      icon: Icons.notifications_none_outlined,
                      label: 'Premier Reminders',
                      value: settings.premierReminders,
                      onChanged: notifier.setPremierReminders,
                    ),
                    const Divider(color: AppColors.border, height: 1),
                    _SwitchRow(
                      icon: Icons.closed_caption_outlined,
                      label: 'Subtitles by Defualt',
                      value: settings.subtitlesByDefault,
                      onChanged: notifier.setSubtitlesByDefault,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // --- Support & Legal Card ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    _ActionRow(
                      leadingIcon: Icons.headset_mic_outlined,
                      label: 'Email Support',
                      trailingIcon: Icons.headset_mic_outlined,
                      onTap: () => _openEmailSupport(context),
                    ),
                    const Divider(color: AppColors.border, height: 1),
                    _ActionRow(
                      leadingIcon: Icons.insert_drive_file_outlined,
                      label: 'Terms of Service',
                      trailingIcon: Icons.insert_drive_file_outlined,
                      onTap: () => _showLegalSheet(
                        context,
                        title: 'Terms of Service',
                        content:
                            'Welcome to Premia by Lumina One. Each ticket grants single-viewing access during the advertised 48-to-72-hour premiere window. Recording, rebroadcasting, or sharing account access outside authorized Guest Passes is strictly prohibited.',
                      ),
                    ),
                    const Divider(color: AppColors.border, height: 1),
                    _ActionRow(
                      leadingIcon: Icons.verified_user_outlined,
                      label: 'Privacy Policy',
                      trailingIcon: Icons.verified_user_outlined,
                      onTap: () => _showLegalSheet(
                        context,
                        title: 'Privacy Policy',
                        content:
                            'Premia collects only the email address and per-install device identifier required to deliver your magic link, verify your ticket, and enforce single-session playback security.',
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Premia by Lumina One · v1.0',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.leadingIcon,
    required this.label,
    required this.trailingIcon,
    required this.onTap,
  });

  final IconData leadingIcon;
  final String label;
  final IconData trailingIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(leadingIcon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            Icon(trailingIcon, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../injection.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_state.dart';
import 'login_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        if (state is! SettingsLoaded) return const SizedBox();
        final hPad = Responsive.horizontalPadding(context);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text('Settings', style: AppTextStyles.headlineSmall),
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: Responsive.contentMaxWidth(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GENERAL',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.secondary, letterSpacing: 3),
                    ),
                    const SizedBox(height: 16),
                    _buildSettingsGroup([
                      _settingsItem(icon: Icons.language, title: 'Language',
                        trailing: Text(state.language, style: AppTextStyles.bodyMedium),
                      ),
                      _settingsToggle(
                        icon: Icons.brightness_6, title: 'Dark Mode',
                        value: state.darkMode,
                        onChanged: (_) => context.read<SettingsCubit>().toggleDarkMode(),
                      ),
                      _settingsItem(icon: Icons.accessibility, title: 'Accessibility'),
                    ]),
                    const SizedBox(height: 32),
                    Text('NOTIFICATIONS',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.secondary, letterSpacing: 3),
                    ),
                    const SizedBox(height: 16),
                    _buildSettingsGroup([
                      _settingsToggle(
                        icon: Icons.notifications_active, title: 'Workout Reminders',
                        value: state.workoutReminders,
                        onChanged: (_) => context.read<SettingsCubit>().toggleWorkoutReminders(),
                      ),
                      _settingsToggle(
                        icon: Icons.smart_toy, title: 'AI Coach Tips',
                        value: state.aiTips,
                        onChanged: (_) => context.read<SettingsCubit>().toggleAiTips(),
                      ),
                      _settingsItem(icon: Icons.schedule, title: 'Reminder Schedule'),
                    ]),
                    const SizedBox(height: 32),
                    Text('ACCOUNT',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.secondary, letterSpacing: 3),
                    ),
                    const SizedBox(height: 16),
                    _buildSettingsGroup([
                      _settingsItem(icon: Icons.privacy_tip, title: 'Privacy'),
                      _settingsItem(icon: Icons.security, title: 'Security'),
                      _settingsItem(icon: Icons.cloud_sync, title: 'Data Sync'),
                    ]),
                    const SizedBox(height: 32),
                    Text('DANGER ZONE',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.error, letterSpacing: 3),
                    ),
                    const SizedBox(height: 16),
                    _buildSettingsGroup([
                      GestureDetector(
                        onTap: () async {
                          await sl<AuthCubit>().logout();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const LoginPage()),
                              (route) => false,
                            );
                          }
                        },
                        child: _settingsItem(icon: Icons.logout, title: 'Sign Out',
                          iconColor: AppColors.error, textColor: AppColors.error),
                      ),
                      _settingsItem(icon: Icons.delete_forever, title: 'Delete Account',
                        iconColor: AppColors.error, textColor: AppColors.error),
                    ]),
                    const SizedBox(height: 32),
                    Center(
                      child: Column(
                        children: [
                          Text('KINETIC AI',
                            style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary, letterSpacing: 3),
                          ),
                          const SizedBox(height: 4),
                          Text('v2.4.1 • Build 847',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.outline),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsGroup(List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          return Column(
            children: [
              items[i],
              if (i < items.length - 1)
                Divider(color: AppColors.outlineVariant.withValues(alpha: 0.2), height: 1, indent: 56),
            ],
          );
        }),
      ),
    );
  }

  Widget _settingsItem({
    required IconData icon, required String title,
    Widget? trailing, Color? iconColor, Color? textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? AppColors.onSurfaceVariant, size: 22),
          const SizedBox(width: 16),
          Expanded(child: Text(title,
            style: AppTextStyles.titleMedium.copyWith(color: textColor ?? AppColors.onSurface),
          )),
          trailing ?? const Icon(Icons.chevron_right, color: AppColors.outline, size: 20),
        ],
      ),
    );
  }

  Widget _settingsToggle({
    required IconData icon, required String title,
    required bool value, required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.onSurfaceVariant, size: 22),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: AppTextStyles.titleMedium)),
          Switch(
            value: value, onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
            inactiveThumbColor: AppColors.outline,
            inactiveTrackColor: AppColors.surfaceContainer,
          ),
        ],
      ),
    );
  }
}

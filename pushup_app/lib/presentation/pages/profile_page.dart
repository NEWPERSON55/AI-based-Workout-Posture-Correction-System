import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/animations/kinetic_animations.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/profile_state.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        if (state is! ProfileLoaded) return const SizedBox();
        final hPad = Responsive.horizontalPadding(context);
        final isTab = Responsive.isTablet(context);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 100),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
              child: isTab
                  ? _buildTabletLayout(context, state)
                  : _buildMobileLayout(context, state),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context, ProfileLoaded state) {
    return StaggeredList(
      crossAxisAlignment: CrossAxisAlignment.center,
      staggerDelay: const Duration(milliseconds: 120),
      children: [
        _buildAvatar(context, state),
        const SizedBox(height: 32),
        _buildMetrics(context, state),
        const SizedBox(height: 32),
        _buildAiAnalysis(state),
        const SizedBox(height: 32),
        _buildActions(),
      ],
    );
  }

  Widget _buildTabletLayout(BuildContext context, ProfileLoaded state) {
    return StaggeredList(
      crossAxisAlignment: CrossAxisAlignment.center,
      staggerDelay: const Duration(milliseconds: 120),
      children: [
        _buildAvatar(context, state),
        const SizedBox(height: 40),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  _buildMetrics(context, state),
                  const SizedBox(height: 24),
                  _buildAiAnalysis(state),
                ],
              ),
            ),
            const SizedBox(width: 24),
            SizedBox(
              width: 300,
              child: _buildActions(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatar(BuildContext context, ProfileLoaded state) {
    final isTab = Responsive.isTablet(context);
    final avatarSize = isTab ? 148.0 : 128.0;
    return Column(
      children: [
        Container(
          width: avatarSize, height: avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.secondary],
            ),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 30),
              BoxShadow(color: AppColors.secondary.withValues(alpha: 0.15), blurRadius: 30),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.surfaceContainer),
            child: Icon(Icons.person, color: AppColors.onSurfaceVariant, size: isTab ? 72 : 60),
          ),
        ),
        const SizedBox(height: 20),
        Text(state.name, style: AppTextStyles.headlineMedium.copyWith(fontSize: isTab ? 32 : 28)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Text(state.tier, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary, letterSpacing: 3)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(state.goal, style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }

  Widget _buildMetrics(BuildContext context, ProfileLoaded state) {
    return Container(
      padding: EdgeInsets.all(Responsive.value(context, mobile: 24, tablet: 28)),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('VITAL STATS', style: AppTextStyles.labelSmall.copyWith(letterSpacing: 3)),
          const SizedBox(height: 16),
          Row(
            children: [
              _metricCard('AGE', '${state.age}', 'years', AppColors.onSurface),
              const SizedBox(width: 12),
              _metricCard('WEIGHT', '${state.weight}', 'lbs', AppColors.primary),
              const SizedBox(width: 12),
              _metricCard('HEIGHT', state.height, '', AppColors.secondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value, String unit, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        decoration: BoxDecoration(color: AppColors.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: AppTextStyles.labelSmall.copyWith(letterSpacing: 3)),
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: AppTextStyles.headlineSmall.copyWith(color: color)),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(unit, style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurfaceVariant, fontSize: 10)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAiAnalysis(ProfileLoaded state) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: AppColors.secondary.withValues(alpha: 0.3), width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.smart_toy, color: AppColors.secondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI COACH ANALYSIS',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.secondary, letterSpacing: 3),
                ),
                const SizedBox(height: 8),
                Text(state.coachAnalysis, style: AppTextStyles.bodyMedium.copyWith(height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        ScaleOnTap(child: _actionItem(Icons.edit, 'Edit Profile', AppColors.primary)),
        const SizedBox(height: 12),
        ScaleOnTap(child: _actionItem(Icons.emoji_events, 'Achievements', AppColors.secondary, badge: '12')),
        const SizedBox(height: 12),
        ScaleOnTap(child: _actionItem(Icons.logout, 'Sign Out', AppColors.error)),
      ],
    );
  }

  Widget _actionItem(IconData icon, String label, Color color, {String? badge}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: AppTextStyles.titleMedium)),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(9999),
              ),
              child: Text(badge, style: AppTextStyles.labelSmall.copyWith(color: color)),
            ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: AppColors.outline),
        ],
      ),
    );
  }
}

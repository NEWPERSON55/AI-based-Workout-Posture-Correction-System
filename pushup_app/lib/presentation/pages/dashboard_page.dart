import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/animations/kinetic_animations.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        if (state is DashboardLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is DashboardError) {
          return Center(
            child: Text((state).message, style: AppTextStyles.bodyMedium),
          );
        }
        if (state is! DashboardLoaded) return const SizedBox();
        final hPad = Responsive.horizontalPadding(context);
        final isTab = Responsive.isTablet(context);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 100),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.contentMaxWidth(context),
              ),
              child: StaggeredList(
                staggerDelay: const Duration(milliseconds: 100),
                children: [
                  // Welcome
                  Text(
                    'STATUS: ACTIVE',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.secondary,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Welcome back, ${state.userName}!',
                    style: AppTextStyles.headlineLarge.copyWith(
                      fontSize: isTab ? 38 : 32,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ScaleOnTap(child: _buildQuickStartHero(context)),
                  const SizedBox(height: 32),
                  _buildDailyPulse(context, state),
                  const SizedBox(height: 32),
                  Text('Shortcuts', style: AppTextStyles.headlineSmall),
                  const SizedBox(height: 16),
                  _buildShortcuts(context),
                  const SizedBox(height: 32),
                  _buildRecoveryScore(context, state),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickStartHero(BuildContext context) {
    final isTab = Responsive.isTablet(context);
    return Container(
      height: isTab ? 260 : 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.secondary.withValues(alpha: 0.1),
          ],
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 30,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppColors.surface],
                ),
              ),
            ),
          ),
          Positioned(
            top: 24,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Start Workout',
                        style: AppTextStyles.headlineSmall.copyWith(
                          fontSize: isTab ? 28 : 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'AI-optimized session based on your recovery score.',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
          Positioned(
            bottom: 12,
            right: 12,

            width: Responsive.isMobile(context) ? 200 : 250,
            child: PulseGlow(
              glowColor: AppColors.primary,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTab ? 28 : 24,
                  vertical: isTab ? 18 : 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Row(
                  children: [
                    Text('BEGIN NOW', style: AppTextStyles.buttonText),
                    const SizedBox(width: 8),
                    const Icon(Icons.play_arrow, color: AppColors.onPrimary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyPulse(BuildContext context, DashboardLoaded state) {
    final isTab = Responsive.isTablet(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Daily Pulse',
              style: AppTextStyles.headlineSmall.copyWith(
                fontSize: isTab ? 24 : 20,
              ),
            ),
            Text('LAST SYNC: 2M AGO', style: AppTextStyles.labelSmall),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 7,
              child: Container(
                height: isTab ? 180 : 160,
                padding: EdgeInsets.all(isTab ? 28 : 24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ACTIVE ENERGY',
                          style: AppTextStyles.labelSmall.copyWith(
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              AnimatedCounter(
                                value: state.caloriesBurned.toInt(),
                                style: AppTextStyles.statValue.copyWith(
                                  fontSize: isTab ? 48 : 42,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'KCAL',
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        AnimatedProgressBar(
                          progress: state.caloriesBurned / state.caloriesGoal,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Icon(
                        Icons.local_fire_department,
                        size: isTab ? 96 : 80,
                        color: AppColors.primary.withValues(alpha: 0.08),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 5,
              child: Container(
                height: isTab ? 180 : 160,
                padding: EdgeInsets.all(isTab ? 28 : 24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SESSIONS',
                      style: AppTextStyles.labelSmall.copyWith(
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          AnimatedCounter(
                            value: state.sessionsCompleted,
                            style: AppTextStyles.statValue.copyWith(
                              fontSize: isTab ? 48 : 42,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'COMPLETED',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: List.generate(state.sessionsGoal, (i) {
                        return Expanded(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: Duration(milliseconds: 600 + i * 200),
                            curve: Curves.easeOutCubic,
                            builder: (_, val, __) => Container(
                              height: 8,
                              margin: EdgeInsets.only(
                                right: i < state.sessionsGoal - 1 ? 4 : 0,
                              ),
                              decoration: BoxDecoration(
                                color: i < state.sessionsCompleted
                                    ? AppColors.secondary.withValues(alpha: val)
                                    : AppColors.surfaceVariant.withValues(
                                        alpha: 0.3 * val,
                                      ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShortcuts(BuildContext context) {
    final isTab = Responsive.isTablet(context);
    final items = [
      _ShortcutData(
        Icons.fitness_center,
        'Exercises',
        'Explore 500+ moves',
        null,
        false,
      ),
      _ShortcutData(
        Icons.smart_toy,
        'AI Coach',
        'Real-time feedback',
        AppColors.secondary,
        true,
      ),
      _ShortcutData(
        Icons.history,
        'History',
        'Track your progress',
        null,
        false,
      ),
    ];
    if (isTab)
      items.add(
        _ShortcutData(
          Icons.bar_chart,
          'Progress',
          'View analytics',
          AppColors.primary,
          false,
        ),
      );

    final cards = items.asMap().entries.map((entry) {
      final i = entry.key;
      final item = entry.value;
      final card = FadeSlideIn(
        delay: Duration(milliseconds: 600 + i * 100),
        child: ScaleOnTap(
          child: _shortcutCard(
            icon: item.icon,
            title: item.title,
            subtitle: item.subtitle,
            accentColor: item.accentColor,
            hasBorder: item.hasBorder,
            isTab: isTab,
          ),
        ),
      );

      if (isTab) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < items.length - 1 ? 12 : 0),
            child: card,
          ),
        );
      } else {
        return Padding(
          padding: EdgeInsets.only(right: i < items.length - 1 ? 12 : 0),
          child: SizedBox(width: 140, child: card),
        );
      }
    }).toList();

    if (isTab) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cards,
        ),
      );
    } else {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cards,
          ),
        ),
      );
    }
  }

  Widget _shortcutCard({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? accentColor,
    bool hasBorder = false,
    bool isTab = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isTab ? 24 : 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: hasBorder
            ? Border(
                left: BorderSide(
                  color: accentColor ?? AppColors.primary,
                  width: 2,
                ),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isTab ? 56 : 48,
            height: isTab ? 56 : 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (accentColor ?? Colors.white).withValues(
                alpha: accentColor != null ? 0.1 : 0.05,
              ),
            ),
            child: Icon(icon, color: accentColor ?? AppColors.onSurface),
          ),
          const SizedBox(height: 16),
          Text(title, style: AppTextStyles.titleMedium),
          const SizedBox(height: 4),
          Text(subtitle, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }

  Widget _buildRecoveryScore(BuildContext context, DashboardLoaded state) {
    final isTab = Responsive.isTablet(context);
    final ringSize = isTab ? 120.0 : 96.0;
    return Container(
      padding: EdgeInsets.all(isTab ? 40 : 32),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          AnimatedRing(
            progress: state.recoveryScore / 100,
            color: AppColors.primary,
            secondaryColor: AppColors.secondary,
            size: ringSize,
            child: AnimatedCounter(
              value: state.recoveryScore,
              style: AppTextStyles.headlineSmall.copyWith(
                fontSize: isTab ? 28 : 22,
              ),
            ),
          ),
          SizedBox(width: isTab ? 40 : 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recovery Score',
                  style: AppTextStyles.titleLarge.copyWith(
                    fontSize: isTab ? 22 : 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your central nervous system is ${state.recoveryScore}% recovered. You\'re ready for high-intensity lifting today.',
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? accentColor;
  final bool hasBorder;
  const _ShortcutData(
    this.icon,
    this.title,
    this.subtitle,
    this.accentColor,
    this.hasBorder,
  );
}

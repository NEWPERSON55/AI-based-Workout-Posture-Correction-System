import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/animations/kinetic_animations.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../cubit/progress_cubit.dart';
import '../cubit/progress_state.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProgressCubit, ProgressState>(
      builder: (context, state) {
        if (state is! ProgressLoaded) return const SizedBox();
        final hPad = Responsive.horizontalPadding(context);
        final isTab = Responsive.isTablet(context);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 100),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
              child: StaggeredList(
                staggerDelay: const Duration(milliseconds: 100),
                children: [
                  Text('Performance Hub',
                    style: AppTextStyles.headlineLarge.copyWith(fontSize: isTab ? 38 : 32),
                  ),
                  const SizedBox(height: 4),
                  Text('ADVANCED KINETIC ANALYTICS',
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.secondary, letterSpacing: 3),
                  ),
                  const SizedBox(height: 32),
                  // Tablet: hero + AI side by side
                  if (isTab)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _buildSessionsHero(context, state)),
                        const SizedBox(width: 24),
                        Expanded(flex: 2, child: Column(
                          children: [
                            _buildAiCard(),
                            const SizedBox(height: 24),
                            _buildCircularIndicators(context, state),
                          ],
                        )),
                      ],
                    )
                  else ...[
                    _buildSessionsHero(context, state),
                    const SizedBox(height: 24),
                    _buildAiCard(),
                    const SizedBox(height: 24),
                    _buildCircularIndicators(context, state),
                  ],
                  const SizedBox(height: 24),
                  _buildWeeklyGrid(context, state),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSessionsHero(BuildContext context, ProgressLoaded state) {
    final isTab = Responsive.isTablet(context);
    return Container(
      padding: EdgeInsets.all(isTab ? 28 : 24),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('WORKOUT FREQUENCY', style: AppTextStyles.labelSmall.copyWith(letterSpacing: 3)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_up, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text('+${state.sessionsTrend.toInt()}%',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedCounter(
                value: (state.sessionsPerWeek * 10).toInt(),
                style: AppTextStyles.statValue.copyWith(fontSize: isTab ? 54 : 48),
              ),
              const SizedBox(width: 8),
              Text('SESSIONS / WEEK', style: AppTextStyles.labelMedium.copyWith(color: AppColors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: isTab ? 100 : 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(12, (i) {
                final heights = [0.3, 0.5, 0.7, 0.4, 0.8, 0.6, 0.9, 0.5, 0.7, 0.95, 0.6, 0.8];
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: (isTab ? 100 : 80) * heights[i],
                    decoration: BoxDecoration(
                      color: i == 9 ? AppColors.primary : AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.secondary.withValues(alpha: 0.05),
          AppColors.primary.withValues(alpha: 0.05),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.smart_toy, color: AppColors.secondary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI OPTIMIZATION',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.secondary, letterSpacing: 3),
                ),
                const SizedBox(height: 4),
                Text('Increase squat depth by 15° for optimal quad activation. Your consistency is top 8% of users.',
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularIndicators(BuildContext context, ProgressLoaded state) {
    return Row(
      children: [
        Expanded(child: _circularCard(context, 'AVG ACCURACY', state.avgAccuracy, AppColors.primary)),
        const SizedBox(width: 16),
        Expanded(child: _circularCard(context, 'GOAL', state.goalCompletion, AppColors.secondary,
          subtitle: '${state.goalRemaining} remaining',
        )),
      ],
    );
  }

  Widget _circularCard(BuildContext context, String label, double value, Color color, {String? subtitle}) {
    final ringSize = Responsive.value(context, mobile: 90, tablet: 100);
    return Container(
      padding: EdgeInsets.all(Responsive.value(context, mobile: 20, tablet: 24)),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(label, style: AppTextStyles.labelSmall.copyWith(letterSpacing: 3)),
          const SizedBox(height: 16),
          AnimatedRing(
            progress: value / 100,
            color: color,
            size: ringSize,
            child: AnimatedCounter(
              value: value.toInt(),
              style: AppTextStyles.headlineSmall.copyWith(color: color),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle, style: AppTextStyles.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _buildWeeklyGrid(BuildContext context, ProgressLoaded state) {
    final isTab = Responsive.isTablet(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('This Week', style: AppTextStyles.headlineSmall),
        const SizedBox(height: 16),
        // Tablet: 4 columns. Mobile: 2×2.
        if (isTab)
          Row(
            children: [
              _gridItem('CALORIES', '${state.totalCalories.toInt()}', 'kcal', Icons.local_fire_department, AppColors.error),
              const SizedBox(width: 12),
              _gridItem('ACTIVE MIN', '${state.activeMinutes}', 'min', Icons.timer, AppColors.primary),
              const SizedBox(width: 12),
              _gridItem('TOTAL REPS', '${state.totalReps}', 'reps', Icons.repeat, AppColors.error),
              const SizedBox(width: 12),
              _gridItem('SQUATS', '${state.squatReps}', 'reps', Icons.accessibility_new, AppColors.secondary),
            ],
          )
        else
          Column(
            children: [
              Row(
                children: [
                  _gridItem('CALORIES', '${state.totalCalories.toInt()}', 'kcal', Icons.local_fire_department, AppColors.error),
                  const SizedBox(width: 12),
                  _gridItem('ACTIVE MIN', '${state.activeMinutes}', 'min', Icons.timer, AppColors.primary),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _gridItem('TOTAL REPS', '${state.totalReps}', 'reps', Icons.repeat, AppColors.error),
                  const SizedBox(width: 12),
                  _gridItem('SQUATS', '${state.squatReps}', 'reps', Icons.accessibility_new, AppColors.secondary),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _gridItem(String label, String value, String unit, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: AppTextStyles.labelSmall.copyWith(fontSize: 10, letterSpacing: 2)),
                Icon(icon, size: 18, color: color),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(child: Text(value, style: AppTextStyles.headlineSmall)),
                const SizedBox(width: 4),
                Text(unit, style: AppTextStyles.labelSmall.copyWith(color: color, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

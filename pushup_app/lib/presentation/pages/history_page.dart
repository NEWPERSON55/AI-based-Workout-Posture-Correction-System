import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/animations/kinetic_animations.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../cubit/history_cubit.dart';
import '../cubit/history_state.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HistoryCubit, HistoryState>(
      builder: (context, state) {
        if (state is! HistoryLoaded) return const SizedBox();
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
                  Text('Workout Log', style: AppTextStyles.headlineLarge.copyWith(fontSize: isTab ? 38 : 32)),
                  const SizedBox(height: 4),
                  Text('YOUR KINETIC HISTORY',
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.secondary, letterSpacing: 3),
                  ),
                  const SizedBox(height: 32),
                  _buildSummary(context, state),
                  const SizedBox(height: 32),
                  Text('Recent Activity', style: AppTextStyles.headlineSmall),
                  const SizedBox(height: 16),
                  if (isTab)
                    _buildTabletEntries(state)
                  else
                    ...state.entries.asMap().entries.map((entry) => FadeSlideIn(
                      delay: Duration(milliseconds: 400 + entry.key * 120),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildEntry(entry.value),
                      ),
                    )),
                  const SizedBox(height: 32),
                  _buildInsight(state),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabletEntries(HistoryLoaded state) {
    final entries = state.entries;
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: entries.map((e) {
        return SizedBox(
          width: 340,
          child: _buildEntry(e),
        );
      }).toList(),
    );
  }

  Widget _buildSummary(BuildContext context, HistoryLoaded state) {
    final isTab = Responsive.isTablet(context);
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.all(isTab ? 28 : 24),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AVG ACCURACY', style: AppTextStyles.labelSmall.copyWith(letterSpacing: 3)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('${state.avgAccuracy}',
                      style: AppTextStyles.statValue.copyWith(fontSize: isTab ? 40 : 36, color: AppColors.primary),
                    ),
                    Text('%', style: AppTextStyles.titleLarge.copyWith(color: AppColors.primary)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: EdgeInsets.all(isTab ? 28 : 24),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ACTIVE DAYS', style: AppTextStyles.labelSmall.copyWith(letterSpacing: 3)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('${state.activeDays}',
                      style: AppTextStyles.statValue.copyWith(fontSize: isTab ? 40 : 36, color: AppColors.secondary),
                    ),
                    Text(' / 30', style: AppTextStyles.titleLarge.copyWith(color: AppColors.outline)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEntry(HistoryEntry entry) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: entry.isHighlighted
            ? AppColors.primary.withValues(alpha: 0.05)
            : AppColors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: entry.isHighlighted
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.2))
            : Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 56, height: 64,
            decoration: BoxDecoration(
              color: entry.isHighlighted
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(entry.date, style: AppTextStyles.headlineSmall.copyWith(
                  color: entry.isHighlighted ? AppColors.primary : AppColors.onSurface,
                )),
                Text(entry.month, style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 10,
                  color: entry.isHighlighted ? AppColors.primary : AppColors.onSurfaceVariant,
                )),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: Text(entry.name, style: AppTextStyles.titleLarge)),
                    if (entry.badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(9999),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(entry.badge!.toUpperCase(),
                          style: AppTextStyles.labelSmall.copyWith(fontSize: 9, color: AppColors.primary),
                        ),
                      )
                    else
                      Text(entry.precision, style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(entry.sets, style: AppTextStyles.labelSmall.copyWith(fontSize: 11)),
                    Text('  •  ', style: TextStyle(color: AppColors.outline)),
                    Text(entry.duration, style: AppTextStyles.labelSmall.copyWith(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsight(HistoryLoaded state) {
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
                Text('AI COACH INSIGHT',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.secondary, letterSpacing: 3),
                ),
                const SizedBox(height: 8),
                Text(state.coachInsight, style: AppTextStyles.bodyMedium.copyWith(height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/animations/kinetic_animations.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../injection.dart';
import '../../domain/repositories/workout_repository.dart';
import '../cubit/exercises_cubit.dart';
import '../cubit/exercises_state.dart';
import '../cubit/pushup_cubit.dart';
import '../cubit/squat_cubit.dart';
import 'home_page.dart';
import 'squat_page.dart';

class ExercisesPage extends StatelessWidget {
  const ExercisesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExercisesCubit, ExercisesState>(
      builder: (context, state) {
        if (state is! ExercisesLoaded) return const SizedBox();
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
                  _buildSearchBar(context, state),
                  const SizedBox(height: 24),
                  _buildAiChip(state),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Select Exercise', style: AppTextStyles.headlineSmall),
                      Text('${state.exercises.length} AVAILABLE',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Tablet: 2-column grid. Mobile: single column list.
                  if (isTab)
                    _buildTabletGrid(context, state)
                  else
                    ...state.exercises.asMap().entries.map((entry) => FadeSlideIn(
                      delay: Duration(milliseconds: 400 + entry.key * 100),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ScaleOnTap(
                          onTap: () => _navigateToExercise(context, entry.value.name),
                          child: _buildExerciseItem(context, entry.value),
                        ),
                      ),
                    )),
                  const SizedBox(height: 32),
                  ScaleOnTap(child: _buildCreateButton()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabletGrid(BuildContext context, ExercisesLoaded state) {
    final exercises = state.exercises;
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: exercises.map((e) {
        return SizedBox(
          width: (Responsive.contentMaxWidth(context) -
                  Responsive.horizontalPadding(context) * 2 - 16) / 2,
          child: _buildExerciseItem(context, e),
        );
      }).toList(),
    );
  }

  Widget _buildSearchBar(BuildContext context, ExercisesLoaded state) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: [
          AppColors.secondary.withValues(alpha: 0.1),
          AppColors.primary.withValues(alpha: 0.1),
        ]),
      ),
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                onChanged: (q) => context.read<ExercisesCubit>().search(q),
                style: const TextStyle(color: AppColors.onSurface),
                decoration: InputDecoration(
                  hintText: 'Find your next push...',
                  hintStyle: TextStyle(color: AppColors.outline),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const Icon(Icons.mic, color: AppColors.secondary),
          ],
        ),
      ),
    );
  }

  Widget _buildAiChip(ExercisesLoaded state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.smart_toy, color: AppColors.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI COACH PREDICTION',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.secondary, letterSpacing: 3),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    text: 'Based on your recovery, ',
                    style: AppTextStyles.bodyMedium,
                    children: [
                      TextSpan(
                        text: state.aiPrediction,
                        style: const TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                      ),
                      const TextSpan(text: ' will maximize your kinetic output today.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseItem(BuildContext context, Exercise exercise) {
    final levelColor = exercise.level == 'Advanced'
        ? AppColors.error
        : exercise.level == 'Intermediate'
            ? AppColors.secondary
            : AppColors.primary;

    return GestureDetector(
      onTap: () => _navigateToExercise(context, exercise.name),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.2)),
              ),
              child: Icon(_getExerciseIcon(exercise.iconType), color: AppColors.primary, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(exercise.name, style: AppTextStyles.titleLarge),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: levelColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(9999),
                          border: Border.all(color: levelColor.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          exercise.level.toUpperCase(),
                          style: AppTextStyles.labelSmall.copyWith(fontSize: 9, color: levelColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        const Icon(Icons.local_fire_department, size: 14, color: AppColors.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(exercise.calories, style: AppTextStyles.labelSmall.copyWith(fontSize: 11)),
                        const SizedBox(width: 16),
                        const Icon(Icons.timer, size: 14, color: AppColors.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(exercise.duration, style: AppTextStyles.labelSmall.copyWith(fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.outline),
          ],
        ),
      ),
    );
  }

  void _navigateToExercise(BuildContext context, String name) async {
    final user = FirebaseAuth.instance.currentUser;
    double weight = 70.0;
    if (user != null) {
      try {
        final profile = await sl<WorkoutRepository>().getUserProfile(user.uid);
        weight = profile?.weight ?? 70.0;
      } catch (_) {}
    }

    if (!context.mounted) return;

    if (name == 'Push-up') {
      final cubit = sl<PushupCubit>();
      if (user != null) cubit.setUser(user.uid, weightKg: weight);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BlocProvider(create: (_) => cubit, child: const HomePage()),
      ));
    } else if (name == 'Squat') {
      final cubit = sl<SquatCubit>();
      if (user != null) cubit.setUser(user.uid, weightKg: weight);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BlocProvider(create: (_) => cubit, child: const SquatPage()),
      ));
    }
  }

  IconData _getExerciseIcon(IconType type) {
    switch (type) {
      case IconType.fitnessCenter: return Icons.fitness_center;
      case IconType.exercise: return Icons.self_improvement;
      case IconType.reorder: return Icons.reorder;
      case IconType.directionsRun: return Icons.directions_run;
    }
  }

  Widget _buildCreateButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_circle_outline, color: AppColors.onSurface),
          const SizedBox(width: 12),
          Text('Create Custom Circuit', style: AppTextStyles.titleMedium),
        ],
      ),
    );
  }
}

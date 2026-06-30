import '../../core/config/app_config.dart';

/// Calculates calories burned for a workout session.
///
/// Uses a hybrid approach:
/// - Rep-based for short sessions (< 50 reps) — more accurate
/// - MET-based for longer sessions — accounts for sustained effort
///
/// All values scale linearly with user weight relative to 70 kg baseline.
class CalculateCalories {
  const CalculateCalories();

  /// Calculate KCAL burned for a workout.
  ///
  /// [exerciseType] — 'pushup' or 'squat'
  /// [repCount] — number of completed reps
  /// [durationSeconds] — session duration in seconds
  /// [userWeightKg] — user's weight in kilograms
  double call({
    required String exerciseType,
    required int repCount,
    required int durationSeconds,
    required double userWeightKg,
  }) {
    final weightRatio = userWeightKg / 70.0;

    if (repCount <= 0) return 0.0;

    // Rep-based calculation (better for short bursts)
    final kcalPerRep = exerciseType == 'pushup'
        ? AppConfig.pushupKcalPerRep70kg
        : AppConfig.squatKcalPerRep70kg;
    final repBased = repCount * kcalPerRep * weightRatio;

    // MET-based calculation
    final met = exerciseType == 'pushup'
        ? AppConfig.pushupMetValue
        : AppConfig.squatMetValue;
    final durationHours = durationSeconds / 3600.0;
    final metBased = met * userWeightKg * durationHours;

    // Hybrid: use rep-based for short sessions, MET for longer
    if (repCount < 50) {
      return double.parse(repBased.toStringAsFixed(1));
    }
    // For longer sessions, take the higher of the two
    final result = repBased > metBased ? repBased : metBased;
    return double.parse(result.toStringAsFixed(1));
  }
}

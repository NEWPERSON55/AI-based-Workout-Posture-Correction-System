import '../entities/user_profile.dart';
import '../entities/workout_session.dart';

/// Abstract workout data repository.
abstract class WorkoutRepository {
  // ── Workout sessions ──────────────────────────────
  Future<void> saveWorkout(String uid, WorkoutSession session);
  Future<List<WorkoutSession>> getWorkoutHistory(String uid,
      {int limit = 50, String? exerciseType});
  Future<List<WorkoutSession>> getWorkoutsAfter(String uid, DateTime after);

  // ── User profile ──────────────────────────────────
  Future<UserProfile?> getUserProfile(String uid);
  Future<void> saveUserProfile(String uid, UserProfile profile);

  // ── Aggregated stats ──────────────────────────────
  Future<int> getTotalWorkoutCount(String uid);
}

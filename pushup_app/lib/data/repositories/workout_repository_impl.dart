import '../../domain/entities/user_profile.dart';
import '../../domain/entities/workout_session.dart';
import '../../domain/repositories/workout_repository.dart';
import '../datasources/firestore_datasource.dart';

class WorkoutRepositoryImpl implements WorkoutRepository {
  final FirestoreDatasource _datasource;

  WorkoutRepositoryImpl(this._datasource);

  @override
  Future<void> saveWorkout(String uid, WorkoutSession session) =>
      _datasource.saveWorkout(uid, session);

  @override
  Future<List<WorkoutSession>> getWorkoutHistory(String uid,
          {int limit = 50, String? exerciseType}) =>
      _datasource.getWorkoutHistory(uid,
          limit: limit, exerciseType: exerciseType);

  @override
  Future<List<WorkoutSession>> getWorkoutsAfter(
          String uid, DateTime after) =>
      _datasource.getWorkoutsAfter(uid, after);

  @override
  Future<UserProfile?> getUserProfile(String uid) =>
      _datasource.getUserProfile(uid);

  @override
  Future<void> saveUserProfile(String uid, UserProfile profile) =>
      _datasource.saveUserProfile(uid, profile);

  @override
  Future<int> getTotalWorkoutCount(String uid) =>
      _datasource.getTotalWorkoutCount(uid);
}

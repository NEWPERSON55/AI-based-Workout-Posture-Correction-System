import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/workout_repository.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final WorkoutRepository _workoutRepo;

  ProfileCubit(this._workoutRepo) : super(const ProfileLoading());

  Future<void> loadProfile(String uid) async {
    emit(const ProfileLoading());
    try {
      final profile = await _workoutRepo.getUserProfile(uid);
      final totalWorkouts = await _workoutRepo.getTotalWorkoutCount(uid);

      // Calculate tier
      final tier = UserProfile.calculateTier(totalWorkouts);

      // Update tier in Firestore if changed
      if (profile != null && profile.tier != tier) {
        await _workoutRepo.saveUserProfile(
          uid,
          profile.copyWith(tier: tier),
        );
      }

      // Generate coach analysis based on workout count
      String analysis;
      if (totalWorkouts == 0) {
        analysis = 'Welcome! Start your first workout to begin your fitness journey.';
      } else if (totalWorkouts < 10) {
        analysis =
            'You\'ve completed $totalWorkouts workouts. Keep building consistency to reach Intermediate tier!';
      } else if (totalWorkouts < 50) {
        analysis =
            'Great momentum with $totalWorkouts workouts! You\'re on track for Advanced tier. Focus on form quality.';
      } else {
        analysis =
            'Impressive $totalWorkouts workouts! You\'re in the top tier. Consider increasing workout complexity.';
      }

      emit(ProfileLoaded(
        name: profile?.name ?? 'User',
        email: profile?.email ?? '',
        age: profile?.age ?? 25,
        weight: profile?.weight ?? 70.0,
        height: '${profile?.height.round() ?? 170}',
        goal: profile?.goal ?? 'Stay Fit',
        tier: tier,
        coachAnalysis: analysis,
        totalWorkouts: totalWorkouts,
      ));
    } catch (e) {
      emit(const ProfileLoaded(
        coachAnalysis: 'Unable to load profile. Please try again.',
      ));
    }
  }

  Future<void> updateProfile(String uid, {
    String? name,
    int? age,
    double? weight,
    double? height,
    String? goal,
  }) async {
    try {
      final existing = await _workoutRepo.getUserProfile(uid);
      if (existing == null) return;

      final updated = existing.copyWith(
        name: name,
        age: age,
        weight: weight,
        height: height,
        goal: goal,
      );
      await _workoutRepo.saveUserProfile(uid, updated);
      await loadProfile(uid);
    } catch (_) {}
  }
}

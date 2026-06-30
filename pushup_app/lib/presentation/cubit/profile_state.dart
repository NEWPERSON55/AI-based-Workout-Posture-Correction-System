import 'package:equatable/equatable.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();
  @override
  List<Object?> get props => [];
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileLoaded extends ProfileState {
  final String name;
  final String email;
  final int age;
  final double weight;
  final String height;
  final String goal;
  final String tier;
  final String coachAnalysis;
  final int totalWorkouts;

  const ProfileLoaded({
    this.name = '',
    this.email = '',
    this.age = 25,
    this.weight = 70.0,
    this.height = '170',
    this.goal = 'Stay Fit',
    this.tier = 'BEGINNER',
    this.coachAnalysis = 'Complete workouts to unlock personalized coaching analysis.',
    this.totalWorkouts = 0,
  });

  @override
  List<Object?> get props =>
      [name, email, age, weight, height, goal, tier, coachAnalysis, totalWorkouts];
}

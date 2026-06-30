import 'package:equatable/equatable.dart';

/// User profile entity stored in Firestore.
class UserProfile extends Equatable {
  final String uid;
  final String name;
  final String email;
  final int age;
  final double weight; // kg
  final double height; // cm
  final String goal; // 'Build Muscle', 'Lose Weight', 'Stay Fit'
  final String tier; // Calculated: 'BEGINNER', 'INTERMEDIATE', 'ADVANCED', 'ELITE'
  final DateTime createdAt;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.age = 25,
    this.weight = 70.0,
    this.height = 170.0,
    this.goal = 'Stay Fit',
    this.tier = 'BEGINNER',
    required this.createdAt,
  });

  UserProfile copyWith({
    String? name,
    String? email,
    int? age,
    double? weight,
    double? height,
    String? goal,
    String? tier,
  }) {
    return UserProfile(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      age: age ?? this.age,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      goal: goal ?? this.goal,
      tier: tier ?? this.tier,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'age': age,
        'weight': weight,
        'height': height,
        'goal': goal,
        'tier': tier,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      age: map['age'] as int? ?? 25,
      weight: (map['weight'] as num?)?.toDouble() ?? 70.0,
      height: (map['height'] as num?)?.toDouble() ?? 170.0,
      goal: map['goal'] as String? ?? 'Stay Fit',
      tier: map['tier'] as String? ?? 'BEGINNER',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }

  /// Calculate tier based on total workout count.
  static String calculateTier(int totalWorkouts) {
    if (totalWorkouts >= 100) return 'ELITE';
    if (totalWorkouts >= 50) return 'ADVANCED';
    if (totalWorkouts >= 10) return 'INTERMEDIATE';
    return 'BEGINNER';
  }

  @override
  List<Object?> get props =>
      [uid, name, email, age, weight, height, goal, tier, createdAt];
}

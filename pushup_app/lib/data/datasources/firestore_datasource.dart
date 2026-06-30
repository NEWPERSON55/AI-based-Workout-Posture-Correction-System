import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/workout_session.dart';

/// Firestore datasource for user profiles and workout sessions.
///
/// Collections:
///   users/{uid}            — profile document
///   users/{uid}/workouts   — sub-collection of workout sessions
class FirestoreDatasource {
  final FirebaseFirestore _db;

  FirestoreDatasource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  // ── User Profile ──────────────────────────────────

  /// Get a user's profile document.
  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserProfile.fromMap(uid, doc.data()!);
  }

  /// Create or update a user's profile.
  Future<void> saveUserProfile(String uid, UserProfile profile) {
    return _db.collection('users').doc(uid).set(
          profile.toMap(),
          SetOptions(merge: true),
        );
  }

  // ── Workout Sessions ──────────────────────────────

  /// Save a completed workout session.
  Future<void> saveWorkout(String uid, WorkoutSession session) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('workouts')
        .doc(session.id)
        .set(session.toMap());
  }

  /// Fetch workout history, ordered by timestamp descending.
  Future<List<WorkoutSession>> getWorkoutHistory(
    String uid, {
    int limit = 50,
    String? exerciseType,
  }) async {
    Query<Map<String, dynamic>> query = _db
        .collection('users')
        .doc(uid)
        .collection('workouts')
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (exerciseType != null) {
      query = query.where('exerciseType', isEqualTo: exerciseType);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => WorkoutSession.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Fetch all workouts after a given date (for stats calculations).
  Future<List<WorkoutSession>> getWorkoutsAfter(
      String uid, DateTime after) async {
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('workouts')
        .where('timestamp', isGreaterThanOrEqualTo: after.toIso8601String())
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => WorkoutSession.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Get total workout count for a user (for tier calculation).
  Future<int> getTotalWorkoutCount(String uid) async {
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('workouts')
        .count()
        .get();
    return snapshot.count ?? 0;
  }
}

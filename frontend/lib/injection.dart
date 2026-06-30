import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/datasources/websocket_datasource.dart';
import 'data/datasources/firebase_auth_datasource.dart';
import 'data/datasources/firestore_datasource.dart';
import 'data/datasources/gemini_datasource.dart';
import 'data/repositories/pushup_repository_impl.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/workout_repository_impl.dart';
import 'data/repositories/chat_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/workout_repository.dart';
import 'domain/repositories/chat_repository.dart';
import 'domain/usecases/connect_usecase.dart';
import 'domain/usecases/send_frame_usecase.dart';
import 'domain/usecases/send_video_usecase.dart';
import 'domain/usecases/disconnect_usecase.dart';
import 'domain/usecases/calculate_calories.dart';
import 'presentation/cubit/auth_cubit.dart';
import 'presentation/cubit/dashboard_cubit.dart';
import 'presentation/cubit/history_cubit.dart';
import 'presentation/cubit/profile_cubit.dart';
import 'presentation/cubit/progress_cubit.dart';
import 'presentation/cubit/ai_coach_cubit.dart';
import 'presentation/cubit/exercises_cubit.dart';
import 'presentation/cubit/settings_cubit.dart';
import 'presentation/cubit/pushup_cubit.dart';
import 'presentation/cubit/squat_cubit.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // ── External ────────────────────────────────────────
  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(prefs);

  // ── Firebase Datasources (singletons) ───────────────
  sl.registerLazySingleton<FirebaseAuthDatasource>(
      () => FirebaseAuthDatasource());
  sl.registerLazySingleton<FirestoreDatasource>(() => FirestoreDatasource());
  sl.registerLazySingleton<GeminiDatasource>(() => GeminiDatasource());

  // ── Repositories (singletons) ───────────────────────
  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(
        sl<FirebaseAuthDatasource>(),
        sl<FirestoreDatasource>(),
      ));
  sl.registerLazySingleton<WorkoutRepository>(
      () => WorkoutRepositoryImpl(sl<FirestoreDatasource>()));
  sl.registerLazySingleton<ChatRepository>(
      () => ChatRepositoryImpl(sl<GeminiDatasource>()));

  // ── Use Cases ───────────────────────────────────────
  sl.registerLazySingleton<CalculateCalories>(() => const CalculateCalories());

  // ── Cubits ──────────────────────────────────────────

  // Auth — singleton so it persists across the app
  sl.registerLazySingleton<AuthCubit>(() => AuthCubit(sl<AuthRepository>()));

  // Dashboard, History, Profile, Progress — factories (fresh per screen visit)
  sl.registerFactory<DashboardCubit>(
      () => DashboardCubit(sl<WorkoutRepository>()));
  sl.registerFactory<HistoryCubit>(
      () => HistoryCubit(sl<WorkoutRepository>()));
  sl.registerFactory<ProfileCubit>(
      () => ProfileCubit(sl<WorkoutRepository>()));
  sl.registerFactory<ProgressCubit>(
      () => ProgressCubit(sl<WorkoutRepository>()));

  // AI Coach
  sl.registerFactory<AiCoachCubit>(
      () => AiCoachCubit(sl<ChatRepository>(), sl<WorkoutRepository>()));

  // Exercises
  sl.registerFactory<ExercisesCubit>(() => ExercisesCubit());

  // Settings
  sl.registerFactory<SettingsCubit>(
      () => SettingsCubit(sl<SharedPreferences>()));

  // Push-up & Squat — each gets its own WebSocket pipeline
  sl.registerFactory<PushupCubit>(() {
    final repo = PushupRepositoryImpl(WebSocketDatasource());
    return PushupCubit(
      connectUseCase: ConnectUseCase(repo),
      sendFrameUseCase: SendFrameUseCase(repo),
      sendVideoUseCase: SendVideoUseCase(repo),
      disconnectUseCase: DisconnectUseCase(repo),
      workoutRepo: sl<WorkoutRepository>(),
      calculateCalories: sl<CalculateCalories>(),
    );
  });

  sl.registerFactory<SquatCubit>(() {
    final repo = PushupRepositoryImpl(WebSocketDatasource());
    return SquatCubit(
      connectUseCase: ConnectUseCase(repo),
      sendFrameUseCase: SendFrameUseCase(repo),
      sendVideoUseCase: SendVideoUseCase(repo),
      disconnectUseCase: DisconnectUseCase(repo),
      workoutRepo: sl<WorkoutRepository>(),
      calculateCalories: sl<CalculateCalories>(),
    );
  });
}

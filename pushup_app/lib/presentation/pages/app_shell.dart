import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_colors.dart';
import '../../injection.dart';
import '../cubit/navigation_cubit.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/exercises_cubit.dart';
import '../cubit/ai_coach_cubit.dart';
import '../cubit/history_cubit.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/progress_cubit.dart';
import '../widgets/kinetic_app_bar.dart';
import '../widgets/kinetic_bottom_nav.dart';
import 'dashboard_page.dart';
import 'exercises_page.dart';
import 'ai_coach_page.dart';
import 'history_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';

/// App shell with bottom navigation hosting the main tab pages.
/// Loads real data for the signed-in user from Firestore.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => NavigationCubit()),
        BlocProvider(create: (_) => sl<DashboardCubit>()..loadDashboard(uid)),
        BlocProvider(create: (_) => sl<ExercisesCubit>()),
        BlocProvider(create: (_) {
          final cubit = sl<AiCoachCubit>();
          cubit.setUser(uid);
          return cubit;
        }),
        BlocProvider(create: (_) => sl<HistoryCubit>()..loadHistory(uid)),
        BlocProvider(create: (_) => sl<ProfileCubit>()..loadProfile(uid)),
        BlocProvider(create: (_) => sl<ProgressCubit>()..loadProgress(uid)),
      ],
      child: BlocBuilder<NavigationCubit, int>(
        builder: (context, currentIndex) {
          return Scaffold(
            backgroundColor: AppColors.background,
            extendBody: true,
            appBar: KineticAppBar(
              onSettingsTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BlocProvider(
                      create: (_) => sl<SettingsCubit>(),
                      child: const SettingsPage(),
                    ),
                  ),
                );
              },
              onProfileTap: () {
                context.read<NavigationCubit>().setTab(4);
              },
            ),
            body: IndexedStack(
              index: currentIndex,
              children: const [
                DashboardPage(),
                ExercisesPage(),
                AiCoachPage(),
                HistoryPage(),
                ProfilePage(),
              ],
            ),
            bottomNavigationBar: KineticBottomNav(
              currentIndex: currentIndex,
              onTap: (i) => context.read<NavigationCubit>().setTab(i),
            ),
          );
        },
      ),
    );
  }
}

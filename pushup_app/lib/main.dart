import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'injection.dart';
import 'core/theme/app_theme.dart';
import 'presentation/cubit/auth_cubit.dart';
import 'presentation/pages/login_page.dart';
import 'presentation/pages/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,);
  await initDependencies();
  runApp(const KineticApp());
}

class KineticApp extends StatelessWidget {
  const KineticApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<AuthCubit>(),
      child: MaterialApp(
        title: 'KINETIC AI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            // Still loading
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            // User is signed in → go to app
            if (snapshot.hasData && snapshot.data != null) {
              return const AppShell();
            }
            // Not signed in → login
            return const LoginPage();
          },
        ),
      ),
    );
  }
}

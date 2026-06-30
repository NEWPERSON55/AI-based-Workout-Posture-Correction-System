import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../injection.dart';
import '../../domain/repositories/workout_repository.dart';
import '../cubit/pushup_cubit.dart';
import '../cubit/squat_cubit.dart';
import 'home_page.dart';
import 'squat_page.dart';

class ExerciseSelectorPage extends StatelessWidget {
  const ExerciseSelectorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 48),

              // ── Header ──
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF00BFA5)],
                ).createShader(bounds),
                child: const Text(
                  'Exercise AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose your exercise',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 48),

              // ── Exercise Cards ──
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Push-up Card
                    _ExerciseCard(
                      title: 'Push-ups',
                      subtitle: 'Upper body strength',
                      icon: Icons.fitness_center_rounded,
                      gradient: const [Color(0xFF6C63FF), Color(0xFF3F3D9E)],
                      glowColor: const Color(0xFF6C63FF),
                      onTap: () async {
                        final cubit = sl<PushupCubit>();
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          double weight = 70.0;
                          try {
                            final profile = await sl<WorkoutRepository>().getUserProfile(user.uid);
                            weight = profile?.weight ?? 70.0;
                          } catch (_) {}
                          cubit.setUser(user.uid, weightKg: weight);
                        }
                        if (!context.mounted) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BlocProvider(
                              create: (_) => cubit,
                              child: const HomePage(),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Squat Card
                    _ExerciseCard(
                      title: 'Squats',
                      subtitle: 'Lower body strength',
                      icon: Icons.accessibility_new_rounded,
                      gradient: const [Color(0xFF00BFA5), Color(0xFF00796B)],
                      glowColor: const Color(0xFF00BFA5),
                      onTap: () async {
                        final cubit = sl<SquatCubit>();
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          double weight = 70.0;
                          try {
                            final profile = await sl<WorkoutRepository>().getUserProfile(user.uid);
                            weight = profile?.weight ?? 70.0;
                          } catch (_) {}
                          cubit.setUser(user.uid, weightKg: weight);
                        }
                        if (!context.mounted) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BlocProvider(
                              create: (_) => cubit,
                              child: const SquatPage(),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // ── Footer ──
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  'Powered by MoveNet + LSTM',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final Color glowColor;
  final VoidCallback onTap;

  const _ExerciseCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.glowColor,
    required this.onTap,
  });

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.gradient[0].withValues(alpha: 0.15),
                widget.gradient[1].withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.gradient[0].withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: 0.15),
                blurRadius: 30,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon circle
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: widget.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.glowColor.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(width: 24),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.4),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


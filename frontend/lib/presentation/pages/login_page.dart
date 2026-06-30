import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/animations/kinetic_animations.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../injection.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';
import '../widgets/glass_card.dart';
import '../widgets/kinetic_button.dart';
import '../widgets/kinetic_text_field.dart';
import 'sign_up_page.dart';
import 'forgot_password_page.dart';
import 'app_shell.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTab = Responsive.isTablet(context);

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthSuccess) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const AppShell(),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // ── Animated Background Glows ──
            _AnimatedGlow(
              top: -100,
              right: -100,
              size: Responsive.value(context, mobile: 300, tablet: 500),
              color: AppColors.primary,
              delay: const Duration(milliseconds: 200),
            ),
            _AnimatedGlow(
              bottom: -100,
              left: -100,
              size: Responsive.value(context, mobile: 250, tablet: 400),
              color: AppColors.secondary,
              delay: const Duration(milliseconds: 600),
            ),

            // ── Content ──
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.horizontalPadding(context),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isTab ? 520 : 480),
                    child: StaggeredList(
                      staggerDelay: const Duration(milliseconds: 120),
                      children: [
                        SizedBox(height: isTab ? 64 : 48),
                        _buildBranding(context),
                        SizedBox(height: isTab ? 56 : 48),
                        _buildLoginForm(context),
                        SizedBox(height: isTab ? 40 : 32),
                        _buildFooter(context),
                        SizedBox(height: isTab ? 64 : 48),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Animated Bottom Accent Bar ──
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: FadeSlideIn(
                delay: const Duration(milliseconds: 800),
                offsetY: 0,
                child: Container(
                  height: 2,
                  color: AppColors.surfaceContainer,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 0.33),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    builder: (_, val, __) {
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: val,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranding(BuildContext context) {
    final scale = Responsive.fontScale(context);
    return Column(
      children: [
        PulseGlow(
          glowColor: AppColors.primary,
          maxBlur: 25,
          child: Container(
            width: 64 * scale,
            height: 64 * scale,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppColors.primary.withValues(alpha: 0.1),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(
              Icons.fitness_center,
              color: AppColors.primary,
              size: 32 * scale,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'KINETIC',
              style: AppTextStyles.headlineLarge.copyWith(fontSize: 36 * scale),
            ),
            const SizedBox(width: 4),
            Text(
              'AI',
              style: AppTextStyles.titleLarge.copyWith(
                color: AppColors.primary,
                fontSize: 18 * scale,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'PRECISION PERFORMANCE PROTOCOL',
          style: AppTextStyles.labelSmall.copyWith(
            letterSpacing: 4,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final isPasswordVisible =
            state is AuthInitial && state.isPasswordVisible;
        final isLoading = state is AuthLoading;

        return GlassCard(
          padding: EdgeInsets.all(
            Responsive.value(context, mobile: 24, tablet: 36),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KineticTextField(
                hint: 'Email Address',
                prefixIcon: Icons.alternate_email,
                keyboardType: TextInputType.emailAddress,
                controller: _emailController,
              ),
              const SizedBox(height: 16),
              KineticTextField(
                hint: 'Password',
                prefixIcon: Icons.lock_outline,
                obscureText: !isPasswordVisible,
                controller: _passwordController,
                suffix: IconButton(
                  icon: Icon(
                    isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.onSurfaceVariant,
                    size: 18,
                  ),
                  onPressed: () =>
                      context.read<AuthCubit>().togglePasswordVisibility(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('KEEP LOGGED IN', style: AppTextStyles.labelSmall),
                    ],
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: sl<AuthCubit>(),
                      child: const ForgotPasswordPage(),
                    ),
                  ),
                ),
                child: Text(
                  'FORGOT PASSWORD?',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.secondary,
                    letterSpacing: 3,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ScaleOnTap(
                onTap: () => context.read<AuthCubit>().login(
                  _emailController.text,
                  _passwordController.text,
                ),
                child: KineticButton(
                  label: 'Initiate Login',
                  icon: Icons.bolt,
                  isLoading: isLoading,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      color: AppColors.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'EXTERNAL AUTHENTICATOR',
                      style: AppTextStyles.labelSmall.copyWith(
                        fontSize: 10,
                        letterSpacing: 3,
                        color: AppColors.outline,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: AppColors.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ScaleOnTap(
                onTap: () =>
                    context.read<AuthCubit>().login('google', 'google'),
                child: const KineticButton(
                  label: 'Connect with Google',
                  isOutlined: true,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('New to the system? ', style: AppTextStyles.bodyMedium),
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: sl<AuthCubit>(),
                child: const SignUpPage(),
              ),
            ),
          ),
          child: Text(
            'Establish Profile',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Animated background glow circle that fades in.
class _AnimatedGlow extends StatelessWidget {
  final double? top, bottom, left, right;
  final double size;
  final Color color;
  final Duration delay;

  const _AnimatedGlow({
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.size,
    required this.color,
    this.delay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: FadeSlideIn(
        delay: delay,
        offsetY: 0,
        duration: const Duration(milliseconds: 1200),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withValues(alpha: 0.06), Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }
}

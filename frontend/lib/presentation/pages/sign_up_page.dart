import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/animations/kinetic_animations.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';
import '../widgets/glass_card.dart';
import '../widgets/kinetic_button.dart';
import '../widgets/kinetic_text_field.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTab = Responsive.isTablet(context);

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthSuccess) {
          Navigator.of(context).pop();
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            Positioned(
              top: -100, right: -100,
              child: Container(
                width: Responsive.value(context, mobile: 300, tablet: 500),
                height: Responsive.value(context, mobile: 300, tablet: 500),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppColors.primary.withValues(alpha: 0.05), Colors.transparent,
                  ]),
                ),
              ),
            ),
            Positioned(
              bottom: -100, left: -100,
              child: Container(
                width: Responsive.value(context, mobile: 250, tablet: 400),
                height: Responsive.value(context, mobile: 250, tablet: 400),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppColors.secondary.withValues(alpha: 0.05), Colors.transparent,
                  ]),
                ),
              ),
            ),
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
                        _buildForm(context),
                        SizedBox(height: isTab ? 40 : 32),
                        _buildFooter(context),
                        const SizedBox(height: 40),
                        _buildAiChip(),
                        SizedBox(height: isTab ? 64 : 48),
                      ],
                    ),
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
        Container(
          width: 64 * scale, height: 64 * scale,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: AppColors.primary.withValues(alpha: 0.1),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 20)],
          ),
          child: Icon(Icons.fitness_center, color: AppColors.primary, size: 32 * scale),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('KINETIC', style: AppTextStyles.headlineLarge.copyWith(fontSize: 36 * scale)),
            const SizedBox(width: 4),
            Text('AI', style: AppTextStyles.titleLarge.copyWith(color: AppColors.primary, fontSize: 18 * scale)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'PRECISION PERFORMANCE PROTOCOL',
          style: AppTextStyles.labelSmall.copyWith(letterSpacing: 4, color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final cubit = context.read<AuthCubit>();
        final isLoading = state is AuthLoading;
        final termsAccepted = state is AuthInitial && state.termsAccepted;

        return GlassCard(
          padding: EdgeInsets.all(
            Responsive.value(context, mobile: 24, tablet: 36),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create Account', style: AppTextStyles.headlineSmall),
              const SizedBox(height: 4),
              Text('Initialize your high-performance fitness profile.',
                  style: AppTextStyles.bodyMedium),
              const SizedBox(height: 24),
              KineticTextField(
                hint: 'Full Name',
                prefixIcon: Icons.person_outline,
                controller: _nameController,
              ),
              const SizedBox(height: 16),
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
                obscureText: true,
                controller: _passwordController,
              ),
              const SizedBox(height: 16),
              KineticTextField(
                hint: 'Confirm Password',
                prefixIcon: Icons.lock_reset,
                obscureText: true,
                controller: _confirmPasswordController,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => cubit.toggleTerms(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: termsAccepted ? AppColors.primary : AppColors.outlineVariant,
                        ),
                        color: termsAccepted ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surfaceContainer,
                      ),
                      child: termsAccepted
                          ? const Icon(Icons.check, size: 14, color: AppColors.primary)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: 'I agree to the ',
                          style: AppTextStyles.labelSmall.copyWith(fontSize: 10),
                          children: [
                            TextSpan(text: 'Terms of Protocol', style: TextStyle(color: AppColors.secondary)),
                            const TextSpan(text: ' and '),
                            TextSpan(text: 'Privacy Logic', style: TextStyle(color: AppColors.secondary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              KineticButton(
                label: 'Sign Up',
                icon: Icons.bolt,
                isLoading: isLoading,
                onPressed: () {
                  if (_passwordController.text != _confirmPasswordController.text) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Passwords do not match'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }
                  cubit.signUp(
                    _nameController.text,
                    _emailController.text,
                    _passwordController.text,
                  );
                },
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
        Text('Already in the system? ', style: AppTextStyles.bodyMedium),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Text(
            'Login here',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.primary, fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAiChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.smart_toy, color: AppColors.secondary, size: 16),
          const SizedBox(width: 8),
          Text(
            'AI COACH IS READY FOR CALIBRATION',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.onSurface, letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

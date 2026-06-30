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

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTab = Responsive.isTablet(context);

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppColors.primary),
          );
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
              top: -128, left: -128,
              child: Container(
                width: Responsive.value(context, mobile: 256, tablet: 400),
                height: Responsive.value(context, mobile: 256, tablet: 400),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppColors.primary.withValues(alpha: 0.1), Colors.transparent,
                  ]),
                ),
              ),
            ),
            Positioned(
              bottom: -128, right: -128,
              child: Container(
                width: Responsive.value(context, mobile: 320, tablet: 480),
                height: Responsive.value(context, mobile: 320, tablet: 480),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppColors.secondary.withValues(alpha: 0.1), Colors.transparent,
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      staggerDelay: const Duration(milliseconds: 120),
                      children: [
                        Text('KINETIC',
                          style: AppTextStyles.headlineLarge.copyWith(color: AppColors.primary),
                        ),
                        const SizedBox(height: 8),
                        Text('PRECISION RECOVERY SYSTEM',
                          style: AppTextStyles.labelSmall.copyWith(letterSpacing: 4),
                        ),
                        SizedBox(height: isTab ? 64 : 48),
                        _buildCard(context),
                        const SizedBox(height: 32),
                        _buildAiNote(),
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

  Widget _buildCard(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        return GlassCard(
          padding: EdgeInsets.all(
            Responsive.value(context, mobile: 24, tablet: 36),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  text: 'Recovery ',
                  style: AppTextStyles.headlineMedium,
                  children: [
                    TextSpan(text: 'Protocol', style: TextStyle(color: AppColors.secondary)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Enter the identifier associated with your profile. Our AI will transmit a secure synchronization link to re-establish your access.',
                style: AppTextStyles.bodyMedium.copyWith(height: 1.6),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NETWORK IDENTIFIER',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.secondary, letterSpacing: 3),
                    ),
                    const SizedBox(height: 8),
                    KineticTextField(
                      hint: 'name@domain.com',
                      prefixIcon: Icons.alternate_email,
                      keyboardType: TextInputType.emailAddress,
                      controller: _emailController,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              KineticButton(
                label: 'Send Reset Link',
                icon: Icons.arrow_forward,
                isLoading: isLoading,
                onPressed: () =>
                    context.read<AuthCubit>().forgotPassword(_emailController.text),
              ),
              const SizedBox(height: 40),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back, size: 14, color: AppColors.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text('BACK TO LOGIN',
                        style: AppTextStyles.labelSmall.copyWith(letterSpacing: 3),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAiNote() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.smart_toy, color: AppColors.secondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI COACH NOTE',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.secondary, letterSpacing: 3),
                ),
                const SizedBox(height: 4),
                Text(
                  'Security is vital to your performance data. If you no longer have access to this email, please contact our biomechanics support team.',
                  style: AppTextStyles.bodySmall.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

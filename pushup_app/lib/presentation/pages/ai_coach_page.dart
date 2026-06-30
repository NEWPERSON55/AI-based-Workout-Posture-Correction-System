import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/animations/kinetic_animations.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../cubit/ai_coach_cubit.dart';
import '../cubit/ai_coach_state.dart';

class AiCoachPage extends StatelessWidget {
  const AiCoachPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AiCoachCubit, AiCoachState>(
      builder: (context, state) {
        if (state is! AiCoachLoaded) return const SizedBox();
        return Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: Responsive.contentMaxWidth(context),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      Responsive.horizontalPadding(context),
                      16,
                      Responsive.horizontalPadding(context),
                      8,
                    ),
                    child: Column(
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: 32),
                        ...state.messages.asMap().entries.map(
                          (entry) => FadeSlideIn(
                            delay: Duration(
                              milliseconds: 200 + entry.key * 150,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: entry.value.isUser
                                  ? _buildUserMessage(context, entry.value)
                                  : _buildAiMessage(context, entry.value),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _buildInputBar(context),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isTab = Responsive.isTablet(context);
    return FadeSlideIn(
      duration: const Duration(milliseconds: 800),
      child: Column(
        children: [
          PulseGlow(
            glowColor: AppColors.secondary,
            child: Container(
              width: isTab ? 96 : 80,
              height: isTab ? 96 : 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.secondary, AppColors.primary],
                ),
              ),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainer,
                ),
                child: Icon(
                  Icons.smart_toy,
                  size: isTab ? 48 : 40,
                  color: AppColors.secondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('AI Coach', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'STATUS: ACTIVE & LEARNING',
            style: AppTextStyles.labelSmall.copyWith(letterSpacing: 3),
          ),
        ],
      ),
    );
  }

  Widget _buildUserMessage(BuildContext context, ChatMessage msg) {
    final maxW = Responsive.isTablet(context) ? 420.0 : 300.0;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                border: Border(
                  right: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
              ),
              child: Text(msg.text, style: AppTextStyles.bodyLarge),
            ),
            const SizedBox(height: 4),
            Text(
              msg.time,
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 10,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiMessage(BuildContext context, ChatMessage msg) {
    final maxW = Responsive.isTablet(context) ? 480.0 : 320.0;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'SMART GYM AI',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.secondary,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow.withValues(alpha: 0.8),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Text(
                msg.text,
                style: AppTextStyles.bodyLarge.copyWith(height: 1.5),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _chip('Yes, show video', Icons.play_circle, true),
                _chip('Tell me more about stance', null, false),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              msg.time,
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 10,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, IconData? icon, bool isAccent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isAccent
            ? AppColors.secondary.withValues(alpha: 0.1)
            : AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(9999),
        border: isAccent
            ? Border.all(color: AppColors.secondary.withValues(alpha: 0.2))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: isAccent
                  ? AppColors.secondary
                  : AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: isAccent
                  ? AppColors.secondary
                  : AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppTextStyles.labelSmall),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: AppTextStyles.headlineSmall.copyWith(color: color),
              ),
              Icon(icon, color: color),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    final controller = TextEditingController();
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: Responsive.contentMaxWidth(context),
        ),
        child: Container(
          padding: EdgeInsets.only(
            left: 8,
            right: 8,
            top: 8,
            bottom: 8 + MediaQuery.of(context).padding.bottom + 20,
          ),
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: AppColors.onSurfaceVariant,
                ),
                onPressed: () {},
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(color: AppColors.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Ask your AI Coach...',
                    hintStyle: TextStyle(color: AppColors.outline),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.mic, color: AppColors.onSurfaceVariant),
                onPressed: () {},
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.send,
                    color: AppColors.onPrimary,
                    size: 18,
                  ),
                  onPressed: () {
                    context.read<AiCoachCubit>().sendMessage(controller.text);
                    controller.clear();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

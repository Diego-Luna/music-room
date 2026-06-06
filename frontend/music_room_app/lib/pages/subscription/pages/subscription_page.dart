import 'package:flutter/material.dart';
import 'package:music_room_app/core/theme/app_theme.dart';
import 'package:music_room_app/widgets/primary_button.dart';
import 'package:music_room_app/providers/subscription_provider.dart';
import 'package:music_room_app/models/subscription.dart';

/// VI.3 bonus — subscription screen.
/// Lists the Free/Premium offers (GET /subscription/plans), highlights the
/// user's current tier (GET /subscription/me) and lets them switch
/// (PUT /subscription/me). Owns its own provider, like [ProfilePage].
class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final SubscriptionProvider _subscription = SubscriptionProvider();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscription.load());
  }

  @override
  void dispose() {
    _subscription.dispose();
    super.dispose();
  }

  Future<void> _switchTo(SubscriptionPlan plan) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _subscription.switchTo(plan.tier);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'You are now on the ${plan.label} plan.'
              : (_subscription.error ?? 'Could not change your plan.'),
        ),
        backgroundColor: ok ? Colors.green : Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: ListenableBuilder(
        listenable: _subscription,
        builder: (context, _) {
          if (_subscription.isLoading && _subscription.plans.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_subscription.plans.isEmpty) {
            return _ErrorState(
              message: _subscription.error ?? 'Could not load the offers.',
              onRetry: _subscription.load,
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppDimens.lg),
            children: [
              Text(
                'Choose your plan',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: AppTypography.bold,
                ),
              ),
              const SizedBox(height: AppDimens.xs),
              Text(
                'Premium unlocks the Music Playlist Editor — create and host '
                'your own playlist rooms.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppDimens.lg),
              for (final plan in _subscription.plans)
                _PlanCard(
                  plan: plan,
                  isCurrent: plan.tier == _subscription.currentTier,
                  isBusy: _subscription.isSwitching,
                  onSelect: () => _switchTo(plan),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isCurrent;
  final bool isBusy;
  final VoidCallback onSelect;

  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.isBusy,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.lg),
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        border: Border.all(
          color: isCurrent ? accent : theme.dividerColor,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                plan.label,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: AppTypography.bold,
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Text(
                plan.isFree ? 'Free' : '€${plan.price}/mo',
                style: theme.textTheme.titleMedium?.copyWith(color: accent),
              ),
              const Spacer(),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.sm,
                    vertical: AppDimens.xs,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
                  ),
                  child: Text(
                    'Current',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDimens.md),
          for (final feature in plan.features)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check, size: AppDimens.lg, color: accent),
                  const SizedBox(width: AppDimens.sm),
                  Expanded(
                    child: Text(feature, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppDimens.md),
          if (isCurrent)
            Center(
              child: Text(
                'Your current plan',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            )
          else
            PrimaryButton(
              label: plan.tier.isPremium ? 'Upgrade to Premium' : 'Switch to Free',
              isLoading: isBusy,
              onPressed: isBusy ? null : onSelect,
            ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppDimens.lg),
            PrimaryButton(label: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

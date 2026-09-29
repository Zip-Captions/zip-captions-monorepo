import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zip_broadcast/src/auth/auth_provider_config.dart';
import 'package:zip_broadcast/src/l10n/zip_broadcast_localizations.dart';
import 'package:zip_core/zip_core.dart';

/// The Zip Broadcast sign-in view (S-15), matching Proto-10
/// (`zip-broadcast-sign-in.html`). Renders one card per [AuthState] variant;
/// the provider button list is driven entirely by
/// [zipBroadcastAuthProviderConfig] — nothing here is hardcoded to a
/// specific provider.
class AccountSection extends ConsumerWidget {
  /// Creates an [AccountSection].
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authNotifierProvider);
    final l10n = ZipBroadcastLocalizations.of(context)!;

    return switch (state) {
      SignedOutState() => _SignInCard(l10n: l10n),
      SigningInState(:final providerId) =>
        _SignInCard(l10n: l10n, signingInProviderId: providerId),
      SignedInState(:final userId) =>
        _SignedInCard(l10n: l10n, userId: userId),
      AuthFailedState(:final providerId) =>
        _AuthFailureCard(l10n: l10n, providerId: providerId),
    };
  }
}

class _SignInCard extends ConsumerWidget {
  const _SignInCard({required this.l10n, this.signingInProviderId});

  final ZipBroadcastLocalizations l10n;
  final String? signingInProviderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      key: const Key('sign-in-signed-out-card'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.podcasts, size: 40),
            const SizedBox(height: 12),
            Text(l10n.signInTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              l10n.signInCopy,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            for (final option in zipBroadcastAuthProviderConfig.providers)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _ProviderButton(
                  option: option,
                  isBusy: signingInProviderId == option.id,
                  isDisabled: signingInProviderId != null,
                  l10n: l10n,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProviderButton extends ConsumerWidget {
  const _ProviderButton({
    required this.option,
    required this.isBusy,
    required this.isDisabled,
    required this.l10n,
  });

  final AuthProviderOption option;
  final bool isBusy;
  final bool isDisabled;
  final ZipBroadcastLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        key: Key('sign-in-provider-${option.id}-button'),
        onPressed: isDisabled
            ? null
            : () =>
                ref.read(authNotifierProvider.notifier).signIn(option.id),
        child: isBusy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(l10n.signInContinueWith(option.displayLabel)),
      ),
    );
  }
}

class _SignedInCard extends ConsumerWidget {
  const _SignedInCard({required this.l10n, required this.userId});

  final ZipBroadcastLocalizations l10n;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      key: const Key('sign-in-signed-in-card'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.signInAccountTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(userId),
            ),
            Text(
              l10n.signInAccountStatus,
              key: const Key('sign-in-signed-in-status'),
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: Colors.green),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.signInAccountCopy,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('sign-in-sign-out-button'),
                onPressed: () =>
                    ref.read(authNotifierProvider.notifier).signOut(),
                child: Text(l10n.signInSignOut),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthFailureCard extends ConsumerWidget {
  const _AuthFailureCard({required this.l10n, required this.providerId});

  final ZipBroadcastLocalizations l10n;
  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      key: const Key('sign-in-auth-failure-card'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.podcasts, size: 40),
            const SizedBox(height: 12),
            Text(l10n.signInTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              l10n.signInCopy,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              key: const Key('sign-in-auth-failure-alert'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.signInFailureAlert,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('sign-in-retry-button'),
                onPressed: () =>
                    ref.read(authNotifierProvider.notifier).signIn(providerId),
                child: Text(l10n.signInRetry),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/subscription_tier.dart';
import '../../services/auth_service.dart';
import '../../services/document_scanner_service.dart';
import '../../services/entitlement_service.dart';
import '../../services/finance_service.dart';
import '../../services/custom_document_type_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/hero_widgets.dart';

/// Hero header of the Profile (Settings) tab — navy ink backdrop carrying the
/// user's identity: avatar initials, name, email, plan/sync badges, and the
/// sign-out action (it lives here because the floating bottom nav pill covers
/// the end of the scroll content).
class ProfileHeroHeader extends StatelessWidget {
  final String userName;

  /// Exact age derived from the DOB captured at signup; null hides the line
  /// (accounts created before DOB capture).
  final int? userAge;

  const ProfileHeroHeader({
    super.key,
    required this.userName,
    this.userAge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = AuthService.instance.userEmail;
    final isCloudSynced =
        SupabaseService.hasCredentials && AuthService.instance.isSignedIn;
    final signedIn = AuthService.instance.isSignedIn;
    final entitlements = EntitlementService.instance;
    final tier = entitlements.tier;
    final tierInfo = TierInfo.all[tier]!;
    final daysLeft = entitlements.daysUntilPlanExpiry();

    final initials = userName
        .trim()
        .split(' ')
        .where((e) => e.isNotEmpty)
        .map((e) => e[0])
        .take(2)
        .join('')
        .toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Settings',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (signedIn)
                HeroIconButton(
                  icon: Icons.logout_rounded,
                  tooltip: 'Sign out',
                  onTap: () => _signOut(context),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Avatar: white on the ink hero — quiet, premium, no glare.
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.18),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    initials.isEmpty ? 'U' : initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email ?? 'local@finavig.app',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.65),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (userAge != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Age $userAge',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.55),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Plan + sync status badges.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroPill(
                icon: Icons.workspace_premium_rounded,
                label: tierInfo.name,
              ),
              _HeroPill(
                icon: isCloudSynced
                    ? Icons.cloud_done_rounded
                    : Icons.storage_rounded,
                label: isCloudSynced ? 'Cloud synced' : 'Local only',
              ),
              if (daysLeft != null && !entitlements.isPlanExpired)
                _HeroPill(
                  icon: Icons.hourglass_top_rounded,
                  label: '$daysLeft day${daysLeft == 1 ? '' : 's'} left',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to see your documents.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await AuthService.instance.signOut();
    DocumentScannerService.instance.clearCache();
    FinanceService.instance.clearCache();
    CustomDocumentTypeService.instance.reset();
    EntitlementService.instance.reset();

    if (context.mounted) context.go('/login');
  }
}

/// Frosted pill in the hero (plan / sync status) — a quieter variant of the
/// hero action pills on Home.
class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

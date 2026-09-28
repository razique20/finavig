import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/document_collection.dart';
import 'profile_sections.dart';

/// Account card of the Profile (Settings) screen — the editable identity
/// details (role, phone) plus the active-collection shortcut. Identity
/// itself lives in the hero; the card carries the editable details.
class ProfileAccountCard extends StatelessWidget {
  final String userRole;
  final String userPhone;
  final List<DocumentCollection> collections;
  final String activeId;
  final VoidCallback onEditProfile;

  const ProfileAccountCard({
    super.key,
    required this.userRole,
    required this.userPhone,
    required this.collections,
    required this.activeId,
    required this.onEditProfile,
  });

  String get _activeCollectionName {
    for (final c in collections) {
      if (c.id == activeId) return c.name;
    }
    return 'Personal';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: profileTileBg(Theme.of(context)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            ProfileSettingsTile(
              icon: Icons.badge_outlined,
              title: userRole,
              subtitle: 'Role / designation',
              trailing: const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colors.grey,
              ),
              onTap: onEditProfile,
            ),
            if (userPhone.trim().isNotEmpty)
              ProfileSettingsTile(
                icon: Icons.phone_iphone_rounded,
                title: userPhone,
                subtitle: 'Phone number',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Colors.grey,
                ),
                onTap: onEditProfile,
              ),
            ProfileSettingsTile(
              icon: Icons.folder_special_rounded,
              title: '$_activeCollectionName is active',
              subtitle: 'Current collection',
              trailing: const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colors.grey,
              ),
              onTap: () => context.go('/documents'),
            ),
          ],
        ),
      ),
    );
  }
}

/// AI summary section — Gemini key configuration. The key stays on-device
/// and only gates the LLM polish pass; the summary works without it.
class ProfileAiSection extends StatelessWidget {
  final String geminiKey;
  final VoidCallback onEditGeminiKey;

  const ProfileAiSection({
    super.key,
    required this.geminiKey,
    required this.onEditGeminiKey,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileSectionGroup(
      title: 'AI Summary',
      children: [
        ProfileSettingsTile(
          icon: Icons.auto_awesome_rounded,
          iconColor: Colors.deepPurple,
          title: 'AI Executive Summary',
          subtitle: geminiKey.isEmpty
              ? 'Uses built-in templates — add a Gemini key for AI polish'
              : 'Gemini key configured — summaries are AI-polished',
          trailing: const Icon(
            Icons.edit_rounded,
            size: 20,
            color: Colors.grey,
          ),
          onTap: onEditGeminiKey,
        ),
      ],
    );
  }
}

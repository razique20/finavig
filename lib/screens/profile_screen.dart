import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/document_collection.dart';
import '../services/auth_service.dart';
import '../services/collection_service.dart';
import '../services/document_scanner_service.dart';
import '../services/entitlement_service.dart';
import '../services/finance_service.dart';
import '../services/tab_scroll_registry.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'profile/app_lock_section.dart';
import 'profile/profile_account_section.dart';
import 'profile/profile_appearance_section.dart';
import 'profile/profile_backup_nudge.dart';
import 'profile/profile_collections_section.dart';
import 'profile/profile_hero.dart';
import 'profile/profile_sheets.dart';
import 'profile/profile_sections.dart';
import 'profile/profile_subscription_section.dart';

/// Profile tab — Settings, redesigned to the visual language of the Home and
/// Documents tabs: a navy hero header over a rounded content sheet.
///
/// The heavy lifting lives in `lib/screens/profile/` modules so each section
/// rebuilds independently:
/// 1. Hero (identity, badges, sign out) — `profile_hero.dart`
/// 2. Account card (role, phone, active collection) — `profile_account_section.dart`
/// 3. Subscription (plan, meters, upgrade) — `profile_subscription_section.dart`
/// 4. Collections — `profile_collections_section.dart`
/// 5. Appearance (theme) + Preferences (alerts link) — `profile_appearance_section.dart`
/// 6. AI summary key — `profile_account_section.dart`
/// 7. Help & support — `profile_sheets.dart`
///
/// Every control saves immediately — there is no Save button.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Root scrollable of this tab — registered so a bottom-nav tap scrolls
  // the tab back to the top (see TabScrollRegistry).
  final ScrollController _scrollController = ScrollController();

  List<DocumentCollection> _collections = [];
  String _activeId = DocumentCollection.personalId;
  bool _loading = true;
  String _userName = 'Unknown User';
  String _userRole = 'Document Admin';
  String _userPhone = '';
  int? _userAge;
  String _geminiKey = '';

  @override
  void initState() {
    super.initState();
    TabScrollRegistry.register(3, _scrollController);
    final service = DocumentCollectionService.instance;
    if (service.collections.isNotEmpty) {
      _collections = service.collections;
      _activeId = service.activeCollectionId;
      _loading = false;
    }
    _loadCollections();
    _loadSettings();
    DocumentCollectionService.instance.addListener(_onCollectionsChanged);
  }

  @override
  void dispose() {
    TabScrollRegistry.unregister(3, _scrollController);
    _scrollController.dispose();
    DocumentCollectionService.instance.removeListener(_onCollectionsChanged);
    super.dispose();
  }

  void _onCollectionsChanged() {
    if (!mounted) return;
    // Schedule outside the notification in case the service notifies while
    // the widget tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCollections();
    });
  }

  Future<void> _loadCollections() async {
    final service = DocumentCollectionService.instance;
    await service.getActiveCollection();
    if (mounted) {
      setState(() {
        _collections = service.collections;
        _activeId = service.activeCollectionId;
        _loading = false;
      });
    }
  }

  Future<void> _loadSettings() async {
    // Re-read the user's tier so the subscription card is current (the admin
    // may have processed an upgrade since this session started).
    await EntitlementService.instance.refresh();

    final prefs = await SharedPreferences.getInstance();
    final email = AuthService.instance.userEmail;
    final derivedName = email != null && email.contains('@')
        ? email
              .split('@')
              .first
              .replaceAll('.', ' ')
              .replaceAll('_', ' ')
              .toUpperCase()
        : 'Unknown User';

    if (!mounted) return;
    setState(() {
      _userName = derivedName;
      _userRole = prefs.getString('userRole') ?? 'Document Admin';
      _userPhone = prefs.getString('userPhone') ?? '';
      _userAge = _ageFromDob(prefs.getString('userDateOfBirth'));
      _geminiKey = prefs.getString('gemini.apiKey.v1') ?? '';
    });
  }

  /// Exact age in years from the ISO DOB captured at signup (null when the
  /// account predates DOB capture or the stored value is unusable).
  static int? _ageFromDob(String? isoDob) {
    final dob = DateTime.tryParse(isoDob ?? '');
    if (dob == null) return null;
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age >= 0 && age < 150 ? age : null;
  }

  /// Persists the profile details edited in the bottom sheet.
  Future<void> _saveProfileDetails() async {
    final prefs = await SharedPreferences.getInstance();
    // userName is always derived from the sign-in email — not saved locally.
    await prefs.setString('userRole', _userRole);
    await prefs.setString('userPhone', _userPhone);
  }

  Future<void> _editProfile() async {
    await showProfileEditSheet(
      context,
      initialRole: _userRole,
      initialPhone: _userPhone,
      onSaved: (role, phone) {
        if (!mounted) return;
        setState(() {
          _userRole = role;
          _userPhone = phone;
        });
        _saveProfileDetails();
      },
    );
  }

  /// Prompt for / clear the Gemini API key used by the AI executive summary.
  Future<void> _editGeminiKey() async {
    await showGeminiKeySheet(
      context,
      currentKey: _geminiKey,
      onSaved: (key) {
        if (!mounted) return;
        setState(() => _geminiKey = key);
      },
    );
  }

  // ------------------------------------------------------------------
  // Collection management
  // ------------------------------------------------------------------

  Future<void> _createCollection() async {
    // Track 1 gate: company workspaces are tiered — Free has none, Plus one,
    // Business unlimited.
    if (!await enforceCompanyCollectionLimit(context)) return;
    if (!mounted) return;

    final res = await showCreateCollectionDialog(context);
    if (res == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final created =
          await DocumentCollectionService.instance.createCollection(
        res.name,
        countryCode: res.countryCode,
      );
      await DocumentCollectionService.instance.setActive(created.id);
      await _loadCollections();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Collection "${res.name}" created')),
        );
      }
    } catch (e) {
      if (mounted) _showError('Could not create collection: $e');
    }
  }

  Future<void> _renameCollection(DocumentCollection collection) async {
    if (EntitlementService.instance.isCollectionLocked(collection)) {
      await showUpgradeDialog(
        context,
        EntitlementService.instance.requiredFeatureForCollection(collection),
      );
      return;
    }

    final name = await showRenameCollectionDialog(context, collection);
    if (name == null || !mounted) return;

    try {
      await DocumentCollectionService.instance.renameCollection(
        collection.id,
        name,
      );
      await _loadCollections();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Renamed to "$name"')));
      }
    } catch (e) {
      if (mounted) _showError('Could not rename collection: $e');
    }
  }

  Future<void> _deleteCollection(DocumentCollection collection) async {
    final confirmed = await showDeleteCollectionDialog(context, collection);
    if (!confirmed || !mounted) return;

    try {
      await DocumentCollectionService.instance.deleteCollection(collection.id);
      await _loadCollections();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${collection.name}" deleted')),
        );
      }
    } catch (e) {
      if (mounted) _showError('Could not delete collection: $e');
    }
  }

  Future<void> _switchTo(DocumentCollection collection) async {
    if (EntitlementService.instance.isCollectionLocked(collection)) {
      await showUpgradeDialog(
        context,
        EntitlementService.instance.requiredFeatureForCollection(collection),
      );
      return;
    }

    await DocumentCollectionService.instance.setActive(collection.id);
    await DocumentScannerService.instance.refresh();
    // Same as the Home switcher: re-scope finance data so the Money tab
    // follows the newly active collection.
    await FinanceService.instance.refresh();
    await _loadCollections();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Switched to "${collection.name}"')),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // Ink backdrop behind the hero; the content sheet covers the rest.
      // Same backdrop as Home/Documents.
      backgroundColor: isDark ? FinavigColors.obsidian : FinavigColors.ink,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: theme.colorScheme.secondary,
          onRefresh: _loadSettings,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: ProfileHeroHeader(
                  userName: _userName,
                  userAge: _userAge,
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: _loading
                      ? SizedBox(
                          height: 320,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            ProfileAccountCard(
                              userRole: _userRole,
                              userPhone: _userPhone,
                              collections: _collections,
                              activeId: _activeId,
                              onEditProfile: _editProfile,
                            ),
                            const SizedBox(height: 16),
                            // Data-safety nudge: scans are device-local
                            // until Storage sync ships — point at exports.
                            const ProfileBackupNudge(),
                            const SizedBox(height: 16),
                            ProfileSubscriptionSection(
                              collections: _collections,
                            ),
                            const SizedBox(height: 16),
                            ProfileCollectionsSection(
                              collections: _collections,
                              activeId: _activeId,
                              onCreate: _createCollection,
                              onRename: _renameCollection,
                              onDelete: _deleteCollection,
                              onSwitch: _switchTo,
                            ),
                            const SizedBox(height: 16),
                            const ProfileAppearanceSection(),
                            const SizedBox(height: 16),
                            const ProfilePreferencesSection(),
                            const SizedBox(height: 16),
                            const ProfileSecuritySection(),
                            const SizedBox(height: 16),
                            ProfileAiSection(
                              geminiKey: _geminiKey,
                              onEditGeminiKey: _editGeminiKey,
                            ),
                            const SizedBox(height: 16),
                            ProfileSectionGroup(
                              title: 'Help & Support',
                              children: [
                                ProfileSettingsTile(
                                  icon: Icons.quiz_rounded,
                                  iconColor: const Color(0xFFD97706),
                                  title: 'Frequently Asked Questions (FAQ)',
                                  subtitle:
                                      'Instant answers for documents, money, AI & account',
                                  trailing: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: FinavigColors.adaptiveIcon(context, Colors.grey),
                                  ),
                                  onTap: () => showFaqSheet(
                                    context,
                                    onOpenSupportTicket: () =>
                                        showProfileSupportSheet(context),
                                  ),
                                ),
                                ProfileSettingsTile(
                                  icon: Icons.auto_stories_rounded,
                                  iconColor: Colors.teal,
                                  title: 'App Guide',
                                  subtitle:
                                      'Interactive walkthrough of all Finavig features',
                                  trailing: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: FinavigColors.adaptiveIcon(context, Colors.grey),
                                  ),
                                  onTap: () => showAppGuideDialog(context),
                                ),
                                ProfileSettingsTile(
                                  icon: Icons.add_comment_rounded,
                                  iconColor: Colors.teal,
                                  title: 'Submit a Request',
                                  subtitle:
                                      'Request a tracking option, report a bug, or get help',
                                  trailing: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: FinavigColors.adaptiveIcon(context, Colors.grey),
                                  ),
                                  onTap: () => showProfileSupportSheet(context),
                                ),
                                ProfileSettingsTile(
                                  icon: Icons.history_rounded,
                                  iconColor: Colors.blueGrey,
                                  title: 'My Requests',
                                  subtitle:
                                      'View status of your previous submissions',
                                  trailing: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: FinavigColors.adaptiveIcon(context, Colors.grey),
                                  ),
                                  onTap: () =>
                                      showProfileRequestHistorySheet(context),
                                ),
                                ProfileSettingsTile(
                                  icon: Icons.delete_forever_rounded,
                                  iconColor: Colors.red,
                                  title: 'Delete Account',
                                  subtitle:
                                      'Permanently erase your account and all data',
                                  trailing: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: FinavigColors.adaptiveIcon(context, Colors.grey),
                                  ),
                                  onTap: () async {
                                    final signedIn =
                                        AuthService.instance.isSignedIn;
                                    if (!signedIn) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Sign in to delete your account.'),
                                        ),
                                      );
                                      return;
                                    }
                                    await showDeleteAccountSheet(context);
                                  },
                                ),
                              ],
                            ),
                            // Keep the last card scrollable clear of the
                            // floating nav pill (height + margins ≈ 80).
                            SizedBox(
                              height:
                                  8 + MediaQuery.of(context).padding.bottom + 80,
                            ),
                          ],
                        ),
                ),
              ),
              // Sheet filler: extends the sheet across the rest of the
              // viewport when content is short, and into overscroll —
              // the navy backdrop never peeks out below the content,
              // behind the floating nav pill.
              SliverFillRemaining(
                hasScrollBody: false,
                fillOverscroll: true,
                child: ColoredBox(color: theme.colorScheme.surface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

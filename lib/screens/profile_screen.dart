import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/document_collection.dart';
import '../models/subscription_tier.dart';
import '../services/app_lock_service.dart';
import '../services/auth_service.dart';
import '../services/collection_service.dart';
import '../services/document_scanner_service.dart';
import '../services/entitlement_service.dart';
import '../services/finance_service.dart';
import '../services/tab_scroll_registry.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'profile/app_lock_section.dart';
import 'profile/profile_appearance_section.dart';
import 'profile/profile_backup_nudge.dart';
import 'profile/profile_collections_section.dart';
import 'profile/profile_hero.dart';
import 'profile/profile_sheets.dart';
import 'profile/profile_sections.dart';
import 'profile/profile_subscription_section.dart';

/// Profile tab — Settings, laid out as a clean, airy list: a centred page
/// title, a circular avatar with the user's name/email, then full-width white
/// rows. The detailed controls (appearance, subscription, collections,
/// security, AI key) open in bottom sheets so the main surface stays flat.
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
        _loading = false;
      });
    }
  }

  Future<void> _loadSettings() async {
    // Re-read the user's tier so the subscription row is current (the admin
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

  /// Opens a titled bottom sheet wrapping [child] — the shared chrome for the
  /// detailed settings surfaces (appearance, subscription, collections).
  void _showSheet({required String title, required Widget child}) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 4, bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    title,
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAppearance() => _showSheet(
        title: 'Customize my experience',
        child: const ProfileAppearanceSection(),
      );

  void _openSubscription() => _showSheet(
        title: 'Manage subscription',
        child: ProfileSubscriptionSection(collections: _collections),
      );

  void _openCollections() {
    // Live off the service so rename / delete / switch reflect immediately
    // inside the sheet (the sheet route is not rebuilt by this screen's
    // setState).
    final service = DocumentCollectionService.instance;
    _showSheet(
      title: 'My Collections',
      child: ListenableBuilder(
        listenable: service,
        builder: (ctx, _) => ProfileCollectionsSection(
          collections: service.collections,
          activeId: service.activeCollectionId,
          onCreate: _createCollection,
          onRename: _renameCollection,
          onDelete: _deleteCollection,
          onSwitch: _switchTo,
        ),
      ),
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
      messenger.showSnackBar(
        SnackBar(content: Text('Collection "${res.name}" created')),
      );
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

  Future<void> _deleteAccount() async {
    if (!AuthService.instance.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to delete your account.')),
      );
      return;
    }
    await showDeleteAccountSheet(context);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  /// The flat settings list. Listens to the theme + app-lock services so the
  /// "current value" columns stay live.
  Widget _buildList() {
    final tierInfo = TierInfo.all[EntitlementService.instance.tier]!;
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeService.instance,
        AppLockService.instance,
      ]),
      builder: (context, _) {
        return ProfileList(
          children: [
            ProfileListRow(
              icon: Icons.person_outline_rounded,
              title: 'Manage profile',
              value: _userRole,
              onTap: _editProfile,
            ),
            ProfileListRow(
              icon: Icons.tune_rounded,
              title: 'Customize my experience',
              onTap: _openAppearance,
            ),
            ProfileListRow(
              icon: Icons.notifications_none_rounded,
              title: 'Manage notifications',
              onTap: () => context.push('/alerts-reminders'),
            ),
            ProfileListRow(
              icon: Icons.folder_outlined,
              title: 'My Collections',
              value: '${_collections.length}',
              onTap: _openCollections,
            ),
            ProfileListRow(
              icon: Icons.workspace_premium_outlined,
              title: 'Manage subscription',
              value: tierInfo.name,
              onTap: _openSubscription,
            ),
            ProfileListRow(
              icon: Icons.lock_outline_rounded,
              title: 'Security & App Lock',
              value: AppLockService.instance.isEnabled ? 'On' : 'Off',
              onTap: () => showAppLockSettingsSheet(context),
            ),
            ProfileListRow(
              icon: Icons.auto_awesome_outlined,
              title: 'AI Summary',
              value: _geminiKey.isEmpty ? 'Shared key' : 'Custom key',
              onTap: _editGeminiKey,
            ),
            ProfileListRow(
              icon: Icons.help_outline_rounded,
              title: 'FAQ',
              onTap: () => showFaqSheet(
                context,
                onOpenSupportTicket: () => showProfileSupportSheet(context),
              ),
            ),
            ProfileListRow(
              icon: Icons.menu_book_outlined,
              title: 'App guide',
              onTap: () => showAppGuideDialog(context),
            ),
            ProfileListRow(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Submit a request',
              onTap: () => showProfileSupportSheet(context),
            ),
            ProfileListRow(
              icon: Icons.history_rounded,
              title: 'My requests',
              onTap: () => showProfileRequestHistorySheet(context),
            ),
            ProfileListRow(
              icon: Icons.battery_saver_outlined,
              title: 'Ensure reminders work',
              onTap: openBatteryGuidance,
            ),
            ProfileListRow(
              icon: Icons.download_outlined,
              title: 'Download my data',
              onTap: () => exportUserData(context),
            ),
            ProfileListRow(
              icon: Icons.delete_outline_rounded,
              title: 'Delete account',
              danger: true,
              onTap: _deleteAccount,
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Canvas + wash resolve through the theme transition factor so they
    // cross-fade with the theme animation instead of snapping.
    final fade = FinavigTransition.of(context);
    final canvas = fade.color(FinavigColors.snowWhite, FinavigColors.obsidian);
    final wash = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        fade.color(FinavigColors.accentSoft, const Color(0xFF151830)),
        canvas,
      ],
      stops: const [0.0, 0.55],
    );

    return Scaffold(
      backgroundColor: canvas,
      body: Container(
        decoration: BoxDecoration(gradient: wash),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: theme.colorScheme.secondary,
            onRefresh: _loadSettings,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProfileSettingsHeader(
                        userName: _userName,
                        userAge: _userAge,
                      ),
                      const SizedBox(height: 18),
                      // Data-safety nudge: scans are device-local until
                      // Storage sync ships — point at exports.
                      const ProfileBackupNudge(),
                      const SizedBox(height: 16),
                      if (_loading)
                        SizedBox(
                          height: 240,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        )
                      else ...[
                        _buildList(),
                        // Keep the last row clear of the floating nav pill
                        // (height + margins ≈ 80).
                        SizedBox(
                          height:
                              16 + MediaQuery.of(context).padding.bottom + 80,
                        ),
                      ],
                    ],
                  ),
                ),
                // Canvas filler: extends the background across the rest of
                // the viewport and into overscroll behind the nav pill.
                SliverFillRemaining(
                  hasScrollBody: false,
                  fillOverscroll: true,
                  child: ColoredBox(color: canvas),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

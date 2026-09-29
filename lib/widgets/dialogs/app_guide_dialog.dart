import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_guide_content.dart';
import '../../theme/app_theme.dart';

/// Show the comprehensive Finavig App Guide modal.
Future<void> showAppGuideDialog(
  BuildContext context, {
  int initialPage = 0,
}) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    builder: (ctx) => AppGuideDialog(initialPage: initialPage),
  );
}

/// The comprehensive, interactive user guide introducing everything in
/// Finavig. All copy and chapter structure lives in
/// `lib/config/app_guide_content.dart` — this file is presentation only.
class AppGuideDialog extends StatefulWidget {
  final int initialPage;

  const AppGuideDialog({super.key, this.initialPage = 0});

  @override
  State<AppGuideDialog> createState() => _AppGuideDialogState();
}

class _AppGuideDialogState extends State<AppGuideDialog> {
  late final PageController _pageController;
  late int _currentPage;

  static const List<GuideChapter> _chapters = guideChapters;
  int get _totalChapters => _chapters.length;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(0, _totalChapters - 1);
    _pageController = PageController(initialPage: _currentPage);
    _markGuideAsSeen();
  }

  Future<void> _markGuideAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenAppGuide', true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 380 || size.height < 650;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: isCompact ? size.height * 0.95 : 680,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? FinavigColors.slate : FinavigColors.cloud,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.6 : 0.2),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              // ── Header Bar ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B).withOpacity(0.5)
                      : FinavigColors.cloud.withOpacity(0.6),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? FinavigColors.slate.withOpacity(0.5)
                          : FinavigColors.mist,
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: FinavigColors.navyPrimary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.explore_rounded,
                            color: FinavigColors.navyPrimary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Finavig App Guide',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              Text(
                                'Chapter ${_currentPage + 1} of $_totalChapters',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          tooltip: 'Close guide',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Quick Chapter Selector Pills
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i < _chapters.length; i++) ...[
                            if (i > 0) const SizedBox(width: 6),
                            _chapterPill(
                              i,
                              _chapters[i].pillLabel,
                              _chapters[i].pillIcon,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Page View Content ────────────────────────────────────────
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  children: [
                    for (final chapter in _chapters)
                      _buildChapterSlide(chapter, isDark, theme),
                  ],
                ),
              ),

              // ── Bottom Navigation Controls ───────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? FinavigColors.slate.withOpacity(0.4)
                          : FinavigColors.mist,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Dot indicators
                    Row(
                      children: List.generate(
                        _totalChapters,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: index == _currentPage ? 22 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: index == _currentPage
                                ? FinavigColors.navyPrimary
                                : (isDark
                                    ? FinavigColors.slateLight
                                    : FinavigColors.fog),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_currentPage > 0) ...[
                      TextButton(
                        onPressed: () => _goToPage(_currentPage - 1),
                        child: const Text('Back'),
                      ),
                      const SizedBox(width: 6),
                    ],
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: FinavigColors.navyPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        if (_currentPage < _totalChapters - 1) {
                          _goToPage(_currentPage + 1);
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Text(
                        _currentPage < _totalChapters - 1
                            ? 'Next →'
                            : 'Start Exploring',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chapterPill(int index, String label, IconData icon) {
    final active = _currentPage == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => _goToPage(index),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? FinavigColors.navyPrimary
              : (isDark
                  ? FinavigColors.slate.withOpacity(0.6)
                  : FinavigColors.cloud),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: active
                  ? Colors.white
                  : (isDark
                      ? FinavigColors.textSecondary
                      : FinavigColors.textMuted),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                color: active
                    ? Colors.white
                    : (isDark
                        ? FinavigColors.textSecondary
                        : FinavigColors.textSecondaryLight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Generic chapter slide — renders the chapter's ordered blocks
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildChapterSlide(
    GuideChapter chapter,
    bool isDark,
    ThemeData theme,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chapter.title != null) ...[
            Row(
              children: [
                Icon(
                  chapter.pillIcon,
                  color: _chapterAccent(chapter),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    chapter.title!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          if (chapter.subtitle != null) ...[
            Text(
              chapter.subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
          ],
          for (final block in chapter.blocks) _buildBlock(block, isDark, theme),
        ],
      ),
    );
  }

  Color _chapterAccent(GuideChapter chapter) {
    // Match each chapter's accent to its showcase block content.
    for (final block in chapter.blocks) {
      if (block is GuideFeatureRowBlock) return block.color;
      if (block is GuideCtaBlock) return block.color;
    }
    return FinavigColors.navyPrimary;
  }

  Widget _buildBlock(GuideBlock block, bool isDark, ThemeData theme) {
    switch (block) {
      case final GuideBannerBlock b:
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: _banner(b),
        );
      case final GuideSectionTitleBlock b:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            b.text,
            style:
                theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      case final GuideDocumentShowcaseBlock b:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _documentShowcase(b, isDark, theme),
        );
      case final GuideBudgetShowcaseBlock b:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _budgetShowcase(b, isDark),
        );
      case final GuideWorkspacesShowcaseBlock b:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _workspacesShowcase(b, isDark),
        );
      case final GuideQuoteShowcaseBlock b:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _quoteShowcase(b, isDark),
        );
      case final GuideFeatureRowBlock b:
        return _featureRow(b, isDark);
      case final GuideBulletBlock b:
        return _featureBullet(b, isDark);
      case final GuideCtaBlock b:
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: SizedBox(
            width: double.infinity,
            child: b.filled
                ? FilledButton.icon(
                    onPressed: () => _openRoute(b),
                    icon: Icon(b.icon, size: 16),
                    label: Text(b.label),
                    style: FilledButton.styleFrom(
                      backgroundColor: FinavigColors.navyPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: () => _openRoute(b),
                    icon: Icon(b.icon, size: 16),
                    label: Text(b.label),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: b.color),
                      foregroundColor:
                          isDark ? b.color : _darkenForLightMode(b),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
          ),
        );
    }
  }

  /// CTA text color on light mode for the Money chapter used dark-green.
  Color _darkenForLightMode(GuideCtaBlock b) {
    if (b.color == FinavigColors.emerald) return const Color(0xFF065F46);
    return b.color;
  }

  void _openRoute(GuideCtaBlock block) {
    Navigator.pop(context);
    if (block.usePush) {
      context.push(block.route);
    } else {
      context.go(block.route);
    }
  }

  Widget _banner(GuideBannerBlock b) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [FinavigColors.navyPrimary, FinavigColors.navyPrimaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: FinavigColors.cyanSecondary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  b.icon,
                  color: FinavigColors.cyanSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  b.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            b.subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _documentShowcase(
    GuideDocumentShowcaseBlock b,
    bool isDark,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? FinavigColors.slate.withOpacity(0.5) : FinavigColors.cloud,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? FinavigColors.slateLight : FinavigColors.mist,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: FinavigColors.navyPrimary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(b.icon, color: FinavigColors.navyPrimary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  b.subtitle,
                  style:
                      TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: FinavigColors.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              b.badge,
              style: const TextStyle(
                color: FinavigColors.warning,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _budgetShowcase(GuideBudgetShowcaseBlock b, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? FinavigColors.slate.withOpacity(0.5) : FinavigColors.cloud,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? FinavigColors.slateLight : FinavigColors.mist,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(b.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              Text(
                b.percentLabel,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isDark
                      ? FinavigColors.cyanSecondary
                      : FinavigColors.navyPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: b.fractionUsed,
              minHeight: 8,
              backgroundColor: isDark ? Colors.black26 : Colors.black12,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(FinavigColors.emerald),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(b.spentLabel, style: const TextStyle(fontSize: 11)),
              Text(b.budgetLabel, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _workspacesShowcase(GuideWorkspacesShowcaseBlock b, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? FinavigColors.slate.withOpacity(0.5) : FinavigColors.cloud,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? FinavigColors.slateLight : FinavigColors.mist,
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < b.items.length; i++) ...[
            if (i > 0) const Divider(height: 16),
            _workspaceItem(b.items[i], isDark),
          ],
        ],
      ),
    );
  }

  Widget _quoteShowcase(GuideQuoteShowcaseBlock b, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF2D2305), const Color(0xFF1E1700)]
              : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt_rounded, color: Colors.amber, size: 18),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'AI Executive Summary & Budget Simulator',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            b.quote,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              fontStyle: FontStyle.italic,
              color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureRow(GuideFeatureRowBlock b, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: b.color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(b.icon, color: b.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  b.description,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: isDark
                        ? FinavigColors.textSecondary
                        : FinavigColors.textMutedLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureBullet(GuideBulletBlock b, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: FinavigColors.emerald,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: isDark
                      ? FinavigColors.textPrimary
                      : FinavigColors.textPrimaryLight,
                ),
                children: [
                  TextSpan(
                    text: '${b.title}: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: b.description,
                    style: TextStyle(
                      color: isDark
                          ? FinavigColors.textSecondary
                          : FinavigColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workspaceItem(GuideWorkspaceItem item, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: FinavigColors.navyPrimary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(item.icon, size: 16, color: FinavigColors.navyPrimary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12.5)),
              Text(item.subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? FinavigColors.slate : FinavigColors.mist,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(item.country,
              style:
                  const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Static App Guide content, extracted from `app_guide_dialog.dart` so the
/// widget file carries only presentation (layout, chrome, page controls).
/// Edit copy here — no widget code required.
///
/// A chapter is a plain data object; the dialog renders each block type
/// generically. Blocks appear in list order.

/// One visual block inside a guide chapter slide.
sealed class GuideBlock {
  const GuideBlock();
}

/// Hero banner (overview chapter) — navy gradient, icon, title, subtitle.
class GuideBannerBlock extends GuideBlock {
  final IconData icon;
  final String title;
  final String subtitle;

  const GuideBannerBlock({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

/// Plain section heading (e.g. "The Four Pillars of Finavig").
class GuideSectionTitleBlock extends GuideBlock {
  final String text;

  const GuideSectionTitleBlock(this.text);
}

/// Mock document card shown in the Documents chapter.
class GuideDocumentShowcaseBlock extends GuideBlock {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;

  const GuideDocumentShowcaseBlock({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
  });
}

/// Mock budget gauge shown in the Money chapter.
class GuideBudgetShowcaseBlock extends GuideBlock {
  final String title;
  final double fractionUsed;
  final String percentLabel;
  final String spentLabel;
  final String budgetLabel;

  const GuideBudgetShowcaseBlock({
    required this.title,
    required this.fractionUsed,
    required this.percentLabel,
    required this.spentLabel,
    required this.budgetLabel,
  });
}

/// Mock workspace switcher shown in the Workspaces chapter.
class GuideWorkspacesShowcaseBlock extends GuideBlock {
  final List<GuideWorkspaceItem> items;

  const GuideWorkspacesShowcaseBlock({required this.items});
}

class GuideWorkspaceItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String country;

  const GuideWorkspaceItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.country,
  });
}

/// Mock AI summary quote card shown in the AI chapter.
class GuideQuoteShowcaseBlock extends GuideBlock {
  final String header;
  final String quote;

  const GuideQuoteShowcaseBlock({required this.header, required this.quote});
}

/// Icon + title + description row (the "Four Pillars" entries).
class GuideFeatureRowBlock extends GuideBlock {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const GuideFeatureRowBlock({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}

/// Check-marked bullet with bold lead-in ("Smart OCR Scan: …").
class GuideBulletBlock extends GuideBlock {
  final String title;
  final String description;

  const GuideBulletBlock({required this.title, required this.description});
}

/// Full-width call-to-action button at the bottom of a chapter. Pops the
/// guide and navigates to [route] (push when [usePush], otherwise go).
class GuideCtaBlock extends GuideBlock {
  final String label;
  final IconData icon;
  final String route;
  final bool usePush;
  final bool filled;
  final Color color;

  const GuideCtaBlock({
    required this.label,
    required this.icon,
    required this.route,
    required this.usePush,
    required this.color,
    this.filled = false,
  });
}

/// One guide chapter: pill label + slide header + ordered content blocks.
class GuideChapter {
  final String pillLabel;
  final IconData pillIcon;
  final String? title;
  final String? subtitle;
  final List<GuideBlock> blocks;

  const GuideChapter({
    required this.pillLabel,
    required this.pillIcon,
    required this.blocks,
    this.title,
    this.subtitle,
  });
}

/// The five guide chapters, in page order.
const List<GuideChapter> guideChapters = [
  GuideChapter(
    pillLabel: 'Overview',
    pillIcon: Icons.auto_awesome_rounded,
    blocks: [
      GuideBannerBlock(
        icon: Icons.rocket_launch_rounded,
        title: 'Welcome to FV',
        subtitle:
            'Your unified command center for expiry tracking, financial budgets, multi-company workspaces, and AI intelligence.',
      ),
      GuideSectionTitleBlock('The Four Pillars of FV'),
      GuideFeatureRowBlock(
        icon: Icons.description_rounded,
        color: FinavigColors.cyanSecondary,
        title: '1. Document & Expiry Tracking',
        description:
            'OCR scan IDs, Passports, Visas, Trade Licenses, Ejari & get 90/60/30/7-day alerts.',
      ),
      GuideFeatureRowBlock(
        icon: Icons.account_balance_wallet_rounded,
        color: FinavigColors.emerald,
        title: '2. Money, Budgets & Cash Flow',
        description:
            'Track income/expenses in GCC currencies, set category limits & forecast 90-day cash flow.',
      ),
      GuideFeatureRowBlock(
        icon: Icons.business_center_rounded,
        color: Colors.purpleAccent,
        title: '3. Workspaces & Collections',
        description:
            'Keep personal files completely separate from multiple company or client workspaces.',
      ),
      GuideFeatureRowBlock(
        icon: Icons.psychology_rounded,
        color: Colors.amber,
        title: '4. AI Executive Summaries',
        description:
            'Groq & Gemini AI analyze your financial health and build realistic savings plans.',
      ),
    ],
  ),
  GuideChapter(
    pillLabel: 'Documents',
    pillIcon: Icons.description_rounded,
    title: 'Document & Expiry Intelligence',
    subtitle:
        'Never get caught by surprise fines or lapsed licenses in the UAE & GCC.',
    blocks: [
      GuideDocumentShowcaseBlock(
        icon: Icons.badge_outlined,
        title: 'Emirates ID — Mohammed R.',
        subtitle: 'Authority: ICP UAE • Fee: 370 AED',
        badge: '18 Days Left',
      ),
      GuideBulletBlock(
        title: 'Smart OCR Scan',
        description:
            'Upload images or PDFs — AI extracts expiry date, document number, and issuing authority automatically.',
      ),
      GuideBulletBlock(
        title: 'GCC Authority Catalog',
        description:
            'Auto-matches DED, GDRFA, MoHRE, ICP, RTA, DHA, and municipal agencies.',
      ),
      GuideBulletBlock(
        title: 'Escalation Reminders',
        description:
            'Automated reminders 90, 60, 30, and 7 days prior to expiry so you renew on time.',
      ),
      GuideCtaBlock(
        label: 'Try Adding or Scanning a Document',
        icon: Icons.add_photo_alternate_rounded,
        route: '/scan',
        usePush: true,
        color: FinavigColors.navyPrimary,
      ),
    ],
  ),
  GuideChapter(
    pillLabel: 'Money',
    pillIcon: Icons.account_balance_wallet_rounded,
    title: 'Money, Budgets & Cash Flow',
    subtitle:
        'Keep your personal & business cash flow healthy and predictable.',
    blocks: [
      GuideBudgetShowcaseBlock(
        title: 'Office & Rent Budget',
        fractionUsed: 0.65,
        percentLabel: '65% used',
        spentLabel: 'Spent: 6,500 AED',
        budgetLabel: 'Budget: 10,000 AED',
      ),
      GuideBulletBlock(
        title: 'GCC Multi-Currency',
        description:
            'Native support for AED, SAR, KWD, QAR, BHD, and OMR across all reports.',
      ),
      GuideBulletBlock(
        title: '90-Day Cash Flow Forecast',
        description:
            'Combines recurring expenses and document renewal fees to detect financial dips in advance.',
      ),
      GuideBulletBlock(
        title: 'Smart Bill Spike Alerts',
        description:
            'Automatically detects anomalous utility or service bills compared to your 3-month history.',
      ),
      GuideCtaBlock(
        label: 'Go to Money & Budgets Tab',
        icon: Icons.arrow_outward_rounded,
        route: '/money',
        usePush: false,
        color: FinavigColors.emerald,
      ),
    ],
  ),
  GuideChapter(
    pillLabel: 'Workspaces',
    pillIcon: Icons.business_center_rounded,
    title: 'Workspaces & Collections',
    subtitle:
        'Keep personal documents separate from your business or client entities.',
    blocks: [
      GuideWorkspacesShowcaseBlock(items: [
        GuideWorkspaceItem(
          icon: Icons.person_rounded,
          title: 'Personal Workspace',
          subtitle: 'Your family passports, visas & driving licenses',
          country: 'UAE (AED)',
        ),
        GuideWorkspaceItem(
          icon: Icons.business_rounded,
          title: 'Al Mansoori Trading LLC',
          subtitle: 'Trade license, Ejari, corporate tax & PRO docs',
          country: 'UAE (AED)',
        ),
      ]),
      GuideBulletBlock(
        title: 'One-Tap Switching',
        description:
            'Switch workspaces from the top-left header anytime to instantly re-scope documents and finances.',
      ),
      GuideBulletBlock(
        title: 'Plan Tier Mapping',
        description:
            'Free includes 1 personal collection; Plus unlocks 1 company workspace; Business unlocks unlimited company workspaces.',
      ),
      GuideBulletBlock(
        title: 'Auto-Protection',
        description:
            'If a plan expires, your data is never deleted — surplus company workspaces are securely locked until renewed.',
      ),
      GuideCtaBlock(
        label: 'Manage Collections in Settings',
        icon: Icons.folder_shared_rounded,
        route: '/profile',
        usePush: false,
        color: Colors.purpleAccent,
      ),
    ],
  ),
  GuideChapter(
    pillLabel: 'AI Power',
    pillIcon: Icons.psychology_rounded,
    title: 'AI Intelligence & Reports',
    subtitle:
        'Harness the speed of Groq LLMs and Gemini to understand your finances.',
    blocks: [
      GuideQuoteShowcaseBlock(
        header: 'AI Executive Summary & Budget Simulator',
        quote:
            '“Your cash flow is stable with 12,400 AED net income. 2 renewals totaling 1,850 AED are due in 3 weeks. Recommended: reallocate 400 AED from dining out.”',
      ),
      GuideBulletBlock(
        title: 'Monthly Financial Health Score',
        description:
            'Calculates an objective 0–100 financial health score based on savings rate, budget discipline, and renewal readiness.',
      ),
      GuideBulletBlock(
        title: 'Goal-Driven AI Budget Planner',
        description:
            'State any financial goal (e.g. "Save 15,000 AED for vacation in 6 months") and AI produces tailored category caps.',
      ),
      GuideBulletBlock(
        title: 'PDF & CSV Export',
        description:
            'Export official audit lists and finance reports with a single tap for accountants and team records.',
      ),
      GuideCtaBlock(
        label: 'Try AI Executive Summary',
        icon: Icons.auto_awesome_rounded,
        route: '/ai-summary',
        usePush: true,
        color: FinavigColors.navyPrimary,
        filled: true,
      ),
    ],
  ),
];

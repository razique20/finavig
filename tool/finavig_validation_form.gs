/**
 * Finavig — Idea Validation Form generator.
 *
 * Creates a ready-to-publish Google Form with pain validation, concept
 * testing, feature priorities, willingness-to-pay and discovery questions,
 * tailored to Finavig (GCC document + money intelligence for SMEs).
 *
 * How to run:
 *   1. Open https://script.google.com → New project.
 *   2. Paste this entire file, save.
 *   3. Run createFinavigValidationForm → authorize when asked.
 *   4. Open View → Logs (or Execution log): copy the published form URL.
 *
 * After the run the form is in your Google Drive → Forms, fully editable.
 */

function createFinavigValidationForm() {
  const form = FormApp.create(
    'Finavig — Idea Validation (2 minutes)'
  );

  form.setDescription(
    'Help us build the right tool. Finavig keeps company documents ' +
      '(trade licences, Emirates IDs, visas, insurance) and company money ' +
      'in one place, warns you before every deadline, and forecasts your ' +
      'cash. 14 quick questions — your answers shape the product, and you ' +
      'get founding-user perks.'
  );
  // Keep friction low; contact is a separate optional question.
  form.setCollectEmail(false);
  form.setLimitOneResponsePerUser(false);
  form.setAllowResponseEdits(false);
  form.setConfirmationMessage(
    'Thank you! Want to be a founding user? We will reach out on the ' +
      'email you shared.'
  );

  // ── Section 1: About you ──────────────────────────────────────────────
  form.addSectionHeaderItem().setTitle('About you').setHelpText(
    'Three quick questions so we know whose problems we are solving.'
  );

  form
    .addMultipleChoiceItem()
    .setTitle('What is your role in the company?')
    .setChoiceValues([
      'Owner / Founder',
      'Operations / Office manager',
      'PRO / Government relations',
      'Accountant / Finance',
      'Other',
    ])
    .showOtherOption(true)
    .setRequired(true);

  form
    .addMultipleChoiceItem()
    .setTitle('How many people work in the company?')
    .setChoiceValues(['1–5', '6–20', '21–50', '51–200', '200+'])
    .setRequired(true);

  form
    .addMultipleChoiceItem()
    .setTitle('Where is the company based?')
    .setChoiceValues([
      'UAE',
      'Saudi Arabia',
      'Kuwait',
      'Qatar',
      'Bahrain',
      'Oman',
      'Other',
    ])
    .showOtherOption(true)
    .setRequired(true);

  // ── Section 2: The problem today ──────────────────────────────────────
  form.addSectionHeaderItem().setTitle('How you handle it today').setHelpText(
    'Renewals, deadlines and expenses — as they are right now, not ideally.'
  );

  form
    .addCheckboxItem()
    .setTitle(
      'How do you currently track document renewals (licences, visas, ' +
        'IDs, insurance)?'
    )
    .setChoiceValues([
      'Memory / mental notes',
      'WhatsApp chats',
      'Notebook or paper',
      'Spreadsheet',
      'A document-management app',
      'Our PRO / agent handles it',
    ])
    .showOtherOption(true)
    .setRequired(true);

  form
    .addMultipleChoiceItem()
    .setTitle(
      'In the last 12 months, how often did a missed renewal cause a ' +
        'fine, penalty or blocked service?'
    )
    .setChoiceValues(['Never', 'Once', '2–4 times', '5+ times'])
    .setRequired(true);

  form
    .addScaleItem()
    .setTitle('How stressful is staying on top of renewals and deadlines?')
    .setBounds(1, 5)
    .setLabels('Not stressful at all', 'Extremely stressful')
    .setRequired(true);

  form
    .addMultipleChoiceItem()
    .setTitle('How does the company track day-to-day expenses?')
    .setChoiceValues([
      'Paper receipts',
      'Spreadsheet',
      'Accounting software',
      'A mobile app',
      'Our bookkeeper does it',
      "We don't track consistently",
    ])
    .showOtherOption(true)
    .setRequired(true);

  // ── Section 3: The idea ───────────────────────────────────────────────
  form.addSectionHeaderItem().setTitle('The idea').setHelpText(
    'One app: scan a document once, AI reads the expiry date and renewal ' +
      'fee, escalating alerts fire at 90/60/30/14/7/1 days. Log expenses ' +
      'in one sentence, set budgets, and see a 90-day cash forecast that ' +
      'includes upcoming renewal fees. Local-first, works offline.'
  );

  form
    .addScaleItem()
    .setTitle('How useful would this be for your company?')
    .setBounds(1, 5)
    .setLabels('Not useful', 'Extremely useful')
    .setRequired(true);

  form
    .addMultipleChoiceItem()
    .setTitle('If Finavig existed today, how likely are you to use it weekly?')
    .setChoiceValues([
      'Very likely',
      'Likely',
      'Not sure',
      'Unlikely',
      'Very unlikely',
    ])
    .setRequired(true);

  const features = form.addCheckboxItem();
  features.setTitle('Which features matter most to you? (pick up to 3)');
  features.setChoiceValues([
    'Scan documents + AI reads expiry date & fee',
    'Deadline alerts before every renewal',
    '90-day cash-flow forecast (incl. renewal fees)',
    'Log expenses in one sentence',
    'Budgets with overspend warnings',
    'Savings envelopes for known big costs',
    'Multi-company workspaces',
    'CSV / PDF export for accountants',
    'Arabic interface',
  ]);
  features.showOtherOption(true);
  features.setRequired(true);

  // ── Section 4: Pricing ────────────────────────────────────────────────
  form
    .addMultipleChoiceItem()
    .setTitle('Which plan would fit your company best?')
    .setChoiceValues([
      'Free — AED 0 (documents + alerts, one workspace)',
      'Plus — ~AED 25/month (AI summaries & planning)',
      'Business — ~AED 99/month (multi-company, team access)',
      'I would not pay for this',
      'Not sure yet',
    ])
    .setRequired(true);

  // ── Section 5: Open floor + contact ───────────────────────────────────
  form
    .addParagraphTextItem()
    .setTitle(
      'What is the hardest part of managing company admin today?'
    )
    .setRequired(false);

  form
    .addTextItem()
    .setTitle(
      'Your email — for early access and founding-user perks (optional)'
    )
    .setRequired(false);

  form
    .addCheckboxItem()
    .setTitle('Where do you usually discover new business tools?')
    .setChoiceValues([
      'WhatsApp groups',
      'Instagram / TikTok',
      'LinkedIn',
      'Google search',
      'Friends / word of mouth',
      'App Store / Play Store',
    ])
    .showOtherOption(true)
    .setRequired(false);

  Logger.log('EDIT the form here:  %s', form.getEditUrl());
  Logger.log('SHARE this link:     %s', form.getPublishedUrl());
}

/// User-selectable categories of Finavig data that may be included in AI prompts.
enum AiDataSource {
  documents('Documents', 'Expiry dates and estimated renewal fees'),
  financialRecords(
    'Transactions & budgets',
    'Income, spending, budgets and savings',
  ),
  creditObligations('Credit obligations', 'Money you owe or are owed');

  const AiDataSource(this.label, this.description);

  final String label;
  final String description;
}

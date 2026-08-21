/// Initial system seed data definitions for new company initialization.
class InitialSeedData {
  /// Default 38 Chart of Accounts system accounts.
  static final List<Map<String, String>> chartOfAccounts = [
    // 1000 ASSETS
    {'code': '1000', 'name_ar': 'أصول', 'name_en': 'Assets', 'type': 'asset', 'normal': 'debit', 'parent': ''},
    {'code': '1100', 'name_ar': 'أصول متداولة', 'name_en': 'Current Assets', 'type': 'asset', 'normal': 'debit', 'parent': '1000'},
    {'code': '1110', 'name_ar': 'نقد في الصندوق', 'name_en': 'Cash on Hand', 'type': 'asset', 'normal': 'debit', 'parent': '1100'},
    {'code': '1120', 'name_ar': 'نقد في البنك', 'name_en': 'Cash in Bank', 'type': 'asset', 'normal': 'debit', 'parent': '1100'},
    {'code': '1130', 'name_ar': 'ذمم مدينة', 'name_en': 'Accounts Receivable', 'type': 'asset', 'normal': 'debit', 'parent': '1100'},
    {'code': '1140', 'name_ar': 'سلف العمال', 'name_en': 'Worker Advances', 'type': 'asset', 'normal': 'debit', 'parent': '1100'},
    {'code': '1150', 'name_ar': 'المخزون', 'name_en': 'Inventory', 'type': 'asset', 'normal': 'debit', 'parent': '1100'},

    // 2000 LIABILITIES
    {'code': '2000', 'name_ar': 'خصوم', 'name_en': 'Liabilities', 'type': 'liability', 'normal': 'credit', 'parent': ''},
    {'code': '2100', 'name_ar': 'خصوم متداولة', 'name_en': 'Current Liabilities', 'type': 'liability', 'normal': 'credit', 'parent': '2000'},
    {'code': '2110', 'name_ar': 'ذمم دائنة', 'name_en': 'Accounts Payable', 'type': 'liability', 'normal': 'credit', 'parent': '2100'},
    {'code': '2120', 'name_ar': 'مصاريف مستحقة', 'name_en': 'Accrued Expenses', 'type': 'liability', 'normal': 'credit', 'parent': '2100'},

    // 3000 EQUITY
    {'code': '3000', 'name_ar': 'حقوق الملكية', 'name_en': 'Equity', 'type': 'equity', 'normal': 'credit', 'parent': ''},
    {'code': '3100', 'name_ar': 'رأس المال', 'name_en': 'Owners Capital', 'type': 'equity', 'normal': 'credit', 'parent': '3000'},
    {'code': '3200', 'name_ar': 'مسحوبات شخصية', 'name_en': 'Owners Withdrawals', 'type': 'equity', 'normal': 'debit', 'parent': '3000'},
    {'code': '3300', 'name_ar': 'أرباح محتجزة', 'name_en': 'Retained Earnings', 'type': 'equity', 'normal': 'credit', 'parent': '3000'},

    // 4000 REVENUE
    {'code': '4000', 'name_ar': 'إيرادات', 'name_en': 'Revenue', 'type': 'revenue', 'normal': 'credit', 'parent': ''},
    {'code': '4100', 'name_ar': 'إيرادات المبيعات', 'name_en': 'Sales Revenue', 'type': 'revenue', 'normal': 'credit', 'parent': '4000'},
    {'code': '4200', 'name_ar': 'إيرادات التصنيع', 'name_en': 'Manufacturing Revenue', 'type': 'revenue', 'normal': 'credit', 'parent': '4000'},
    {'code': '4210', 'name_ar': 'إيرادات تصنيع خارجي', 'name_en': 'External Mfg Revenue', 'type': 'revenue', 'normal': 'credit', 'parent': '4200'},
    {'code': '4300', 'name_ar': 'إيرادات أخرى', 'name_en': 'Other Income', 'type': 'revenue', 'normal': 'credit', 'parent': '4000'},

    // 5000 COST OF GOODS/SERVICES
    {'code': '5000', 'name_ar': 'تكلفة البضاعة والخدمات', 'name_en': 'Cost of Goods/Services', 'type': 'cogs', 'normal': 'debit', 'parent': ''},
    {'code': '5100', 'name_ar': 'تكلفة البضاعة المباعة', 'name_en': 'Cost of Goods Sold', 'type': 'cogs', 'normal': 'debit', 'parent': '5000'},
    {'code': '5200', 'name_ar': 'تكاليف التصنيع', 'name_en': 'Manufacturing Costs', 'type': 'cogs', 'normal': 'debit', 'parent': '5000'},
    {'code': '5210', 'name_ar': 'عمالة مباشرة', 'name_en': 'Direct Labor', 'type': 'cogs', 'normal': 'debit', 'parent': '5200'},
    {'code': '5220', 'name_ar': 'مواد تصنيع', 'name_en': 'Manufacturing Materials', 'type': 'cogs', 'normal': 'debit', 'parent': '5200'},
    {'code': '5230', 'name_ar': 'مصاريف ورشة', 'name_en': 'Workshop Overhead', 'type': 'cogs', 'normal': 'debit', 'parent': '5200'},

    // 6000 OPERATING EXPENSES
    {'code': '6000', 'name_ar': 'مصاريف تشغيلية', 'name_en': 'Operating Expenses', 'type': 'expense', 'normal': 'debit', 'parent': ''},
    {'code': '6100', 'name_ar': 'أجور العمال', 'name_en': 'Worker Wages', 'type': 'expense', 'normal': 'debit', 'parent': '6000'},
    {'code': '6200', 'name_ar': 'نقل', 'name_en': 'Transportation', 'type': 'expense', 'normal': 'debit', 'parent': '6000'},
    {'code': '6300', 'name_ar': 'صبغ', 'name_en': 'Painting', 'type': 'expense', 'normal': 'debit', 'parent': '6000'},
    {'code': '6400', 'name_ar': 'عمالة حرة', 'name_en': 'Freelance Workers', 'type': 'expense', 'normal': 'debit', 'parent': '6000'},
    {'code': '6500', 'name_ar': 'أعمال خارجية', 'name_en': 'External Work', 'type': 'expense', 'normal': 'debit', 'parent': '6000'},
    {'code': '6900', 'name_ar': 'مصاريف تشغيلية أخرى', 'name_en': 'Other Operating Expenses', 'type': 'expense', 'normal': 'debit', 'parent': '6000'},

    // 7000 GENERAL EXPENSES
    {'code': '7000', 'name_ar': 'مصاريف عامة', 'name_en': 'General Expenses', 'type': 'expense', 'normal': 'debit', 'parent': ''},
    {'code': '7100', 'name_ar': 'إيجار', 'name_en': 'Rent', 'type': 'expense', 'normal': 'debit', 'parent': '7000'},
    {'code': '7200', 'name_ar': 'فواتير', 'name_en': 'Utilities', 'type': 'expense', 'normal': 'debit', 'parent': '7000'},
    {'code': '7300', 'name_ar': 'مصاريف مكتبية', 'name_en': 'Office Expenses', 'type': 'expense', 'normal': 'debit', 'parent': '7000'},
    {'code': '7900', 'name_ar': 'مصاريف عامة أخرى', 'name_en': 'Other General Expenses', 'type': 'expense', 'normal': 'debit', 'parent': '7000'},
  ];

  /// Default 7 Expense Categories.
  static final List<Map<String, String>> expenseCategories = [
    {'name_ar': 'إيجار', 'name_en': 'Rent', 'group': 'general', 'account_code': '7100'},
    {'name_ar': 'فواتير', 'name_en': 'Utilities', 'group': 'general', 'account_code': '7200'},
    {'name_ar': 'مصاريف مكتبية', 'name_en': 'Office Expenses', 'group': 'general', 'account_code': '7300'},
    {'name_ar': 'نقل', 'name_en': 'Transportation', 'group': 'operating', 'account_code': '6200'},
    {'name_ar': 'صبغ', 'name_en': 'Painting', 'group': 'operating', 'account_code': '6300'},
    {'name_ar': 'عمالة حرة', 'name_en': 'Freelance Workers', 'group': 'operating', 'account_code': '6400'},
    {'name_ar': 'أعمال خارجية', 'name_en': 'External Work', 'group': 'operating', 'account_code': '6500'},
  ];

  /// Default 5 System Roles.
  static final List<Map<String, String>> roles = [
    {'name': 'مالك', 'description': 'Owner'},
    {'name': 'مدير', 'description': 'Admin'},
    {'name': 'محاسب', 'description': 'Accountant'},
    {'name': 'موظف', 'description': 'Employee'},
    {'name': 'مشاهد', 'description': 'Viewer'},
  ];
}

import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const supportedLocales = [
    Locale('ar'),
    Locale('en'),
    Locale('tr'),
  ];

  Map<String, String> get _strings {
    switch (locale.languageCode) {
      case 'en':
        return _en;
      case 'tr':
        return _tr;
      default:
        return _ar;
    }
  }

  String translate(String key) => _strings[key] ?? key;

  // ============================================================
  // NAVIGATION
  // ============================================================
  String get appName => translate('appName');
  String get home => translate('home');
  String get transactions => translate('transactions');
  String get reports => translate('reports');
  String get settings => translate('settings');
  String get pageNotFound => translate('pageNotFound');

  // TRANSACTIONS MENU
  String get sales => translate('sales');
  String get salesDesc => translate('salesDesc');
  String get purchases => translate('purchases');
  String get purchasesDesc => translate('purchasesDesc');
  String get payments => translate('payments');
  String get paymentsDesc => translate('paymentsDesc');
  String get expenses => translate('expenses');
  String get expensesDesc => translate('expensesDesc');
  String get customers => translate('customers');
  String get customersDesc => translate('customersDesc');
  String get suppliers => translate('suppliers');
  String get suppliersDesc => translate('suppliersDesc');
  String get workers => translate('workers');
  String get workersDesc => translate('workersDesc');

  // PAYMENTS CHOOSER
  String get incomingPayments => translate('incomingPayments');
  String get incomingPaymentsDesc => translate('incomingPaymentsDesc');
  String get outgoingPayments => translate('outgoingPayments');
  String get outgoingPaymentsDesc => translate('outgoingPaymentsDesc');

  // REPORTS MENU
  String get trialBalance => translate('trialBalance');
  String get balanceSheet => translate('balanceSheet');
  String get incomeStatement => translate('incomeStatement');
  String get generalLedger => translate('generalLedger');
  String get agingReport => translate('agingReport');
  String get cashFlowReport => translate('cashFlowReport');
  String get financialReports => translate('financialReports');

  // ============================================================
  // DASHBOARD
  // ============================================================
  String get welcomeBack => translate('welcomeBack');
  String get totalRevenue => translate('totalRevenue');
  String get totalExpenses => translate('totalExpenses');
  String get netIncome => translate('netIncome');
  String get cashBalance => translate('cashBalance');
  String get quickActions => translate('quickActions');
  String get newSale => translate('newSale');
  String get newPurchase => translate('newPurchase');
  String get newPayment => translate('newPayment');
  String get recentTransactions => translate('recentTransactions');
  String get viewAll => translate('viewAll');
  String get noTransactionsYet => translate('noTransactionsYet');
  String get startByAddingTransaction => translate('startByAddingTransaction');

  // ============================================================
  // SALES
  // ============================================================
  String get addNewSale => translate('addNewSale');
  String get noSales => translate('noSales');
  String get tapPlusToAddSale => translate('tapPlusToAddSale');
  String get saleSaved => translate('saleSaved');
  String get saveError => translate('saveError');
  String get customer => translate('customer');
  String get selectCustomerOptional => translate('selectCustomerOptional');
  String get generalCustomer => translate('generalCustomer');
  String get date => translate('date');
  String get items => translate('items');
  String get addItem => translate('addItem');
  String itemNumber(int n) => '${translate('item')} $n';
  String get description => translate('description');
  String get itemDescription => translate('itemDescription');
  String get enterDescription => translate('enterDescription');
  String get quantity => translate('quantity');
  String get required => translate('required');
  String get unitPrice => translate('unitPrice');
  String totalAmount(String amount) => '${translate('total')}: $amount';
  String get paymentType => translate('paymentType');
  String get cash => translate('cash');
  String get credit => translate('credit');
  String get mixed => translate('mixed');
  String get cashReceived => translate('cashReceived');
  String get enterCashAmount => translate('enterCashAmount');
  String get amountMustBePositive => translate('amountMustBePositive');
  String get cashMustBeLessThanTotal => translate('cashMustBeLessThanTotal');
  String get notes => translate('notes');
  String get additionalNotesOptional => translate('additionalNotesOptional');
  String get total => translate('total');
  String get saving => translate('saving');
  String get savePurchase => translate('savePurchase');
  String get saveSale => translate('saveSale');
  String get saveExpense => translate('saveExpense');
  String get generalSupplier => translate('generalSupplier');

  // ============================================================
  // PURCHASES
  // ============================================================
  String get addNewPurchase => translate('addNewPurchase');
  String get noPurchases => translate('noPurchases');
  String get tapPlusToAddPurchase => translate('tapPlusToAddPurchase');
  String get purchaseSaved => translate('purchaseSaved');
  String get supplier => translate('supplier');
  String get selectSupplierOptional => translate('selectSupplierOptional');
  String get accountingNature => translate('accountingNature');
  String get inventory => translate('inventory');
  String get materials => translate('materials');
  String get operatingExpense => translate('operatingExpense');
  String get service => translate('service');
  String get cashPaid => translate('cashPaid');
  String get enterCashPaid => translate('enterCashPaid');
  String get cashPaidMustBeLess => translate('cashPaidMustBeLess');

  // ============================================================
  // EXPENSES
  // ============================================================
  String get addNewExpense => translate('addNewExpense');
  String get noExpenses => translate('noExpenses');
  String get tapPlusToAddExpense => translate('tapPlusToAddExpense');
  String get expenseSaved => translate('expenseSaved');
  String get amount => translate('amount');
  String get enterAmount => translate('enterAmount');
  String get category => translate('category');
  String get selectCategory => translate('selectCategory');
  String get selectCategoryValidation => translate('selectCategoryValidation');
  String get paymentMethod => translate('paymentMethod');
  String get bank => translate('bank');
  String get expenseDescription => translate('expenseDescription');
  String get descriptionOptional => translate('descriptionOptional');
  String get uncategorized => translate('uncategorized');

  // ============================================================
  // PAYMENTS
  // ============================================================
  String get customerPayments => translate('customerPayments');
  String get supplierPayments => translate('supplierPayments');
  String get noIncomingPayments => translate('noIncomingPayments');
  String get noOutgoingPayments => translate('noOutgoingPayments');
  String get customerDefault => translate('customerDefault');
  String get supplierDefault => translate('supplierDefault');

  // ============================================================
  // MASTERS
  // ============================================================
  String get noCustomers => translate('noCustomers');
  String get noSuppliers => translate('noSuppliers');
  String get noWorkers => translate('noWorkers');
  String get phone => translate('phone');
  String get balance => translate('balance');
  String get dailyRate => translate('dailyRate');

  // FORMS
  String get addNewCustomer => translate('addNewCustomer');
  String get editCustomer => translate('editCustomer');
  String get addNewSupplier => translate('addNewSupplier');
  String get editSupplier => translate('editSupplier');
  String get addNewWorker => translate('addNewWorker');
  String get editWorker => translate('editWorker');
  String get name => translate('name');
  String get enterName => translate('enterName');
  String get email => translate('email');
  String get address => translate('address');
  String get saveChanges => translate('saveChanges');
  String get addCustomer => translate('addCustomer');
  String get addSupplier => translate('addSupplier');
  String get addWorker => translate('addWorker');
  String get dailyWage => translate('dailyWage');
  String get advanceAmount => translate('advanceAmount');
  String get phoneLabel => translate('phoneLabel');

  // ============================================================
  // REPORTS
  // ============================================================
  String get noData => translate('noData');
  String get accountNumber => translate('accountNumber');
  String get accountName => translate('accountName');
  String get debit => translate('debit');
  String get creditColumn => translate('creditColumn');
  String get balanceCol => translate('balanceCol');
  String get totalLabel => translate('totalLabel');

  // BALANCE SHEET
  String get noAccounts => translate('noAccounts');
  String get balanced => translate('balanced');
  String get unbalanced => translate('unbalanced');
  String get assets => translate('assets');
  String get liabilitiesEquity => translate('liabilitiesEquity');
  String groupTotal(String name) => '${translate('totalLabel')} - $name';

  // INCOME STATEMENT
  String get netProfit => translate('netProfit');
  String get netIncomeReport => translate('netIncomeReport');

  // GENERAL LEDGER
  String get fromDate => translate('fromDate');
  String get toDate => translate('toDate');
  String get noEntries => translate('noEntries');
  String get entryNumber => translate('entryNumber');
  String get descriptionCol => translate('descriptionCol');
  String get accountCol => translate('accountCol');

  // AGING
  String get customerCol => translate('customerCol');
  String get amountDue => translate('amountDue');
  String get recent => translate('recent');
  String get days31_60 => translate('days31_60');
  String get days61_90 => translate('days61_90');
  String get over90Days => translate('over90Days');

  // ACCOUNT STATEMENT
  String get selectAccount => translate('selectAccount');
  String get selectAccountHint => translate('selectAccountHint');
  String get noMovements => translate('noMovements');
  String get runningBalance => translate('runningBalance');

  // ============================================================
  // SETTINGS
  // ============================================================
  String get companyInfo => translate('companyInfo');
  String get companyName => translate('companyName');
  String get companyNameValue => translate('companyNameValue');
  String get addressLabel => translate('addressLabel');
  String get addressValue => translate('addressValue');
  String get phoneLabelSettings => translate('phoneLabelSettings');
  String get emailLabel => translate('emailLabel');
  String get accountingSettings => translate('accountingSettings');
  String get chartOfAccounts => translate('chartOfAccounts');
  String get chartOfAccountsDesc => translate('chartOfAccountsDesc');
  String get expenseCategories => translate('expenseCategories');
  String get expenseCategoriesDesc => translate('expenseCategoriesDesc');
  String get defaultCurrency => translate('defaultCurrency');
  String get defaultCurrencyValue => translate('defaultCurrencyValue');
  String get dataManagement => translate('dataManagement');
  String get backup => translate('backup');
  String get backupDesc => translate('backupDesc');
  String get restore => translate('restore');
  String get restoreDesc => translate('restoreDesc');
  String get exportData => translate('exportData');
  String get exportDataDesc => translate('exportDataDesc');
  String get importData => translate('importData');
  String get importDataDesc => translate('importDataDesc');
  String get aboutSystem => translate('aboutSystem');
  String get systemInfo => translate('systemInfo');
  String get version => translate('version');
  String get helpSupport => translate('helpSupport');
  String get helpSupportDesc => translate('helpSupportDesc');
  String get termsConditions => translate('termsConditions');
  String get privacyPolicy => translate('privacyPolicy');
  String get backupTitle => translate('backupTitle');
  String get backupConfirm => translate('backupConfirm');
  String get cancel => translate('cancel');
  String get creatingBackup => translate('creatingBackup');
  String get create => translate('create');
  String get language => translate('language');
  String get languageDesc => translate('languageDesc');
  String get arabic => translate('arabic');
  String get english => translate('english');
  String get turkish => translate('turkish');

  // ============================================================
  // LICENSE / ACTIVATION
  // ============================================================
  String get enterActivationKey => translate('enterActivationKey');
  String get activationSubtitle => translate('activationSubtitle');
  String get activationHint => translate('activationHint');
  String get activate => translate('activate');
  String get subscriptionPlans => translate('subscriptionPlans');
  String get monthly => translate('monthly');
  String get yearly => translate('yearly');
  String get perMonth => translate('perMonth');
  String get perYear => translate('perYear');
  String get save11 => translate('save11');
  String get contactDistributor => translate('contactDistributor');
  String get activationComplete => translate('activationComplete');
  String get checkingLicense => translate('checkingLicense');
  String get initializingSystem => translate('initializingSystem');

  // COMMON
  String get retry => translate('retry');

  // ============================================================
  // ARABIC STRINGS
  // ============================================================
  static const Map<String, String> _ar = {
    'appName': 'نظام المحاسبة',
    'home': 'الرئيسية',
    'transactions': 'المعاملات',
    'reports': 'التقارير',
    'settings': 'الإعدادات',
    'pageNotFound': 'صفحة غير موجودة',

    // Transactions menu
    'sales': 'المبيعات',
    'salesDesc': 'إدارة فواتير المبيعات',
    'purchases': 'المشتريات',
    'purchasesDesc': 'إدارة فواتير المشتريات',
    'payments': 'المدفوعات',
    'paymentsDesc': 'إدارة المدفوعات والمتحصلات',
    'expenses': 'المصروفات',
    'expensesDesc': 'إدارة المصروفات المختلفة',
    'customers': 'العملاء',
    'customersDesc': 'إدارة بيانات العملاء',
    'suppliers': 'الموردون',
    'suppliersDesc': 'إدارة بيانات الموردين',
    'workers': 'العمال',
    'workersDesc': 'إدارة بيانات العمال',

    // Payments
    'incomingPayments': 'المتحصلات',
    'incomingPaymentsDesc': 'المدفوعات الواردة من العملاء',
    'outgoingPayments': 'المدفوعات',
    'outgoingPaymentsDesc': 'المدفوعات الصادرة للموردين والعمال',

    // Reports menu
    'trialBalance': 'ميزان المراجعة',
    'balanceSheet': 'الميزانية العمومية',
    'incomeStatement': 'قائمة الدخل',
    'generalLedger': 'الأستاذ العام',
    'agingReport': 'تقرير الأعمار',
    'cashFlowReport': 'قائمة التدفقات النقدية',
    'financialReports': 'التقارير المالية',

    // Dashboard
    'welcomeBack': 'مرحباً بعودتك',
    'totalRevenue': 'إجمالي الإيرادات',
    'totalExpenses': 'إجمالي المصروفات',
    'netIncome': 'صافي الدخل',
    'cashBalance': 'الرصيد النقدي',
    'quickActions': 'إجراءات سريعة',
    'newSale': 'بيع جديد',
    'newPurchase': 'شراء جديد',
    'newPayment': 'دفعة جديدة',
    'recentTransactions': 'آخر المعاملات',
    'viewAll': 'عرض الكل',
    'noTransactionsYet': 'لا توجد معاملات بعد',
    'startByAddingTransaction': 'ابدأ بإضافة معاملة جديدة',

    // Sales
    'addNewSale': 'إضافة مبيع جديدة',
    'noSales': 'لا توجد مبيعات',
    'tapPlusToAddSale': 'اضغط على + لإضافة مبيع جديدة',
    'saleSaved': 'تم حفظ المبيع بنجاح',
    'saveError': 'خطأ في الحفظ',
    'customer': 'العميل',
    'selectCustomerOptional': 'اختر العميل (اختياري)',
    'generalCustomer': 'عميل عام',
    'date': 'التاريخ',
    'items': 'الأصناف',
    'addItem': 'إضافة صنف',
    'item': 'صنف',
    'description': 'الوصف',
    'itemDescription': 'وصف الصنف',
    'enterDescription': 'الرجاء إدخال الوصف',
    'quantity': 'الكمية',
    'required': 'مطلوب',
    'unitPrice': 'سعر الوحدة',
    'total': 'الإجمالي',
    'paymentType': 'نوع الدفع',
    'cash': 'نقدي',
    'credit': 'آجل',
    'mixed': 'مختلط',
    'cashReceived': 'المبلغ النقدي المحصّل',
    'enterCashAmount': 'الرجاء إدخال المبلغ النقدي',
    'amountMustBePositive': 'المبلغ يجب أن يكون أكبر من صفر',
    'cashMustBeLessThanTotal': 'المبلغ النقدي يجب أن يكون أقل من الإجمالي',
    'notes': 'ملاحظات',
    'additionalNotesOptional': 'ملاحظات إضافية (اختياري)',
    'saving': 'جاري الحفظ...',
    'saveSale': 'حفظ المبيع',
    'savePurchase': 'حفظ المشتري',
    'saveExpense': 'حفظ المصروف',
    'generalSupplier': 'مورد عام',

    // Purchases
    'addNewPurchase': 'إضافة مشتري جديدة',
    'noPurchases': 'لا توجد مشتريات',
    'tapPlusToAddPurchase': 'اضغط على + لإضافة مشتري جديدة',
    'purchaseSaved': 'تم حفظ المشتري بنجاح',
    'supplier': 'المورد',
    'selectSupplierOptional': 'اختر المورد (اختياري)',
    'accountingNature': 'الطبيعة المحاسبية',
    'inventory': 'مخزون',
    'materials': 'مواد',
    'operatingExpense': 'تشغيلية',
    'service': 'خدمة',
    'cashPaid': 'المبلغ المدفوع نقداً',
    'enterCashPaid': 'الرجاء إدخال المبلغ المدفوع',
    'cashPaidMustBeLess': 'المبلغ المدفوع يجب أن يكون أقل من الإجمالي',

    // Expenses
    'addNewExpense': 'إضافة مصروف جديد',
    'noExpenses': 'لا توجد مصروفات',
    'tapPlusToAddExpense': 'اضغط على + لإضافة مصروف جديد',
    'expenseSaved': 'تم حفظ المصروف بنجاح',
    'amount': 'المبلغ',
    'enterAmount': 'الرجاء إدخال المبلغ',
    'category': 'الفئة',
    'selectCategory': 'اختر الفئة',
    'selectCategoryValidation': 'الرجاء اختيار الفئة',
    'paymentMethod': 'طريقة الدفع',
    'bank': 'بنك',
    'expenseDescription': 'وصف المصروف (اختياري)',
    'descriptionOptional': 'وصف المصروف (اختياري)',
    'uncategorized': 'غير مصنف',

    // Payments
    'customerPayments': 'مدفوعات العملاء',
    'supplierPayments': 'مدفوعات الموردين',
    'noIncomingPayments': 'لا توجد مدفوعات واردة',
    'noOutgoingPayments': 'لا توجد مدفوعات صادرة',
    'customerDefault': 'عميل',
    'supplierDefault': 'مورد',

    // Masters
    'noCustomers': 'لا يوجد عملاء',
    'noSuppliers': 'لا يوجد موردون',
    'noWorkers': 'لا يوجد عمال',
    'phone': 'الهاتف',
    'balanceCol': 'الرصيد',
    'dailyRate': 'الأجر اليومي',

    // Forms
    'addNewCustomer': 'إضافة عميل جديد',
    'editCustomer': 'تعديل العميل',
    'addNewSupplier': 'إضافة مورد جديد',
    'editSupplier': 'تعديل المورد',
    'addNewWorker': 'إضافة عامل جديد',
    'editWorker': 'تعديل العامل',
    'name': 'الاسم *',
    'enterName': 'الرجاء إدخال الاسم',
    'email': 'البريد الإلكتروني',
    'address': 'العنوان',
    'saveChanges': 'حفظ التعديلات',
    'addCustomer': 'إضافة العميل',
    'addSupplier': 'إضافة المورد',
    'addWorker': 'إضافة العامل',
    'dailyWage': 'الأجر اليومي (د.ع)',
    'advanceAmount': 'مبلغ السلفة (د.ع)',
    'phoneLabel': 'الهاتف',

    // Reports
    'noData': 'لا توجد بيانات',
    'accountNumber': 'رقم الحساب',
    'accountName': 'اسم الحساب',
    'debit': 'مدين',
    'creditColumn': 'دائن',
    'totalLabel': 'الإجمالي',
    'noAccounts': 'لا توجد حسابات',
    'balanced': 'الميزانية متساوية',
    'unbalanced': 'الميزانية غير متساوية',
    'assets': 'الأصول',
    'liabilitiesEquity': 'الخصوم + حقوق الملكية',
    'netProfit': 'صافي الربح',
    'netIncomeReport': 'صافي الدخل',
    'fromDate': 'من تاريخ',
    'toDate': 'إلى تاريخ',
    'noEntries': 'لا توجد قيود',
    'entryNumber': 'رقم القيد',
    'descriptionCol': 'الوصف',
    'accountCol': 'الحساب',
    'customerCol': 'العميل',
    'amountDue': 'المطلوب',
    'recent': 'حديثاً',
    'days31_60': '31-60 يوم',
    'days61_90': '61-90 يوم',
    'over90Days': 'أكثر من 90 يوم',
    'selectAccount': 'اختر الحساب',
    'selectAccountHint': 'اختر حساباً لعرض كشف الحساب',
    'noMovements': 'لا توجد حركات',
    'runningBalance': 'الرصيد الجاري',

    // Settings
    'companyInfo': 'بيانات الشركة',
    'companyName': 'اسم الشركة',
    'companyNameValue': 'شركة المحاسبة',
    'addressLabel': 'العنوان',
    'addressValue': 'المملكة العربية السعودية',
    'phoneLabelSettings': 'رقم الهاتف',
    'emailLabel': 'البريد الإلكتروني',
    'accountingSettings': 'إعدادات الحسابات',
    'chartOfAccounts': 'دليل الحسابات',
    'chartOfAccountsDesc': 'إدارة وتصنيف الحسابات',
    'expenseCategories': 'تصنيفات المصروفات',
    'expenseCategoriesDesc': 'إدارة تصنيفات المصروفات',
    'defaultCurrency': 'العملة الافتراضية',
    'defaultCurrencyValue': 'ريال سعودي (SAR)',
    'dataManagement': 'إدارة البيانات',
    'backup': 'نسخ احتياطي',
    'backupDesc': 'إنشاء نسخة احتياطية من البيانات',
    'restore': 'استعادة البيانات',
    'restoreDesc': 'استعادة بيانات من نسخة احتياطية',
    'exportData': 'تصدير البيانات',
    'exportDataDesc': 'تصدير البيانات إلى ملف Excel أو PDF',
    'importData': 'استيراد البيانات',
    'importDataDesc': 'استيراد بيانات من ملف',
    'aboutSystem': 'حول النظام',
    'systemInfo': 'معلومات النظام',
    'version': 'الإصدار 1.0.0',
    'helpSupport': 'المساعدة والدعم',
    'helpSupportDesc': 'التواصل مع فريق الدعم',
    'termsConditions': 'الشروط والأحكام',
    'privacyPolicy': 'سياسة الخصوصية',
    'backupTitle': 'نسخ احتياطي',
    'backupConfirm': 'هل تريد إنشاء نسخة احتياطية من جميع البيانات؟',
    'cancel': 'إلغاء',
    'creatingBackup': 'جاري إنشاء النسخة الاحتياطية...',
    'create': 'إنشاء',
    'language': 'اللغة',
    'languageDesc': 'تغيير لغة التطبيق',
    'arabic': 'العربية',
    'english': 'English',
    'turkish': 'Türkçe',

    // License
    'enterActivationKey': 'أدخل مفتاح التفعيل كاملاً',
    'activationSubtitle': 'أدخل مفتاح التفعيل لبدء الاستخدام',
    'activationHint': 'مثال: ABCD-1234-EFGH-5678',
    'activate': 'تفعيل',
    'subscriptionPlans': 'باقات الاشتراك',
    'monthly': 'شهري',
    'yearly': 'سنوي',
    'perMonth': '/شهر',
    'perYear': '/سنة',
    'save11': 'وفر 11%',
    'contactDistributor': 'للحصول على مفتاح التفعيل تواصل مع الموزع',
    'activationComplete': 'تم التفعيل بنجاح',
    'checkingLicense': 'جاري التحقق من الترخيص...',
    'initializingSystem': 'جاري تهيئة النظام...',
    'retry': 'إعادة المحاولة',
  };

  // ============================================================
  // ENGLISH STRINGS
  // ============================================================
  static const Map<String, String> _en = {
    'appName': 'Accounting System',
    'home': 'Home',
    'transactions': 'Transactions',
    'reports': 'Reports',
    'settings': 'Settings',
    'pageNotFound': 'Page not found',

    // Transactions menu
    'sales': 'Sales',
    'salesDesc': 'Manage sales invoices',
    'purchases': 'Purchases',
    'purchasesDesc': 'Manage purchase invoices',
    'payments': 'Payments',
    'paymentsDesc': 'Manage payments and receipts',
    'expenses': 'Expenses',
    'expensesDesc': 'Manage various expenses',
    'customers': 'Customers',
    'customersDesc': 'Manage customer data',
    'suppliers': 'Suppliers',
    'suppliersDesc': 'Manage supplier data',
    'workers': 'Workers',
    'workersDesc': 'Manage worker data',

    // Payments
    'incomingPayments': 'Receipts',
    'incomingPaymentsDesc': 'Incoming payments from customers',
    'outgoingPayments': 'Payments',
    'outgoingPaymentsDesc': 'Outgoing payments to suppliers and workers',

    // Reports menu
    'trialBalance': 'Trial Balance',
    'balanceSheet': 'Balance Sheet',
    'incomeStatement': 'Income Statement',
    'generalLedger': 'General Ledger',
    'agingReport': 'Aging Report',
    'cashFlowReport': 'Cash Flow Statement',
    'financialReports': 'Financial Reports',

    // Dashboard
    'welcomeBack': 'Welcome back',
    'totalRevenue': 'Total Revenue',
    'totalExpenses': 'Total Expenses',
    'netIncome': 'Net Income',
    'cashBalance': 'Cash Balance',
    'quickActions': 'Quick Actions',
    'newSale': 'New Sale',
    'newPurchase': 'New Purchase',
    'newPayment': 'New Payment',
    'recentTransactions': 'Recent Transactions',
    'viewAll': 'View All',
    'noTransactionsYet': 'No transactions yet',
    'startByAddingTransaction': 'Start by adding a new transaction',

    // Sales
    'addNewSale': 'Add New Sale',
    'noSales': 'No sales',
    'tapPlusToAddSale': 'Tap + to add a new sale',
    'saleSaved': 'Sale saved successfully',
    'saveError': 'Save error',
    'customer': 'Customer',
    'selectCustomerOptional': 'Select customer (optional)',
    'generalCustomer': 'General Customer',
    'date': 'Date',
    'items': 'Items',
    'addItem': 'Add Item',
    'item': 'Item',
    'description': 'Description',
    'itemDescription': 'Item description',
    'enterDescription': 'Please enter description',
    'quantity': 'Quantity',
    'required': 'Required',
    'unitPrice': 'Unit Price',
    'total': 'Total',
    'paymentType': 'Payment Type',
    'cash': 'Cash',
    'credit': 'Credit',
    'mixed': 'Mixed',
    'cashReceived': 'Cash Amount Received',
    'enterCashAmount': 'Please enter cash amount',
    'amountMustBePositive': 'Amount must be greater than zero',
    'cashMustBeLessThanTotal': 'Cash must be less than total',
    'notes': 'Notes',
    'additionalNotesOptional': 'Additional notes (optional)',
    'saving': 'Saving...',
    'saveSale': 'Save Sale',
    'savePurchase': 'Save Purchase',
    'saveExpense': 'Save Expense',
    'generalSupplier': 'General Supplier',

    // Purchases
    'addNewPurchase': 'Add New Purchase',
    'noPurchases': 'No purchases',
    'tapPlusToAddPurchase': 'Tap + to add a new purchase',
    'purchaseSaved': 'Purchase saved successfully',
    'supplier': 'Supplier',
    'selectSupplierOptional': 'Select supplier (optional)',
    'accountingNature': 'Accounting Nature',
    'inventory': 'Inventory',
    'materials': 'Materials',
    'operatingExpense': 'Operating',
    'service': 'Service',
    'cashPaid': 'Cash Amount Paid',
    'enterCashPaid': 'Please enter cash amount paid',
    'cashPaidMustBeLess': 'Cash paid must be less than total',

    // Expenses
    'addNewExpense': 'Add New Expense',
    'noExpenses': 'No expenses',
    'tapPlusToAddExpense': 'Tap + to add a new expense',
    'expenseSaved': 'Expense saved successfully',
    'amount': 'Amount',
    'enterAmount': 'Please enter amount',
    'category': 'Category',
    'selectCategory': 'Select Category',
    'selectCategoryValidation': 'Please select a category',
    'paymentMethod': 'Payment Method',
    'bank': 'Bank',
    'expenseDescription': 'Expense description (optional)',
    'descriptionOptional': 'Description (optional)',
    'uncategorized': 'Uncategorized',

    // Payments
    'customerPayments': 'Customer Payments',
    'supplierPayments': 'Supplier Payments',
    'noIncomingPayments': 'No incoming payments',
    'noOutgoingPayments': 'No outgoing payments',
    'customerDefault': 'Customer',
    'supplierDefault': 'Supplier',

    // Masters
    'noCustomers': 'No customers',
    'noSuppliers': 'No suppliers',
    'noWorkers': 'No workers',
    'phone': 'Phone',
    'balanceCol': 'Balance',
    'dailyRate': 'Daily Rate',

    // Forms
    'addNewCustomer': 'Add New Customer',
    'editCustomer': 'Edit Customer',
    'addNewSupplier': 'Add New Supplier',
    'editSupplier': 'Edit Supplier',
    'addNewWorker': 'Add New Worker',
    'editWorker': 'Edit Worker',
    'name': 'Name *',
    'enterName': 'Please enter name',
    'email': 'Email',
    'address': 'Address',
    'saveChanges': 'Save Changes',
    'addCustomer': 'Add Customer',
    'addSupplier': 'Add Supplier',
    'addWorker': 'Add Worker',
    'dailyWage': 'Daily Wage (IQD)',
    'advanceAmount': 'Advance Amount (IQD)',
    'phoneLabel': 'Phone',

    // Reports
    'noData': 'No data',
    'accountNumber': 'Account No.',
    'accountName': 'Account Name',
    'debit': 'Debit',
    'creditColumn': 'Credit',
    'totalLabel': 'Total',
    'noAccounts': 'No accounts',
    'balanced': 'Balanced',
    'unbalanced': 'Unbalanced',
    'assets': 'Assets',
    'liabilitiesEquity': 'Liabilities + Equity',
    'netProfit': 'Net Profit',
    'netIncomeReport': 'Net Income',
    'fromDate': 'From Date',
    'toDate': 'To Date',
    'noEntries': 'No entries',
    'entryNumber': 'Entry No.',
    'descriptionCol': 'Description',
    'accountCol': 'Account',
    'customerCol': 'Customer',
    'amountDue': 'Amount Due',
    'recent': 'Recent',
    'days31_60': '31-60 days',
    'days61_90': '61-90 days',
    'over90Days': 'Over 90 days',
    'selectAccount': 'Select Account',
    'selectAccountHint': 'Select an account to view statement',
    'noMovements': 'No movements',
    'runningBalance': 'Running Balance',

    // Settings
    'companyInfo': 'Company Information',
    'companyName': 'Company Name',
    'companyNameValue': 'Accounting Company',
    'addressLabel': 'Address',
    'addressValue': 'Kingdom of Saudi Arabia',
    'phoneLabelSettings': 'Phone Number',
    'emailLabel': 'Email',
    'accountingSettings': 'Accounting Settings',
    'chartOfAccounts': 'Chart of Accounts',
    'chartOfAccountsDesc': 'Manage and classify accounts',
    'expenseCategories': 'Expense Categories',
    'expenseCategoriesDesc': 'Manage expense categories',
    'defaultCurrency': 'Default Currency',
    'defaultCurrencyValue': 'Saudi Riyal (SAR)',
    'dataManagement': 'Data Management',
    'backup': 'Backup',
    'backupDesc': 'Create a backup of all data',
    'restore': 'Restore Data',
    'restoreDesc': 'Restore data from backup',
    'exportData': 'Export Data',
    'exportDataDesc': 'Export data to Excel or PDF',
    'importData': 'Import Data',
    'importDataDesc': 'Import data from file',
    'aboutSystem': 'About System',
    'systemInfo': 'System Information',
    'version': 'Version 1.0.0',
    'helpSupport': 'Help & Support',
    'helpSupportDesc': 'Contact support team',
    'termsConditions': 'Terms & Conditions',
    'privacyPolicy': 'Privacy Policy',
    'backupTitle': 'Backup',
    'backupConfirm': 'Do you want to create a backup of all data?',
    'cancel': 'Cancel',
    'creatingBackup': 'Creating backup...',
    'create': 'Create',
    'language': 'Language',
    'languageDesc': 'Change app language',
    'arabic': 'العربية',
    'english': 'English',
    'turkish': 'Türkçe',

    // License
    'enterActivationKey': 'Please enter the full activation key',
    'activationSubtitle': 'Enter activation key to start',
    'activationHint': 'e.g. ABCD-1234-EFGH-5678',
    'activate': 'Activate',
    'subscriptionPlans': 'Subscription Plans',
    'monthly': 'Monthly',
    'yearly': 'Yearly',
    'perMonth': '/month',
    'perYear': '/year',
    'save11': 'Save 11%',
    'contactDistributor': 'Contact distributor to get activation key',
    'activationComplete': 'Activation successful',
    'checkingLicense': 'Checking license...',
    'initializingSystem': 'Initializing system...',
    'retry': 'Retry',
  };

  // ============================================================
  // TURKISH STRINGS
  // ============================================================
  static const Map<String, String> _tr = {
    'appName': 'Muhasebe Sistemi',
    'home': 'Ana Sayfa',
    'transactions': 'İşlemler',
    'reports': 'Raporlar',
    'settings': 'Ayarlar',
    'pageNotFound': 'Sayfa bulunamadı',

    // Transactions menu
    'sales': 'Satışlar',
    'salesDesc': 'Satış faturalarını yönetin',
    'purchases': 'Alışverişler',
    'purchasesDesc': 'Alış faturalarını yönetin',
    'payments': 'Ödemeler',
    'paymentsDesc': 'Ödemeleri ve tahsilatları yönetin',
    'expenses': 'Giderler',
    'expensesDesc': 'Çeşitli giderleri yönetin',
    'customers': 'Müşteriler',
    'customersDesc': 'Müşteri bilgilerini yönetin',
    'suppliers': 'Tedarikçiler',
    'suppliersDesc': 'Tedarikçi bilgilerini yönetin',
    'workers': 'İşçiler',
    'workersDesc': 'İşçi bilgilerini yönetin',

    // Payments
    'incomingPayments': 'Tahsilatlar',
    'incomingPaymentsDesc': 'Müşterilerden gelen ödemeler',
    'outgoingPayments': 'Ödemeler',
    'outgoingPaymentsDesc': 'Tedarikçilere ve işçilere yapılan ödemeler',

    // Reports menu
    'trialBalance': 'Prova Mizanı',
    'balanceSheet': 'Bilanço',
    'incomeStatement': 'Kâr-Zarar Tablosu',
    'generalLedger': 'Defteri Kebir',
    'agingReport': 'Yaşlandırma Raporu',
    'cashFlowReport': 'Nakit Akış Tablosu',
    'financialReports': 'Finansal Raporlar',

    // Dashboard
    'welcomeBack': 'Tekrar hoş geldiniz',
    'totalRevenue': 'Toplam Gelir',
    'totalExpenses': 'Toplam Gider',
    'netIncome': 'Net Kâr',
    'cashBalance': 'Nakit Bakiye',
    'quickActions': 'Hızlı İşlemler',
    'newSale': 'Yeni Satış',
    'newPurchase': 'Yeni Alış',
    'newPayment': 'Yeni Ödeme',
    'recentTransactions': 'Son İşlemler',
    'viewAll': 'Tümünü Gör',
    'noTransactionsYet': 'Henüz işlem yok',
    'startByAddingTransaction': 'Yeni bir işlem ekleyerek başlayın',

    // Sales
    'addNewSale': 'Yeni Satış Ekle',
    'noSales': 'Satış yok',
    'tapPlusToAddSale': 'Yeni satış eklemek için + ya dokunun',
    'saleSaved': 'Satış başarıyla kaydedildi',
    'saveError': 'Kaydetme hatası',
    'customer': 'Müşteri',
    'selectCustomerOptional': 'Müşteri seçin (isteğe bağlı)',
    'generalCustomer': 'Genel Müşteri',
    'date': 'Tarih',
    'items': 'Kalemler',
    'addItem': 'Kalem Ekle',
    'item': 'Kalem',
    'description': 'Açıklama',
    'itemDescription': 'Kalem açıklaması',
    'enterDescription': 'Lütfen açıklama girin',
    'quantity': 'Miktar',
    'required': 'Gerekli',
    'unitPrice': 'Birim Fiyat',
    'total': 'Toplam',
    'paymentType': 'Ödeme Türü',
    'cash': 'Nakit',
    'credit': 'Kredili',
    'mixed': 'Karma',
    'cashReceived': 'Alınan Nakit Tutarı',
    'enterCashAmount': 'Lütfen nakit tutarı girin',
    'amountMustBePositive': 'Tutar sıfırdan büyük olmalıdır',
    'cashMustBeLessThanTotal': 'Nakit toplamdan az olmalıdır',
    'notes': 'Notlar',
    'additionalNotesOptional': 'Ek notlar (isteğe bağlı)',
    'saving': 'Kaydediliyor...',
    'saveSale': 'Satışı Kaydet',
    'savePurchase': 'Alışı Kaydet',
    'saveExpense': 'Gideri Kaydet',
    'generalSupplier': 'Genel Tedarikçi',

    // Purchases
    'addNewPurchase': 'Yeni Alış Ekle',
    'noPurchases': 'Alış yok',
    'tapPlusToAddPurchase': 'Yeni alış eklemek için + ya dokunun',
    'purchaseSaved': 'Alış başarıyla kaydedildi',
    'supplier': 'Tedarikçi',
    'selectSupplierOptional': 'Tedarikçi seçin (isteğe bağlı)',
    'accountingNature': 'Muhasebe Niteliği',
    'inventory': 'Stok',
    'materials': 'Malzeme',
    'operatingExpense': 'İşletme',
    'service': 'Hizmet',
    'cashPaid': 'Ödenen Nakit Tutarı',
    'enterCashPaid': 'Lütfen ödenen nakit tutarını girin',
    'cashPaidMustBeLess': 'Ödenen nakit toplamdan az olmalıdır',

    // Expenses
    'addNewExpense': 'Yeni Gider Ekle',
    'noExpenses': 'Gider yok',
    'tapPlusToAddExpense': 'Yeni gider eklemek için + ya dokunun',
    'expenseSaved': 'Gider başarıyla kaydedildi',
    'amount': 'Tutar',
    'enterAmount': 'Lütfen tutarı girin',
    'category': 'Kategori',
    'selectCategory': 'Kategori Seçin',
    'selectCategoryValidation': 'Lütfen bir kategori seçin',
    'paymentMethod': 'Ödeme Yöntemi',
    'bank': 'Banka',
    'expenseDescription': 'Gider açıklaması (isteğe bağlı)',
    'descriptionOptional': 'Açıklama (isteğe bağlı)',
    'uncategorized': 'Kategorisiz',

    // Payments
    'customerPayments': 'Müşteri Ödemeleri',
    'supplierPayments': 'Tedarikçi Ödemeleri',
    'noIncomingPayments': 'Gelen ödeme yok',
    'noOutgoingPayments': 'Giden ödeme yok',
    'customerDefault': 'Müşteri',
    'supplierDefault': 'Tedarikçi',

    // Masters
    'noCustomers': 'Müşteri yok',
    'noSuppliers': 'Tedarikçi yok',
    'noWorkers': 'İşçi yok',
    'phone': 'Telefon',
    'balanceCol': 'Bakiye',
    'dailyRate': 'Günlük Ücret',

    // Forms
    'addNewCustomer': 'Yeni Müşteri Ekle',
    'editCustomer': 'Müşteriyi Düzenle',
    'addNewSupplier': 'Yeni Tedarikçi Ekle',
    'editSupplier': 'Tedarikçiyi Düzenle',
    'addNewWorker': 'Yeni İşçi Ekle',
    'editWorker': 'İşçiyi Düzenle',
    'name': 'Ad *',
    'enterName': 'Lütfen ad girin',
    'email': 'E-posta',
    'address': 'Adres',
    'saveChanges': 'Değişiklikleri Kaydet',
    'addCustomer': 'Müşteri Ekle',
    'addSupplier': 'Tedarikçi Ekle',
    'addWorker': 'İşçi Ekle',
    'dailyWage': 'Günlük Ücret (IQD)',
    'advanceAmount': 'Avans Tutarı (IQD)',
    'phoneLabel': 'Telefon',

    // Reports
    'noData': 'Veri yok',
    'accountNumber': 'Hesap No.',
    'accountName': 'Hesap Adı',
    'debit': 'Borç',
    'creditColumn': 'Alacak',
    'totalLabel': 'Toplam',
    'noAccounts': 'Hesap yok',
    'balanced': 'Dengeli',
    'unbalanced': 'Dengesiz',
    'assets': 'Aktifler',
    'liabilitiesEquity': 'Pasifler + Özkaynaklar',
    'netProfit': 'Net Kâr',
    'netIncomeReport': 'Net Gelir',
    'fromDate': 'Başlangıç',
    'toDate': 'Bitiş',
    'noEntries': 'Kayıt yok',
    'entryNumber': 'Kayıt No.',
    'descriptionCol': 'Açıklama',
    'accountCol': 'Hesap',
    'customerCol': 'Müşteri',
    'amountDue': 'Tutar',
    'recent': 'Son',
    'days31_60': '31-60 gün',
    'days61_90': '61-90 gün',
    'over90Days': '90+ gün',
    'selectAccount': 'Hesap Seçin',
    'selectAccountHint': 'Hesap özeti için bir hesap seçin',
    'noMovements': 'Hareket yok',
    'runningBalance': 'İşleyen Bakiye',

    // Settings
    'companyInfo': 'Şirket Bilgileri',
    'companyName': 'Şirket Adı',
    'companyNameValue': 'Muhasebe Şirketi',
    'addressLabel': 'Adres',
    'addressValue': 'Suudi Arabistan',
    'phoneLabelSettings': 'Telefon Numarası',
    'emailLabel': 'E-posta',
    'accountingSettings': 'Muhasebe Ayarları',
    'chartOfAccounts': 'Hesap Planı',
    'chartOfAccountsDesc': 'Hesapları yönetin ve sınıflandırın',
    'expenseCategories': 'Gider Kategorileri',
    'expenseCategoriesDesc': 'Gider kategorilerini yönetin',
    'defaultCurrency': 'Varsayılan Para Birimi',
    'defaultCurrencyValue': 'Suudi Riyali (SAR)',
    'dataManagement': 'Veri Yönetimi',
    'backup': 'Yedekleme',
    'backupDesc': 'Tüm verilerin yedeğini oluşturun',
    'restore': 'Veri Geri Yükleme',
    'restoreDesc': 'Yedekten veri geri yükleyin',
    'exportData': 'Veri Dışa Aktar',
    'exportDataDesc': 'Verileri Excel veya PDF olarak dışa aktarın',
    'importData': 'Veri İçe Aktar',
    'importDataDesc': 'Dosyadan veri içe aktarın',
    'aboutSystem': 'Sistem Hakkında',
    'systemInfo': 'Sistem Bilgisi',
    'version': 'Sürüm 1.0.0',
    'helpSupport': 'Yardım & Destek',
    'helpSupportDesc': 'Destek ekibiyle iletişime geçin',
    'termsConditions': 'Şartlar & Koşullar',
    'privacyPolicy': 'Gizlilik Politikası',
    'backupTitle': 'Yedekleme',
    'backupConfirm': 'Tüm verilerin yedeğini oluşturmak istiyor musunuz?',
    'cancel': 'İptal',
    'creatingBackup': 'Yedek oluşturuluyor...',
    'create': 'Oluştur',
    'language': 'Dil',
    'languageDesc': 'Uygulama dilini değiştirin',
    'arabic': 'العربية',
    'english': 'English',
    'turkish': 'Türkçe',

    // License
    'enterActivationKey': 'Lütfen tam aktivasyon anahtarını girin',
    'activationSubtitle': 'Kullanıma başlamak için aktivasyon anahtarını girin',
    'activationHint': 'ör. ABCD-1234-EFGH-5678',
    'activate': 'Etkinleştir',
    'subscriptionPlans': 'Abonelik Planları',
    'monthly': 'Aylık',
    'yearly': 'Yıllık',
    'perMonth': '/ay',
    'perYear': '/yıl',
    'save11': '%11 Tasarruf',
    'contactDistributor': 'Aktivasyon anahtarı için dağıtıcıyla iletişime geçin',
    'activationComplete': 'Aktivasyon başarılı',
    'checkingLicense': 'Lisans kontrol ediliyor...',
    'initializingSystem': 'Sistem başlatılıyor...',
    'retry': 'Tekrar Dene',
  };
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['ar', 'en', 'tr'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}

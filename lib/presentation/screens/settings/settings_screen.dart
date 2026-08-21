import 'package:flutter/material.dart';
import 'package:accounting_system/presentation/theme/app_theme.dart';
import 'package:accounting_system/l10n/app_localizations.dart';
import 'package:accounting_system/l10n/locale_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          _buildSectionHeader(context, loc.companyInfo),
          _buildSettingsCard(
            children: [
              _buildSettingsTile(
                icon: Icons.business,
                title: loc.companyName,
                subtitle: loc.companyNameValue,
                onTap: () {},
              ),
              const Divider(),
              _buildSettingsTile(
                icon: Icons.location_on,
                title: loc.addressLabel,
                subtitle: loc.addressValue,
                onTap: () {},
              ),
              const Divider(),
              _buildSettingsTile(
                icon: Icons.phone,
                title: loc.phoneLabelSettings,
                subtitle: '+966XXXXXXXXX',
                onTap: () {},
              ),
              const Divider(),
              _buildSettingsTile(
                icon: Icons.email,
                title: loc.emailLabel,
                subtitle: 'info@accounting.com',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, loc.language),
          _buildSettingsCard(
            children: [
              _buildLanguageTile(
                title: loc.arabic,
                value: 'ar',
                locale: const Locale('ar'),
              ),
              const Divider(),
              _buildLanguageTile(
                title: loc.english,
                value: 'en',
                locale: const Locale('en'),
              ),
              const Divider(),
              _buildLanguageTile(
                title: loc.turkish,
                value: 'tr',
                locale: const Locale('tr'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, loc.accountingSettings),
          _buildSettingsCard(
            children: [
              _buildSettingsTile(
                icon: Icons.account_tree,
                title: loc.chartOfAccounts,
                subtitle: loc.chartOfAccountsDesc,
                onTap: () {},
              ),
              const Divider(),
              _buildSettingsTile(
                icon: Icons.category,
                title: loc.expenseCategories,
                subtitle: loc.expenseCategoriesDesc,
                onTap: () {},
              ),
              const Divider(),
              _buildSettingsTile(
                icon: Icons.attach_money,
                title: loc.defaultCurrency,
                subtitle: loc.defaultCurrencyValue,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, loc.dataManagement),
          _buildSettingsCard(
            children: [
              _buildSettingsTile(
                icon: Icons.backup,
                title: loc.backup,
                subtitle: loc.backupDesc,
                onTap: () => _showBackupDialog(context),
              ),
              const Divider(),
              _buildSettingsTile(
                icon: Icons.restore,
                title: loc.restore,
                subtitle: loc.restoreDesc,
                onTap: () {},
              ),
              const Divider(),
              _buildSettingsTile(
                icon: Icons.file_download,
                title: loc.exportData,
                subtitle: loc.exportDataDesc,
                onTap: () {},
              ),
              const Divider(),
              _buildSettingsTile(
                icon: Icons.file_upload,
                title: loc.importData,
                subtitle: loc.importDataDesc,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, loc.aboutSystem),
          _buildSettingsCard(
            children: [
              _buildSettingsTile(
                icon: Icons.info,
                title: loc.systemInfo,
                subtitle: loc.version,
                onTap: () {},
              ),
              const Divider(),
              _buildSettingsTile(
                icon: Icons.help,
                title: loc.helpSupport,
                subtitle: loc.helpSupportDesc,
                onTap: () {},
              ),
              const Divider(),
              _buildSettingsTile(
                icon: Icons.description,
                title: loc.termsConditions,
                subtitle: loc.privacyPolicy,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLanguageTile({
    required String title,
    required String value,
    required Locale locale,
  }) {
    final currentLang = Localizations.localeOf(context).languageCode;
    final isSelected = currentLang == value;

    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
        ),
      ),
      onTap: () {
        LocaleProviderScope.of(context).setLocale(locale);
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildSettingsCard({required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primary),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
        ),
      ),
      trailing: const Icon(Icons.chevron_left, color: AppTheme.textSecondary),
      onTap: onTap,
    );
  }

  void _showBackupDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.backupTitle),
        content: Text(loc.backupConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(loc.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(loc.creatingBackup),
                  backgroundColor: AppTheme.primary,
                ),
              );
            },
            child: Text(loc.create),
          ),
        ],
      ),
    );
  }
}

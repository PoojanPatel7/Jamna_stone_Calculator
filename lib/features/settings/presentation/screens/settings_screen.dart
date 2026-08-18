import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:slab_count/main.dart';
import 'package:slab_count/core/localization/app_translations.dart';
import 'package:slab_count/features/slabs/services/backup_service.dart';
import 'package:slab_count/features/settings/presentation/screens/info_screen.dart';
import 'package:slab_count/features/settings/presentation/screens/backup_status_screen.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  
  List<BackupLog> _backupLogs = [];
  List<BackupLog> _loadLogs = [];
  bool _isLoadingLogs = true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _loadHistoryLogs();
  }

  Future<void> _loadHistoryLogs() async {
    final logs = await BackupService.getLogs();
    if (mounted) {
      setState(() {
        _backupLogs = logs.where((l) => l.type == 'Backup').toList();
        _loadLogs = logs.where((l) => l.type == 'Load').toList();
        _isLoadingLogs = false;
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _showLanguagePicker() {
    final currentLang = AppTranslations.currentLocale.value;
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 250,
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            children: [
              Container(
                color: Theme.of(context).appBarTheme.backgroundColor,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.pop(context),
                    ),
                    CupertinoButton(
                      child: const Text('Done'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 40,
                  scrollController: FixedExtentScrollController(
                    initialItem: currentLang == 'en' ? 0 : (currentLang == 'hi' ? 1 : 2),
                  ),
                  onSelectedItemChanged: (index) {
                    final newLang = index == 0 ? 'en' : (index == 1 ? 'hi' : 'gu');
                    AppTranslations.currentLocale.value = newLang;
                  },
                  children: const [
                    Center(child: Text('English')),
                    Center(child: Text('हिंदी')),
                    Center(child: Text('ગુજરાતી')),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openPrivacyPolicy() {
    Navigator.push(context, CupertinoPageRoute(builder: (context) => InfoScreen(
      title: 'Privacy Policy',
      headerIcon: Icons.privacy_tip_rounded,
      headerColor: Colors.orange,
      topDescription: 'Your privacy is our top priority. We believe in keeping your data entirely under your control.',
      sections: [
        InfoSection(icon: Icons.phonelink_lock, title: 'Local-First Approach', content: 'Jamna Stone is designed to work completely offline. Every measurement book, stock entry, and block name you create is stored securely on your device\'s local storage. We do not use remote databases to store your inventory.'),
        InfoSection(icon: Icons.visibility_off_rounded, title: 'No Telemetry or Tracking', content: 'We do not track your usage, collect analytical data, or sell your personal information. Your business data is your business alone.'),
        InfoSection(icon: Icons.file_download_rounded, title: 'Data Export & Ownership', content: 'You can export your measurement sheets to PDF at any time. When you use the Backup feature, it saves a JSON database directly into your device\'s Document folder which you can copy, move, or delete freely.'),
      ],
    )));
  }

  void _openTerms() {
    Navigator.push(context, CupertinoPageRoute(builder: (context) => InfoScreen(
      title: 'Terms & Conditions',
      headerIcon: Icons.description_rounded,
      headerColor: Colors.redAccent,
      topDescription: 'By using the Jamna Stone app, you agree to our usage terms. Please read them carefully.',
      sections: [
        InfoSection(icon: Icons.gavel_rounded, title: 'App Usage & Liability', content: 'This application is provided "as is" without warranty. While the app is designed to calculate areas and manage inventory accurately, the developers are not liable for any miscalculations, loss of business, or data corruption.'),
        InfoSection(icon: Icons.cloud_off_rounded, title: 'Data Responsibility', content: 'Since this app does not rely on a central server, you are entirely responsible for keeping your data safe. We highly recommend using the built-in Backup feature regularly to prevent data loss in case of app uninstallation or device failure.'),
        InfoSection(icon: Icons.update_rounded, title: 'Updates & Changes', content: 'We may release updates to improve functionality and fix bugs. Continued use of the app signifies your acceptance of any updated terms.'),
      ],
    )));
  }

  void _openDataSecurity() {
    Navigator.push(context, CupertinoPageRoute(builder: (context) => InfoScreen(
      title: 'Data Security',
      headerIcon: Icons.security_rounded,
      headerColor: Colors.deepOrange,
      topDescription: 'Learn how Jamna Stone protects your data and ensures it is never lost unintentionally.',
      sections: [
        InfoSection(icon: Icons.lock_rounded, title: 'Encrypted Local Storage', content: 'Your day-to-day data is securely stored within the app\'s internal storage partition. This partition is heavily protected by the operating system and cannot be accessed by other apps.'),
        InfoSection(icon: Icons.folder_special_rounded, title: 'Backup Storage Location', content: 'When you generate a backup, it saves a `database.json` file securely into your device\'s local Documents folder (`/Documents/Jamna Stone Backup`).'),
        InfoSection(icon: Icons.delete_forever_rounded, title: 'Uninstall Behavior', content: 'If you accidentally uninstall the app, your active session data will be cleared, but your generated backups in the Documents folder will remain safely untouched unless you manually delete them.'),
        InfoSection(icon: Icons.health_and_safety_rounded, title: 'Best Practices', content: 'To ensure maximum security, create backups weekly and consider copying the `Jamna Stone Backup` folder to an external drive or cloud service.'),
      ],
    )));
  }

  void _openSupport() {
    Navigator.push(context, CupertinoPageRoute(builder: (context) => InfoScreen(
      title: 'Contact Developer',
      headerIcon: Icons.contact_support_rounded,
      headerColor: Colors.purpleAccent,
      topDescription: 'Have a question, feedback, or need help? We are here for you.',
      sections: [
        InfoSection(icon: Icons.email_rounded, title: 'Direct Email', content: 'Feel free to reach out directly at:\n\npanchasarapoojan@gmail.com'),
        InfoSection(icon: Icons.support_agent_rounded, title: 'Response Time', content: 'We typically respond to support inquiries within 24-48 hours. When emailing, please include a detailed description of your issue or request.'),
        InfoSection(icon: Icons.bug_report_rounded, title: 'Reporting Bugs', content: 'If you encounter a bug, please let us know what screen you were on and what steps caused the issue, so we can fix it promptly in the next update.'),
      ],
      customBottomWidget: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purpleAccent.withOpacity(0.8), Colors.purpleAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.purpleAccent.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: const Center(
                child: Text(
                  'PP',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.purpleAccent),
                ),
              ),
            ),
            const SizedBox(width: 20),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Panchasara Poojan',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Lead Developer & Designer',
                    style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )));
  }

  void _openBackupStatus() {
    Navigator.push(context, CupertinoPageRoute(builder: (context) => const BackupStatusScreen()));
  }

  void _openAboutApp() {
    Navigator.push(context, CupertinoPageRoute(builder: (context) => InfoScreen(
      title: 'About Jamna Stone',
      headerIcon: Icons.info_outline_rounded,
      headerColor: Colors.blueGrey,
      topDescription: 'Jamna Stone is a state-of-the-art marble and granite management platform designed for stonemasons, fabricators, and suppliers.',
      sections: [
        InfoSection(icon: Icons.smartphone_rounded, title: 'Modern Slab Counting', content: 'Say goodbye to physical pocket notebook logs. Jamna Stone brings a modern, fast, and structured layout to count slabs and track marble and granite blocks.'),
        InfoSection(icon: Icons.local_activity_rounded, title: 'Offline First & Secure', content: 'Calculations are instant and require no active internet connection. All documents and data live entirely on your device with offline backup capability.'),
        InfoSection(icon: Icons.build_circle_rounded, title: 'Version & Specifications', content: 'App Version: 1.0.2\nBuild: 3\nFramework: Flutter SDK'),
      ],
    )));
  }

  void _showHistoryLogs(String type, List<BackupLog> logs) {
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No $type history available.')));
      return;
    }
    
    final headerColor = type == 'Backup' ? Colors.blue : Colors.green;
    final headerIcon = type == 'Backup' ? Icons.cloud_upload_rounded : Icons.cloud_download_rounded;

    Navigator.push(context, CupertinoPageRoute(builder: (context) => InfoScreen(
      title: '$type History Log',
      headerIcon: headerIcon,
      headerColor: headerColor,
      topDescription: 'A chronological record of all your past $type operations.',
      sections: logs.map((log) {
        final parsedDate = DateTime.tryParse(log.date) ?? DateTime.now();
        final dateStr = DateFormat('MMM d, yyyy - hh:mm a').format(parsedDate);
        return InfoSection(
          icon: Icons.history_rounded,
          title: dateStr,
          content: log.details,
        );
      }).toList(),
    )));
  }

  void _showAppGuide() {
    Navigator.push(context, CupertinoPageRoute(builder: (context) => InfoScreen(
      title: 'app_guide'.tr,
      headerIcon: Icons.menu_book_rounded,
      headerColor: Colors.blue,
      topDescription: 'Welcome to Jamna Stone! Here is a quick guide on how to efficiently manage your inventory and measurement books.',
      sections: [
        InfoSection(icon: Icons.inventory_2_rounded, title: 'Add New Blocks', content: 'Add new blocks of Marble or Granite to your inventory, specifying their initial slab count and estimated area.'),
        InfoSection(icon: Icons.category_rounded, title: 'Smart Categories', content: 'Your inventory is automatically organized into Granite and Marble sections for quick access.'),
        InfoSection(icon: Icons.search_rounded, title: 'Intelligent Search', content: 'Search for specific blocks by name, number, or type using the intelligent search bar on the Stock page.'),
        InfoSection(icon: Icons.link_rounded, title: 'Linked vs Unlinked Books', content: 'Create a measurement book linked to an existing block, or create an unlinked standalone book from the History page.'),
        InfoSection(icon: Icons.calculate_rounded, title: 'Automatic Calculations', content: 'Enter length and width for each slab. The area is calculated automatically in square feet.'),
        InfoSection(icon: Icons.auto_awesome_motion_rounded, title: 'Dynamic Rows', content: 'For unlinked books, rows are automatically added as you fill them. For linked books, the rows are strictly limited to the remaining slabs of that block.'),
        InfoSection(icon: Icons.picture_as_pdf_rounded, title: 'PDF Export', content: 'Export your completed measurement books securely to PDF and share them seamlessly with clients or team members.'),
      ],
    )));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF2F2F7),
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: isDark ? Colors.black : const Color(0xFFF2F2F7),
            elevation: 0,
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // Theme & Language Group
                    _buildSectionHeader('PREFERENCES'),
                    _buildSettingsGroup(
                      isDark: isDark,
                      children: [
                        _buildSettingsRow(
                          icon: Icons.dark_mode_rounded,
                          iconColor: Colors.deepPurple,
                          title: 'Theme Mode',
                          trailing: ValueListenableBuilder<ThemeMode>(
                            valueListenable: themeNotifier,
                            builder: (context, currentMode, _) {
                              return CupertinoSlidingSegmentedControl<ThemeMode>(
                                backgroundColor: isDark ? const Color(0xFF333333) : CupertinoColors.lightBackgroundGray,
                                thumbColor: isDark ? const Color(0xFF555555) : Colors.white,
                                groupValue: currentMode,
                                children: const {
                                  ThemeMode.system: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Auto', style: TextStyle(fontSize: 12))),
                                  ThemeMode.light: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Light', style: TextStyle(fontSize: 12))),
                                  ThemeMode.dark: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Dark', style: TextStyle(fontSize: 12))),
                                },
                                onValueChanged: (ThemeMode? value) {
                                  if (value != null) {
                                    themeNotifier.value = value;
                                  }
                                },
                              );
                            },
                          ),
                        ),
                        _buildDivider(isDark),
                        _buildSettingsRow(
                          icon: Icons.language_rounded,
                          iconColor: Colors.blue,
                          title: 'Language',
                          onTap: _showLanguagePicker,
                          trailing: ValueListenableBuilder<String>(
                            valueListenable: AppTranslations.currentLocale,
                            builder: (context, locale, _) {
                              String display = 'English';
                              if (locale == 'hi') display = 'हिंदी';
                              if (locale == 'gu') display = 'ગુજરાતી';
                              return Row(
                                children: [
                                  Text(display, style: const TextStyle(fontSize: 15, color: Colors.grey)),
                                  const SizedBox(width: 4),
                                  const Icon(CupertinoIcons.chevron_right, size: 16, color: Colors.grey),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Resources Group
                    _buildSectionHeader('RESOURCES'),
                    _buildSettingsGroup(
                      isDark: isDark,
                      children: [
                        _buildSettingsRow(
                          icon: Icons.help_outline_rounded,
                          iconColor: Colors.green,
                          title: 'App Guide',
                          onTap: _showAppGuide,
                          trailing: const Icon(CupertinoIcons.chevron_right, size: 16, color: Colors.grey),
                        ),
                        _buildDivider(isDark),
                        _buildSettingsRow(
                          icon: Icons.privacy_tip_rounded,
                          iconColor: Colors.orange,
                          title: 'Privacy Policy',
                          onTap: _openPrivacyPolicy,
                          trailing: const Icon(CupertinoIcons.chevron_right, size: 16, color: Colors.grey),
                        ),
                        _buildDivider(isDark),
                        _buildSettingsRow(
                          icon: Icons.description_rounded,
                          iconColor: Colors.redAccent,
                          title: 'Terms & Conditions',
                          onTap: _openTerms,
                          trailing: const Icon(CupertinoIcons.chevron_right, size: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),

                    // Data Management & Security Group
                    _buildSectionHeader('DATA MANAGEMENT & SECURITY'),
                    _buildSettingsGroup(
                      isDark: isDark,
                      children: [
                        _buildSettingsRow(
                          icon: Icons.security_rounded,
                          iconColor: Colors.deepOrange,
                          title: 'Data Security',
                          onTap: _openDataSecurity,
                          trailing: const Icon(CupertinoIcons.chevron_right, size: 16, color: Colors.grey),
                        ),
                        _buildDivider(isDark),
                        _buildSettingsRow(
                          icon: Icons.shield_rounded,
                          iconColor: Colors.green,
                          title: 'Check Backup Status',
                          onTap: _openBackupStatus,
                          trailing: const Icon(CupertinoIcons.chevron_right, size: 16, color: Colors.grey),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Backup & Restore History Group
                    _buildSectionHeader('BACKUP & RESTORE HISTORY'),
                    _isLoadingLogs 
                        ? const CircularProgressIndicator()
                        : _buildSettingsGroup(
                            isDark: isDark,
                            children: [
                              _buildSettingsRow(
                                icon: Icons.cloud_upload_rounded,
                                iconColor: Colors.blueAccent,
                                title: 'Last Backup',
                                onTap: () => _showHistoryLogs('Backup', _backupLogs),
                                trailing: Row(
                                  children: [
                                    Text(
                                      _backupLogs.isNotEmpty ? DateFormat('MMM d').format(DateTime.tryParse(_backupLogs.first.date) ?? DateTime.now()) : 'Never',
                                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(CupertinoIcons.chevron_right, size: 16, color: Colors.grey),
                                  ],
                                ),
                              ),
                              _buildDivider(isDark),
                              _buildSettingsRow(
                                icon: Icons.cloud_download_rounded,
                                iconColor: Colors.green,
                                title: 'Last Load',
                                onTap: () => _showHistoryLogs('Load', _loadLogs),
                                trailing: Row(
                                  children: [
                                    Text(
                                      _loadLogs.isNotEmpty ? DateFormat('MMM d').format(DateTime.tryParse(_loadLogs.first.date) ?? DateTime.now()) : 'Never',
                                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(CupertinoIcons.chevron_right, size: 16, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ],
                          ),

                    const SizedBox(height: 32),

                    // About App Group
                    _buildSectionHeader('ABOUT APP'),
                    _buildSettingsGroup(
                      isDark: isDark,
                      children: [
                        _buildSettingsRow(
                          icon: Icons.info_outline_rounded,
                          iconColor: Colors.blueGrey,
                          title: 'About Jamna Stone',
                          onTap: _openAboutApp,
                          trailing: const Icon(CupertinoIcons.chevron_right, size: 16, color: Colors.grey),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Support Group
                    _buildSectionHeader('SUPPORT'),
                    _buildSettingsGroup(
                      isDark: isDark,
                      children: [
                        _buildSettingsRow(
                          icon: Icons.contact_support_rounded,
                          iconColor: Colors.purpleAccent,
                          title: 'Contact Developer',
                          onTap: _openSupport,
                          trailing: const Icon(CupertinoIcons.chevron_right, size: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                    
                    // Modern App Footer
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? Colors.grey.shade900 : Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            ),
                            child: const Text('🪨', style: TextStyle(fontSize: 32)),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Jamna Stone',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Your Smart Marble & Granite Assistant ✨',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.verified_user_rounded, size: 16, color: isDark ? Colors.green.shade400 : Colors.green.shade600),
                              const SizedBox(width: 6),
                              Text(
                                '100% SECURE & LOCAL',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  color: isDark ? Colors.green.shade400 : Colors.green.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Version 1.0.2',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Made with ❤️ in India 🇮🇳',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 100), // padding for bottom nav
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsGroup({required bool isDark, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingsRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: isDark ? Colors.white12 : Colors.black12,
      ),
    );
  }
}

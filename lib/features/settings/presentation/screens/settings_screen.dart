import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:slab_count/main.dart';
import 'package:slab_count/core/localization/app_translations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
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

  void _showPolicyDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Text(content, style: const TextStyle(height: 1.5)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAppGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Text(
                'app_guide'.tr,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  children: [
                    _buildGuideItem(Icons.add_circle_outline, 'guide_1'.tr),
                    _buildGuideItem(Icons.edit_document, 'guide_2'.tr),
                    _buildGuideItem(Icons.layers_outlined, 'guide_3'.tr),
                    _buildGuideItem(Icons.format_list_numbered, 'guide_4'.tr),
                    _buildGuideItem(Icons.view_carousel_outlined, 'guide_5'.tr),
                    _buildGuideItem(Icons.history_rounded, 'guide_6'.tr),
                    _buildGuideItem(Icons.share_rounded, 'guide_7'.tr),
                    _buildGuideItem(Icons.inventory_2_rounded, 'guide_8'.tr),
                    _buildGuideItem(Icons.touch_app_rounded, 'guide_9'.tr),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuideItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, height: 1.4),
            ),
          ),
        ],
      ),
    );
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
                    // Header Area
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white12 : Colors.blue.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.settings_suggest_rounded, size: 48, color: isDark ? Colors.white : primaryColor),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Preferences & Setup',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Customize your Jamna Stone experience.',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Developer Profile Card
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor.withOpacity(0.8), primaryColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
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
                            child: Center(
                              child: Text(
                                'PP',
                                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor),
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
                    const SizedBox(height: 32),

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
                          onTap: () => _showPolicyDialog('Privacy Policy', 'Your privacy is important to us. All your data is stored locally on your device and is never uploaded to our servers without your explicit permission when generating backups. We do not track or sell your personal information.'),
                          trailing: const Icon(CupertinoIcons.chevron_right, size: 16, color: Colors.grey),
                        ),
                        _buildDivider(isDark),
                        _buildSettingsRow(
                          icon: Icons.description_rounded,
                          iconColor: Colors.redAccent,
                          title: 'Terms & Conditions',
                          onTap: () => _showPolicyDialog('Terms & Conditions', 'By using the Jamna Stone app, you agree to our terms. This app is provided "as is" without warranty. The developers are not liable for any miscalculations or data loss. We highly recommend using the Backup feature regularly to secure your data.'),
                          trailing: const Icon(CupertinoIcons.chevron_right, size: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Pro Footer
                    Center(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shield_rounded, size: 16, color: isDark ? Colors.white38 : Colors.black38),
                              const SizedBox(width: 6),
                              Text(
                                '100% SECURE & LOCAL',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Jamna Stone v1.0.0',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Crafted with ❤️ in India',
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

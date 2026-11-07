import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/pwa_install.dart';

class PwaInstallHelper {
  static bool _hasPromptedThisSession = false;

  static const String playStoreUrl = 
      'https://play.google.com/store/apps/details?src=AppAgg.com&id=com.jamna.stone&referrer=utm_source%3DAppAgg.com%26utm_medium%3Dreferral%26utm_campaign%3DAppAgg';

  /// Automatically triggers the install pop-up dialog when the app loads on Web
  static Future<void> checkAndPromptOnLoad(BuildContext context) async {
    if (!kIsWeb) return;
    if (isPwaStandalone()) return;
    if (_hasPromptedThisSession) return;
    _hasPromptedThisSession = true;

    // Small delay so the home screen renders cleanly first
    await Future.delayed(const Duration(milliseconds: 900));
    if (!context.mounted) return;

    showInstallGuide(context);
  }

  /// Opens the official Google Play Store page
  static Future<void> openPlayStore() async {
    final uri = Uri.parse(playStoreUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  /// Shows the install pop-up dialog tailored to iPhone, Android, or PC
  static void showInstallGuide(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1E2230) : Colors.white,
        child: Container(
          width: 440,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Header with App Icon and Title
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white24 : const Color(0xFFE2E8F0), 
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/icone.jpeg',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Jamna Stone',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: isAndroid 
                                    ? const Color(0xFF01875F).withOpacity(0.15)
                                    : Colors.blueAccent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isIOS ? 'iPhone' : (isAndroid ? 'Play Store' : 'PC App'),
                                style: TextStyle(
                                  fontSize: 10, 
                                  fontWeight: FontWeight.bold, 
                                  color: isAndroid ? const Color(0xFF01875F) : Colors.blueAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isIOS 
                              ? 'Add to iPhone Home Screen' 
                              : (isAndroid ? 'Install from Google Play Store' : 'Install for Offline Access'),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Description
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isAndroid 
                      ? const Color(0xFF01875F).withOpacity(0.08)
                      : (isDark ? Colors.white.withOpacity(0.05) : Colors.blue.withOpacity(0.06)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      isAndroid ? Icons.shop_rounded : Icons.offline_bolt_rounded, 
                      color: isAndroid ? const Color(0xFF01875F) : Colors.amber, 
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isIOS 
                            ? 'Run full-screen without Safari browser bars with 100% offline data.'
                            : (isAndroid 
                                ? 'Download the official Android app directly from Google Play Store.' 
                                : 'Install on your PC for instant desktop launch and offline calculations.'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Step-by-Step Instructions or Play Store Highlights
              if (isIOS) ...[
                _buildStepCard(
                  step: 1,
                  icon: Icons.ios_share_rounded,
                  title: 'Tap the Share Button',
                  desc: 'Tap the Share icon at the bottom of Safari.',
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _buildStepCard(
                  step: 2,
                  icon: Icons.add_box_outlined,
                  title: 'Select "Add to Home Screen"',
                  desc: 'Scroll down the menu and tap "+ Add to Home Screen".',
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _buildStepCard(
                  step: 3,
                  icon: Icons.check_circle_outline_rounded,
                  title: 'Tap "Add"',
                  desc: 'Tap Add in the top-right corner. The app is installed!',
                  isDark: isDark,
                ),
              ] else if (isAndroid) ...[
                _buildFeatureCard(
                  icon: Icons.verified_user_rounded,
                  title: 'Official Google Play Release',
                  desc: 'Verified by Google Play Protect with automatic updates.',
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _buildFeatureCard(
                  icon: Icons.sd_storage_rounded,
                  title: 'Permanent Device Storage',
                  desc: 'All data saved to internal storage with offline backups.',
                  isDark: isDark,
                ),
              ] else ...[
                _buildStepCard(
                  step: 1,
                  icon: Icons.download_for_offline_rounded,
                  title: 'Click "Install App Now"',
                  desc: 'Installs Jamna Stone as a native desktop window on PC/Laptop.',
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _buildStepCard(
                  step: 2,
                  icon: Icons.open_in_browser_rounded,
                  title: 'Or check Address Bar',
                  desc: 'Click the Install icon (⊞ or ⬇) at the top-right of your browser address bar.',
                  isDark: isDark,
                ),
              ],
              const SizedBox(height: 24),

              // Action Buttons
              if (isAndroid) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    openPlayStore();
                  },
                  icon: const Icon(Icons.shop_two_rounded, size: 20),
                  label: const Text('Get it on Google Play', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF01875F), // Google Play Green
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 1,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await triggerPwaInstall();
                  },
                  icon: const Icon(Icons.install_mobile_rounded, size: 18),
                  label: const Text('Or Install as Web App', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white70 : Colors.black87,
                    side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ] else if (!isIOS) ...[
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await triggerPwaInstall();
                  },
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Install App Now', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ],
              const SizedBox(height: 8),

              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                  foregroundColor: isDark ? Colors.white60 : Colors.black54,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(
                  isIOS ? 'Got it / Continue in Browser' : 'Continue in Browser',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildStepCard({
    required int step,
    required IconData icon,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$step',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: Colors.blueAccent),
                    const SizedBox(width: 6),
                    Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFBBF7D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF01875F).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: const Color(0xFF01875F)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PwaInstallBanner extends StatefulWidget {
  const PwaInstallBanner({super.key});

  @override
  State<PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends State<PwaInstallBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || _dismissed || isPwaStandalone()) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;

    final String title = isIOS 
        ? 'Add Jamna Stone to iPhone' 
        : (isAndroid ? 'Install from Google Play Store' : 'Install on PC / Desktop');

    final String subtitle = isIOS 
        ? 'Run full-screen with offline permanent backups' 
        : (isAndroid ? 'Get official app with native performance' : 'Get 1-click desktop access & offline calculations');

    final Color primaryBtnColor = isAndroid ? const Color(0xFF01875F) : Colors.blueAccent;
    final String btnText = isIOS ? 'How to Add' : (isAndroid ? 'Play Store' : 'Install');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : (isAndroid 
                  ? [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)]
                  : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)]),
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryBtnColor.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: primaryBtnColor.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black12, width: 1),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/images/icone.jpeg', fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              if (isAndroid) {
                PwaInstallHelper.openPlayStore();
              } else {
                PwaInstallHelper.showInstallGuide(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBtnColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text(btnText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 18, color: isDark ? Colors.white54 : Colors.black45),
            onPressed: () => setState(() => _dismissed = true),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }
}

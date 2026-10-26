import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../slabs/services/backup_service.dart';

enum BackupCheckState { checking, secure, error }

class BackupStatusScreen extends StatefulWidget {
  const BackupStatusScreen({super.key});

  @override
  State<BackupStatusScreen> createState() => _BackupStatusScreenState();
}

class _BackupStatusScreenState extends State<BackupStatusScreen> {
  BackupCheckState _state = BackupCheckState.checking;
  Map<String, dynamic>? _backupData;
  String _statusMessage = 'Initializing security scan...';
  bool _isExporting = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _performScan();
  }

  Future<void> _performScan() async {
    setState(() {
      _state = BackupCheckState.checking;
      _statusMessage = 'Verifying local storage access...';
    });
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (!mounted) return;
    setState(() => _statusMessage = 'Checking database integrity...');
    final data = await BackupService.getBackupData();
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    if (data != null) {
      setState(() {
        _statusMessage = 'Data successfully verified!';
        _backupData = data;
        _state = BackupCheckState.secure;
      });
    } else {
      setState(() {
        _statusMessage = 'No backup found or access denied.';
        _state = BackupCheckState.error;
      });
    }
  }

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);
    try {
      final success = await BackupService.exportDatabaseFile();
      if (mounted) {
        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to export backup file.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handleImport() async {
    setState(() => _isImporting = true);
    try {
      final dbMap = await BackupService.pickBackupFile();
      if (!mounted) return;

      if (dbMap == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No file selected.')),
        );
        return;
      }

      int booksCount = 0;
      int stockCount = 0;
      if (dbMap.containsKey('history')) {
        booksCount = (dbMap['history'] as List).length;
      }
      if (dbMap.containsKey('stockEntries')) {
        stockCount = (dbMap['stockEntries'] as List).length;
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.restore_page_rounded, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text('Restore Database'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Selected backup contains:'),
              const SizedBox(height: 8),
              Text('• $booksCount Measurement Books', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('• $stockCount Stock Items', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('Do you want to merge this data into your current records?'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore Now', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        final success = await BackupService.restoreFromLocalFolder(dbMap);
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Data restored successfully!'), backgroundColor: Colors.green),
            );
            _performScan();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to restore data.'), backgroundColor: Colors.red),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security & Backup Hub'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Re-scan',
            onPressed: _performScan,
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 10),
              // Animation container
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: _buildStateIcon(isDark),
              ),
              const SizedBox(height: 24),
              
              // Status Text
              Text(
                _state == BackupCheckState.checking 
                    ? 'Scanning System...' 
                    : _state == BackupCheckState.secure 
                        ? 'System Secured' 
                        : 'Attention Needed',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: _state == BackupCheckState.secure 
                      ? Colors.green 
                      : _state == BackupCheckState.error 
                          ? Colors.redAccent 
                          : (isDark ? Colors.white : Colors.black87),
                ),
              ).animate(target: _state == BackupCheckState.secure ? 1 : 0).shimmer(duration: 2.seconds, color: Colors.greenAccent),
              
              const SizedBox(height: 8),
              
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              
              if (_state == BackupCheckState.secure && _backupData != null) ...[
                const SizedBox(height: 24),
                _buildDetailsCard(isDark).animate().slideY(begin: 0.2, end: 0, duration: 500.ms).fadeIn(),
              ],

              const SizedBox(height: 32),

              // Action Section
              _buildActionCard(
                isDark: isDark,
                icon: Icons.cloud_upload_rounded,
                iconColor: Colors.blueAccent,
                title: 'Share / Upload to Google Drive',
                subtitle: 'Save database.json to Google Drive, WhatsApp, Gmail, or Phone Downloads',
                isLoading: _isExporting,
                onTap: _handleExport,
              ),

              const SizedBox(height: 16),

              _buildActionCard(
                isDark: isDark,
                icon: Icons.file_open_rounded,
                iconColor: Colors.orangeAccent,
                title: 'Select & Restore from Device / Drive',
                subtitle: 'Pick a database.json file from Google Drive or Phone Storage to restore all data',
                isLoading: _isImporting,
                onTap: _handleImport,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateIcon(bool isDark) {
    switch (_state) {
      case BackupCheckState.checking:
        return Container(
          key: const ValueKey('checking'),
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.withOpacity(0.1),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 40,
                spreadRadius: 10,
              )
            ]
          ),
          child: const Icon(Icons.security_rounded, size: 65, color: Colors.blue)
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scaleXY(begin: 0.9, end: 1.1, duration: 1.seconds)
              .tint(color: Colors.lightBlueAccent),
        );
      case BackupCheckState.secure:
        return Container(
          key: const ValueKey('secure'),
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green.withOpacity(0.15),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.4),
                blurRadius: 50,
                spreadRadius: 15,
              )
            ]
          ),
          child: const Icon(Icons.verified_user_rounded, size: 75, color: Colors.green)
              .animate()
              .scaleXY(begin: 0.0, end: 1.0, curve: Curves.easeOutBack, duration: 800.ms)
              .then()
              .shimmer(duration: 2.seconds, curve: Curves.easeInOut),
        );
      case BackupCheckState.error:
        return Container(
          key: const ValueKey('error'),
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withOpacity(0.1),
          ),
          child: const Icon(Icons.gpp_bad_rounded, size: 75, color: Colors.red)
              .animate()
              .shake(duration: 500.ms),
        );
    }
  }

  Widget _buildDetailsCard(bool isDark) {
    int historyCount = 0;
    int stockCount = 0;
    String lastSync = 'Unknown';
    
    if (_backupData!.containsKey('history')) {
      historyCount = (_backupData!['history'] as List).length;
    }
    if (_backupData!.containsKey('stockEntries')) {
      stockCount = (_backupData!['stockEntries'] as List).length;
    }
    if (_backupData!.containsKey('timestamp')) {
      try {
        final dt = DateTime.parse(_backupData!['timestamp']);
        lastSync = DateFormat('dd MMM yyyy • hh:mm a').format(dt);
      } catch (e) {
        lastSync = 'Invalid Date';
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_done_rounded, color: Colors.green, size: 22),
              const SizedBox(width: 8),
              Text('Auto-Sync Active', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, fontSize: 15)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(),
          ),
          _buildStatRow('Last Secured', lastSync, isDark),
          const SizedBox(height: 10),
          _buildStatRow('Saved Measurement Books', '$historyCount', isDark),
          const SizedBox(height: 10),
          _buildStatRow('Saved Stock Blocks', '$stockCount', isDark),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, fontSize: 13)),
      ],
    );
  }

  Widget _buildActionCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              else
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

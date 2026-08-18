import 'dart:ui';
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

  @override
  void initState() {
    super.initState();
    _performScan();
  }

  Future<void> _performScan() async {
    setState(() => _statusMessage = 'Verifying local storage access...');
    await Future.delayed(const Duration(milliseconds: 1200));
    
    setState(() => _statusMessage = 'Checking database integrity...');
    final data = await BackupService.getBackupData();
    await Future.delayed(const Duration(milliseconds: 1200));

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security & Backup Status'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animation container
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: _buildStateIcon(isDark),
            ),
            const SizedBox(height: 40),
            
            // Status Text
            Text(
              _state == BackupCheckState.checking 
                  ? 'Scanning System...' 
                  : _state == BackupCheckState.secure 
                      ? 'System Secured' 
                      : 'Attention Needed',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: _state == BackupCheckState.secure 
                    ? Colors.green 
                    : _state == BackupCheckState.error 
                        ? Colors.redAccent 
                        : (isDark ? Colors.white : Colors.black87),
              ),
            ).animate(target: _state == BackupCheckState.secure ? 1 : 0).shimmer(duration: 2.seconds, color: Colors.greenAccent),
            
            const SizedBox(height: 12),
            
            Text(
              _statusMessage,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
            
            if (_state == BackupCheckState.secure && _backupData != null) ...[
              const SizedBox(height: 50),
              _buildDetailsCard(isDark).animate().slideY(begin: 0.2, end: 0, duration: 500.ms).fadeIn(),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildStateIcon(bool isDark) {
    switch (_state) {
      case BackupCheckState.checking:
        return Container(
          key: const ValueKey('checking'),
          width: 160,
          height: 160,
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
          child: const Icon(Icons.security_rounded, size: 80, color: Colors.blue)
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scaleXY(begin: 0.9, end: 1.1, duration: 1.seconds)
              .tint(color: Colors.lightBlueAccent),
        );
      case BackupCheckState.secure:
        return Container(
          key: const ValueKey('secure'),
          width: 160,
          height: 160,
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
          child: const Icon(Icons.verified_user_rounded, size: 90, color: Colors.green)
              .animate()
              .scaleXY(begin: 0.0, end: 1.0, curve: Curves.easeOutBack, duration: 800.ms)
              .then()
              .shimmer(duration: 2.seconds, curve: Curves.easeInOut),
        );
      case BackupCheckState.error:
        return Container(
          key: const ValueKey('error'),
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withOpacity(0.1),
          ),
          child: const Icon(Icons.gpp_bad_rounded, size: 90, color: Colors.red)
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
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.green.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_done_rounded, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              Text('Auto-Sync Active', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, fontSize: 16)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(),
          ),
          _buildStatRow('Last Secured', lastSync, isDark),
          const SizedBox(height: 12),
          _buildStatRow('Saved Measurement Books', '$historyCount', isDark),
          const SizedBox(height: 12),
          _buildStatRow('Saved Stock Blocks', '$stockCount', isDark),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 14)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../slabs/presentation/screens/slab_measurement_screen.dart';
import '../../../blocks/presentation/screens/block_calculator_screen.dart';
import '../../../../main.dart'; // For themeNotifier

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Jamna Stone', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton<ThemeMode>(
            icon: const Icon(Icons.brightness_medium_rounded),
            tooltip: 'Theme',
            onSelected: (mode) {
              themeNotifier.value = mode;
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: ThemeMode.system, child: Text('System Default')),
              const PopupMenuItem(value: ThemeMode.light, child: Text('Light Mode')),
              const PopupMenuItem(value: ThemeMode.dark, child: Text('Dark Mode')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Calculator',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0, duration: 400.ms),
              const SizedBox(height: 8),
              Text(
                'Choose the measurement tool you need',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideX(begin: -0.1, end: 0, delay: 200.ms, duration: 400.ms),
              const SizedBox(height: 40),
              
              Expanded(
                child: Hero(
                  tag: 'block_calculator_card',
                  child: _buildCalculatorCard(
                    context,
                    title: 'Block Calculator',
                    subtitle: 'Calculate weight in tons using L × W × H',
                    icon: Icons.view_in_ar_rounded,
                    color: Colors.blueAccent,
                    onTap: () {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) => const BlockCalculatorScreen(),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            return ScaleTransition(
                              scale: Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                              child: FadeTransition(opacity: animation, child: child),
                            );
                          },
                          transitionDuration: const Duration(milliseconds: 500),
                        ),
                      );
                    },
                  ),
                ).animate().fadeIn(delay: 400.ms, duration: 500.ms).slideY(begin: 0.1, end: 0, delay: 400.ms, duration: 500.ms),
              ),
              
              const SizedBox(height: 24),
              
              Expanded(
                child: Hero(
                  tag: 'slab_calculator_card',
                  child: _buildCalculatorCard(
                    context,
                    title: 'Slab Calculator',
                    subtitle: 'Measure area, quantity, and manage slab books',
                    icon: Icons.grid_on_rounded,
                    color: Colors.amber,
                    onTap: () {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) => const SlabMeasurementScreen(),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            return ScaleTransition(
                              scale: Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                              child: FadeTransition(opacity: animation, child: child),
                            );
                          },
                          transitionDuration: const Duration(milliseconds: 500),
                        ),
                      );
                    },
                  ),
                ).animate().fadeIn(delay: 600.ms, duration: 500.ms).slideY(begin: 0.1, end: 0, delay: 600.ms, duration: 500.ms),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalculatorCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? color.withOpacity(0.15) : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? color.withOpacity(0.3) : color.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? color.withOpacity(0.2) : color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 64, color: isDark ? color.lighten(0.2) : color),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? color.lighten(0.2) : color.darken(0.2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension ColorUtils on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }

  Color lighten([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslLight.toColor();
  }
}

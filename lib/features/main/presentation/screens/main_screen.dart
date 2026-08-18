import 'package:flutter/material.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../slabs/presentation/screens/slab_measurement_screen.dart';
import '../../../slabs/presentation/screens/history_screen.dart';
import '../../../stock/presentation/screens/stock_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../slabs/data/models/slab_models.dart';
import '../../../../core/localization/app_translations.dart';

class MainScreen extends StatefulWidget {
  final SlabBook? initialBook;
  
  const MainScreen({super.key, this.initialBook});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  SlabBook? _activeBook;
  UniqueKey _measurementKey = UniqueKey(); // Used to force reload when changing books
  UniqueKey _historyKey = UniqueKey(); // Force reload when switching to history tab
  UniqueKey _settingsKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    if (widget.initialBook != null) {
      _currentIndex = 1;
      _activeBook = widget.initialBook;
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      if (index == 2) {
        _historyKey = UniqueKey();
      } else if (index == 4) {
        _settingsKey = UniqueKey();
      }
      _currentIndex = index;
    });
  }

  void _openBookFromHistory(SlabBook book) {
    setState(() {
      _activeBook = book;
      _measurementKey = UniqueKey();
      _currentIndex = 1; // Switch to measurement tab
    });
  }

  void _startNewMeasurement() {
    setState(() {
      _activeBook = null;
      _measurementKey = UniqueKey();
      _currentIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvoked: (didPop) {
        if (!didPop && _currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
        }
      },
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: _currentIndex,
          children: [
            HomeScreen(
              onStartMeasurement: _startNewMeasurement,
              onGoToStock: () => _onTabTapped(3),
              isActive: _currentIndex == 0,
            ),
            SlabMeasurementScreen(
              key: _measurementKey, 
              loadedBook: _activeBook,
              onBackTapped: () {
                setState(() {
                  _currentIndex = 0; // Go to Home
                  _activeBook = null;
                });
              },
            ),
            HistoryScreen(
              key: _historyKey, 
              onBookOpened: _openBookFromHistory, 
              onNewBook: _startNewMeasurement
            ),
            StockScreen(
              isActive: _currentIndex == 3,
            ),
            SettingsScreen(key: _settingsKey),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? const Color(0xFF1E1E1E) 
                  : Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_rounded, 'home'.tr),
                _buildNavItem(1, Icons.calculate_rounded, 'measure'.tr),
                _buildNavItem(2, Icons.history_rounded, 'history'.tr),
                _buildNavItem(3, Icons.inventory_2_rounded, 'Stock'),
                _buildNavItem(4, Icons.settings_rounded, 'Settings'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 16 : 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.blue.withOpacity(0.15) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected 
                  ? Colors.blue 
                  : Colors.grey.shade500,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

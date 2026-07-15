import 'package:flutter/material.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../slabs/presentation/screens/slab_measurement_screen.dart';
import '../../../slabs/presentation/screens/history_screen.dart';
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
        body: IndexedStack(
          index: _currentIndex,
          children: [
            HomeScreen(onStartMeasurement: _startNewMeasurement),
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
            HistoryScreen(key: _historyKey, onBookOpened: _openBookFromHistory, onNewBook: _startNewMeasurement),
          ],
        ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          backgroundColor: Theme.of(context).cardColor,
          selectedItemColor: AppColors.amber,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_rounded),
              label: 'home'.tr,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.calculate_rounded),
              label: 'measure'.tr,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.history_rounded),
              label: 'history'.tr,
            ),
          ],
        ),
      ),
    ));
  }
}

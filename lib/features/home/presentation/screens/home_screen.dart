import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../slabs/services/storage_service.dart';
import '../../../slabs/data/models/slab_models.dart';
import '../../../slabs/presentation/screens/slab_measurement_screen.dart';
import '../../../../main.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onStartMeasurement;
  
  const HomeScreen({super.key, required this.onStartMeasurement});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _totalBooks = 0;
  double _totalAreaSaved = 0.0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final history = await StorageService.loadHistory();
    double area = 0.0;
    for (var book in history) {
      for (var slab in book.slabs) {
        area += slab.getArea(book.unit);
      }
    }
    if (mounted) {
      setState(() {
        _totalBooks = history.length;
        _totalAreaSaved = area;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Jamna Stone', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: () {
              themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.amberGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.amber.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('App Guide', style: TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  const Text(
                    '1. Tap "Start Measuring" to create a new book.\n'
                    '2. Enter the Book Name and an optional Number Plate.\n'
                    '3. Add Slabs: Enter the length, width, and quantity for each row.\n'
                    '4. The app auto-increments the slab numbers for you.\n'
                    '5. Switch between Card View and Table View for easy data entry.\n'
                    '6. Use the History tab to manage, edit, or export saved books.\n'
                    '7. Export data instantly as PDF or Images, or directly share them.',
                    style: TextStyle(color: Colors.black87, fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: ElevatedButton(
                      onPressed: widget.onStartMeasurement,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_box_rounded),
                          SizedBox(width: 8),
                          Text('Start Measuring', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
          ],
        ),
      ),
    );
  }
}

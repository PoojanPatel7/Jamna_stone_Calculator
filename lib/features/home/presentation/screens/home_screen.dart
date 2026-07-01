import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../slabs/services/storage_service.dart';
import '../../../slabs/data/models/slab_models.dart';
import '../../../slabs/presentation/screens/slab_measurement_screen.dart';
import '../../../../main.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../about/presentation/screens/about_screen.dart';

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
        title: Text('app_title'.tr, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            tooltip: 'Change Language',
            onSelected: (String lang) {
              AppTranslations.currentLocale.value = lang;
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(value: 'en', child: Text('English')),
              const PopupMenuItem<String>(value: 'hi', child: Text('हिंदी')),
              const PopupMenuItem<String>(value: 'gu', child: Text('ગુજરાતી')),
            ],
          ),
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
                  Text('app_guide'.tr, style: const TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  Text(
                    '${'guide_1'.tr}\n'
                    '${'guide_2'.tr}\n'
                    '${'guide_3'.tr}\n'
                    '${'guide_4'.tr}\n'
                    '${'guide_5'.tr}\n'
                    '${'guide_6'.tr}\n'
                    '${'guide_7'.tr}',
                    style: const TextStyle(color: Colors.black87, fontSize: 16, height: 1.5),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_box_rounded),
                          const SizedBox(width: 8),
                          Text('start_measuring'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Text('developed_by'.tr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('Panchasara Poojan', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
                    icon: const Icon(Icons.info_outline, size: 16),
                    label: Text('about_us'.tr),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.grey[300] : Colors.grey[700],
                      side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

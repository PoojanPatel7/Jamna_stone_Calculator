import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/stock_models.dart';
import '../../services/stock_storage_service.dart';
import '../../../../features/slabs/services/storage_service.dart';
import '../../../../features/slabs/data/models/slab_models.dart';
import '../../../../features/slabs/presentation/screens/slab_measurement_screen.dart';
import 'add_stock_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StockScreen extends StatefulWidget {
  final bool isActive;
  
  const StockScreen({
    super.key,
    this.isActive = true,
  });

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  List<StockEntry> _stockEntries = [];
  Map<String, double> _consumedAreaMap = {};
  Map<String, int> _consumedSlabsMap = {};
  Map<String, List<SlabBook>> _linkedBooksMap = {};
  bool _isLoading = true;
  
  String _searchQuery = '';
  String _filterStatus = 'Available';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(StockScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _stockEntries = await StockStorageService.loadStockEntries();
    
    // Calculate consumed stock from history
    try {
      final history = await StorageService.loadHistory();
      _consumedAreaMap.clear();
      _consumedSlabsMap.clear();
      _linkedBooksMap.clear();
      
      for (var book in history) {
        if (book.linkedStockId != null) {
          double area = book.slabs.fold(0.0, (sum, slab) => sum + slab.getArea(book.unit));
          int slabs = book.slabs.where((s) => s.length > 0 || s.width > 0).fold(0, (sum, slab) => sum + slab.quantity);
          
          _consumedAreaMap[book.linkedStockId!] = (_consumedAreaMap[book.linkedStockId!] ?? 0.0) + area;
          _consumedSlabsMap[book.linkedStockId!] = (_consumedSlabsMap[book.linkedStockId!] ?? 0) + slabs;
          
          if (!_linkedBooksMap.containsKey(book.linkedStockId!)) {
            _linkedBooksMap[book.linkedStockId!] = [];
          }
          _linkedBooksMap[book.linkedStockId!]!.add(book);
        }
      }
    } catch (e) {
      // Ignore errors if history fails to load
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Map<String, List<StockEntry>> _getGroupedEntriesByBlockType(String blockType) {
    final Map<String, List<StockEntry>> grouped = {};
    for (var entry in _stockEntries) {
      if (entry.blockTypeName.toLowerCase() == blockType.toLowerCase()) {
        final consumedSlabs = _consumedSlabsMap[entry.id] ?? 0;
        final bool isActuallySold = (entry.totalSlabCount - consumedSlabs) <= 0;

        if (_filterStatus == 'Available' && isActuallySold) continue;
        if (_filterStatus == 'Sold' && !isActuallySold) continue;

        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          if (!entry.blockName.toLowerCase().contains(query) &&
              !entry.blockNumber.toLowerCase().contains(query) &&
              !entry.blockTypeName.toLowerCase().contains(query)) {
            continue;
          }
        }
        if (!grouped.containsKey(entry.blockName)) {
          grouped[entry.blockName] = [];
        }
        grouped[entry.blockName]!.add(entry);
      }
    }
    return grouped;
  }

  bool _isOverviewExpanded = false;

  Widget _buildTopDashboard(String typeName, Map<String, List<StockEntry>> groupedEntries) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    int originalTotalSlabs = 0;
    double originalTotalArea = 0.0;
    int availableSlabs = 0;
    double availableArea = 0.0;
    int totalBlocks = groupedEntries.length;

    for (var entries in groupedEntries.values) {
      for (var e in entries) {
        originalTotalSlabs += e.totalSlabCount;
        originalTotalArea += e.estimatedArea;

        final consumedSlabs = _consumedSlabsMap[e.id] ?? 0;
        final consumedArea = _consumedAreaMap[e.id] ?? 0.0;
        
        availableSlabs += e.totalSlabCount - consumedSlabs;
        availableArea += e.estimatedArea - consumedArea;
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200, width: 1.5),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _isOverviewExpanded,
          onExpansionChanged: (val) {
            setState(() {
              _isOverviewExpanded = val;
            });
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$typeName Overview',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$totalBlocks Blocks',
                  style: TextStyle(color: isDark ? Colors.lightBlueAccent : Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Available Stock',
                      slabs: availableSlabs,
                      area: availableArea,
                      isPrimary: true,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Total Originally Added',
                      slabs: originalTotalSlabs,
                      area: originalTotalArea,
                      isPrimary: false,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fade().slideY(begin: 0.1);
  }

  Widget _buildMetricCard({
    required String title,
    required int slabs,
    required double area,
    required bool isPrimary,
    required bool isDark,
  }) {
    final bgColor = isPrimary 
      ? (isDark ? const Color(0xFF0D47A1).withOpacity(0.3) : const Color(0xFFE3F2FD))
      : (isDark ? Colors.white10 : Colors.grey.shade100);
      
    final textColor = isPrimary 
      ? (isDark ? Colors.lightBlueAccent : Colors.blue.shade800)
      : (isDark ? Colors.white70 : Colors.black54);
      
    final valueColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isPrimary ? (isDark ? Colors.blue.withOpacity(0.3) : Colors.blue.shade200) : Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            '${area.toStringAsFixed(0)} SqFt',
            style: TextStyle(color: valueColor, fontSize: 18, fontWeight: FontWeight.w900, height: 1.1),
          ),
          const SizedBox(height: 2),
          Text(
            '$slabs Slabs',
            style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String blockName, List<StockEntry> entries) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    int originalPolishedSlabs = 0;
    double originalPolishedArea = 0.0;
    int originalUnpolishedSlabs = 0;
    double originalUnpolishedArea = 0.0;

    int availablePolishedSlabs = 0;
    double availablePolishedArea = 0.0;
    int availableUnpolishedSlabs = 0;
    double availableUnpolishedArea = 0.0;

    for (var e in entries) {
      final consumedSlabs = _consumedSlabsMap[e.id] ?? 0;
      final consumedArea = _consumedAreaMap[e.id] ?? 0.0;
      final remainingSlabs = e.totalSlabCount - consumedSlabs;
      final remainingArea = e.estimatedArea - consumedArea;

      if (e.isPolished) {
        originalPolishedSlabs += e.totalSlabCount;
        originalPolishedArea += e.estimatedArea;
        availablePolishedSlabs += remainingSlabs;
        availablePolishedArea += remainingArea;
      } else {
        originalUnpolishedSlabs += e.totalSlabCount;
        originalUnpolishedArea += e.estimatedArea;
        availableUnpolishedSlabs += remainingSlabs;
        availableUnpolishedArea += remainingArea;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200, width: 1.5),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ExpansionTile(
          initiallyExpanded: _searchQuery.isNotEmpty,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.all(20),
          iconColor: Colors.blue,
          collapsedIconColor: isDark ? Colors.white54 : Colors.grey.shade400,
          title: Text(
            blockName,
            style: TextStyle(
              fontWeight: FontWeight.w800, 
              fontSize: 20, 
              letterSpacing: -0.5,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entries.isNotEmpty && entries.first.blockNumber.isNotEmpty)
                Text('#${entries.first.blockNumber}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatBox(
                        title: 'Polished',
                        originalSlabs: originalPolishedSlabs,
                        originalArea: originalPolishedArea,
                        availableSlabs: availablePolishedSlabs,
                        availableArea: availablePolishedArea,
                        color: isDark ? Colors.lightBlueAccent : Colors.blue,
                        bgColor: isDark ? Colors.blue.withOpacity(0.1) : const Color(0xFFE3F2FD),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatBox(
                        title: 'Unpolished',
                        originalSlabs: originalUnpolishedSlabs,
                        originalArea: originalUnpolishedArea,
                        availableSlabs: availableUnpolishedSlabs,
                        availableArea: availableUnpolishedArea,
                        color: isDark ? Colors.brown.shade300 : const Color(0xFF8D6E63),
                        bgColor: isDark ? Colors.brown.withOpacity(0.1) : const Color(0xFFEFEBE9),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          children: [
            Container(
              color: isDark ? Colors.black12 : Colors.grey.shade50,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: entries.asMap().entries.map((e) {
                  final index = e.key;
                  final entry = e.value;
                  final isPolished = entry.isPolished;
                  final primaryColor = isPolished 
                      ? (isDark ? Colors.lightBlueAccent : const Color(0xFF1976D2)) 
                      : (isDark ? Colors.brown.shade300 : const Color(0xFF795548));
                  
                  final consumedSlabs = _consumedSlabsMap[entry.id] ?? 0;
                  final consumedArea = _consumedAreaMap[entry.id] ?? 0.0;
                  final int remainingSlabs = entry.totalSlabCount - consumedSlabs;
                  final double remainingArea = entry.estimatedArea - consumedArea;
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                      border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: isPolished ? primaryColor : Colors.orange,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Text(
                                      entry.blockNumber.isNotEmpty 
                                          ? 'Block ${index + 1} • #${entry.blockNumber}' 
                                          : 'Block ${index + 1}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800, 
                                        color: isDark ? Colors.white : Colors.black87, 
                                        fontSize: 16,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white10 : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isPolished ? 'Polished' : 'Unpolished',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600, 
                                          color: isDark ? Colors.white70 : Colors.grey.shade700, 
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    if (entry.isSynced)
                                      const Icon(Icons.cloud_done_rounded, color: Colors.green, size: 16)
                                    else
                                      const Icon(Icons.sync_problem_rounded, color: Colors.orange, size: 16),
                                    if ((entry.totalSlabCount - (_consumedSlabsMap[entry.id] ?? 0)) <= 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text('SOLD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AddStockScreen(
                                            entryToEdit: entry,
                                            onSave: () {
                                              Navigator.pop(context);
                                              _loadData();
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      child: Icon(Icons.edit_rounded, color: isDark ? Colors.white54 : Colors.black45, size: 18),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => _confirmDelete(entry),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Available Slabs', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 11, fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 2),
                                          Text('$remainingSlabs', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16, fontWeight: FontWeight.w900)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Available Area', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 11, fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 2),
                                          Text('${remainingArea.toStringAsFixed(1)} sqft', style: TextStyle(color: primaryColor, fontSize: 16, fontWeight: FontWeight.w900)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0),
                                  child: Divider(height: 1, thickness: 1),
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Original Slabs', style: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 2),
                                          Text('${entry.totalSlabCount}', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13, fontWeight: FontWeight.w700)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Original Area', style: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 2),
                                          Text('${entry.estimatedArea.toStringAsFixed(1)} sqft', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13, fontWeight: FontWeight.w700)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (_linkedBooksMap.containsKey(entry.id) && _linkedBooksMap[entry.id]!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Text('Linked Measurement Sheets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                            const SizedBox(height: 8),
                            ..._linkedBooksMap[entry.id]!.map((book) {
                              final slabs = book.slabs.where((s) => s.length > 0 || s.width > 0).fold(0, (sum, slab) => sum + slab.quantity);
                              final area = book.slabs.fold(0.0, (sum, slab) => sum + slab.getArea(book.unit));
                              final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(book.date);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.blue.withOpacity(0.05) : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade100),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  title: Text(book.name, style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
                                  subtitle: Text('$slabs Slabs • ${area.toStringAsFixed(1)} ${book.unit}\n$dateStr', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54, height: 1.4)),
                                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.blueAccent : Colors.blue.shade700),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SlabMeasurementScreen(
                                          loadedBook: book,
                                          onBackTapped: () {
                                            Navigator.pop(context);
                                            _loadData();
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            }).toList(),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    ).animate().fade().slideY(begin: 0.05, duration: 300.ms);
  }

  Widget _buildStatBox({
    required String title, 
    required int originalSlabs, 
    required double originalArea, 
    required int availableSlabs, 
    required double availableArea, 
    required Color color, 
    required Color bgColor, 
    required bool isDark
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 8, color: color),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 12),
          Text('Available', style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey.shade600, fontWeight: FontWeight.w600)),
          Text('${availableArea.toStringAsFixed(0)} SqFt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
          Text('$availableSlabs slabs', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Original Total', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey.shade500, fontWeight: FontWeight.w600)),
          Text('${originalArea.toStringAsFixed(0)} SqFt', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white70 : Colors.black54)),
          Text('$originalSlabs slabs', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(StockEntry entry) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Record?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to permanently delete this stock entry?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await StockStorageService.deleteStockEntry(entry.id);
      _loadData();
    }
  }

  Widget _buildListContent(String blockType, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final grouped = _getGroupedEntriesByBlockType(blockType);
    final blockKeys = grouped.keys.toList()..sort();

    return Column(
      children: [
        // Top Dashboard
        if (grouped.isNotEmpty)
          _buildTopDashboard(title, grouped),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search Block Name, Number, Type...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: isDark ? Colors.white10 : Colors.grey.shade200,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _filterStatus,
                    dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    icon: const Icon(Icons.filter_list_rounded, size: 20),
                    items: const [
                      DropdownMenuItem(value: 'Available', child: Text('Available', style: TextStyle(fontSize: 14))),
                      DropdownMenuItem(value: 'Sold', child: Text('Sold', style: TextStyle(fontSize: 14))),
                      DropdownMenuItem(value: 'All', child: Text('All', style: TextStyle(fontSize: 14))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _filterStatus = val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ).animate().fade().slideY(begin: -0.1),
        ),

        // Empty State
        if (blockKeys.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.inventory_2_rounded, size: 64, color: isDark ? Colors.white24 : Colors.grey.shade300),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No $title Stock Found',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try adjusting your search or add new inventory.',
                    style: TextStyle(fontSize: 15, color: isDark ? Colors.white54 : Colors.grey.shade500),
                  ),
                ],
              ).animate().fade().scale(duration: 400.ms),
            ),
          )
        else
          // Blocks List
          Expanded(
            child: ListView.builder(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(top: 8, bottom: 100),
              itemCount: blockKeys.length,
              itemBuilder: (context, index) {
                final blockName = blockKeys[index];
                final entries = grouped[blockName] ?? [];
                return _buildSummaryCard(blockName, entries);
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasMultipleTypes = _stockEntries.any((e) => e.blockTypeName.toLowerCase() == 'granite') && 
                             _stockEntries.any((e) => e.blockTypeName.toLowerCase() == 'marble');

    // If there is no specific multiple type, we still show tabs but Granite first, or if no stock, just show default
    final showTabs = _stockEntries.isNotEmpty;

    Widget content = Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Inventory', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        bottom: showTabs ? PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              indicator: BoxDecoration(
                color: isDark ? const Color(0xFF252525) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: isDark ? Colors.blue : Colors.black87,
              unselectedLabelColor: isDark ? Colors.white54 : Colors.grey.shade500,
              labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Granite'),
                Tab(text: 'Marble'),
              ],
            ),
          ),
        ) : null,
      ),
      body: showTabs ? TabBarView(
        children: [
          _buildListContent('Granite', 'Granite'),
          _buildListContent('Marble', 'Marble'),
        ],
      ) : _buildListContent('Granite', 'Granite'),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddStockScreen(
                  onSave: () {
                    Navigator.pop(context);
                    _loadData();
                  },
                ),
              ),
            );
          },
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Stock', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ).animate().scale(delay: 200.ms, duration: 400.ms),
      ),
    );
    if (showTabs) {
      return DefaultTabController(
        length: 2,
        child: content,
      );
    }
    return content;
  }
}

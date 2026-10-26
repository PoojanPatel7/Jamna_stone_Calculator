import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/stock_models.dart';
import '../../services/stock_storage_service.dart';
import '../../../../features/slabs/services/storage_service.dart';
import '../../../../features/slabs/data/models/slab_models.dart';
import '../../../../features/slabs/presentation/screens/slab_measurement_screen.dart';
import 'add_stock_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HeightCount {
  final double height;
  final int totalBlocks;
  final int availableBlocks;
  final int totalSlabs;
  final int availableSlabs;
  final double availableArea;

  HeightCount({
    required this.height,
    required this.totalBlocks,
    required this.availableBlocks,
    required this.totalSlabs,
    required this.availableSlabs,
    required this.availableArea,
  });
}

class SizeCount {
  final double height;
  final double width;
  final String label;
  final int totalBlocks;
  final int availableBlocks;
  final int totalSlabs;
  final int availableSlabs;
  final double availableArea;

  SizeCount({
    required this.height,
    required this.width,
    required this.label,
    required this.totalBlocks,
    required this.availableBlocks,
    required this.totalSlabs,
    required this.availableSlabs,
    required this.availableArea,
  });
}

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
  final Map<String, double> _consumedAreaMap = {};
  final Map<String, int> _consumedSlabsMap = {};
  final Map<String, List<SlabBook>> _linkedBooksMap = {};
  bool _isLoading = true;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterStatus = 'Available'; // 'Available', 'Sold', 'All'
  double? _minHeight;
  double? _maxHeight;
  double? _minWidth;
  double? _maxWidth;
  double? _selectedExactHeight;
  String? _selectedExactSize;
  bool _isOverviewExpanded = true;

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatNum(double val) {
    if (val <= 0) return '0';
    return val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(1);
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

  List<String> get _blockTypes {
    final types = _stockEntries.map((e) => e.blockTypeName.trim()).where((t) => t.isNotEmpty).toSet().toList();
    if (types.isEmpty) return ['Granite', 'Marble'];
    if (!types.contains('Granite')) types.insert(0, 'Granite');
    if (!types.contains('Marble')) types.insert(1, 'Marble');
    return types;
  }

  List<HeightCount> _computeHeightCounts(String blockType) {
    final Map<double, List<StockEntry>> map = {};
    for (var entry in _stockEntries) {
      if (entry.blockTypeName.toLowerCase() == blockType.toLowerCase()) {
        if (entry.height > 0) {
          map.putIfAbsent(entry.height, () => []).add(entry);
        }
      }
    }

    final List<HeightCount> result = [];
    final sortedHeights = map.keys.toList()..sort();
    for (var h in sortedHeights) {
      final list = map[h]!;
      int totalSlabs = 0;
      int availSlabs = 0;
      int availBlocks = 0;
      double availArea = 0;

      for (var e in list) {
        totalSlabs += e.totalSlabCount;
        final consumedS = _consumedSlabsMap[e.id] ?? 0;
        final consumedA = _consumedAreaMap[e.id] ?? 0.0;
        final remS = e.totalSlabCount - consumedS;
        final remA = e.estimatedArea - consumedA;
        if (remS > 0) {
          availBlocks++;
          availSlabs += remS;
          availArea += remA;
        }
      }

      result.add(HeightCount(
        height: h,
        totalBlocks: list.length,
        availableBlocks: availBlocks,
        totalSlabs: totalSlabs,
        availableSlabs: availSlabs,
        availableArea: availArea,
      ));
    }
    return result;
  }

  List<SizeCount> _computeSizeCounts(String blockType) {
    final Map<String, List<StockEntry>> map = {};
    final Map<String, ({double h, double w})> dims = {};

    for (var entry in _stockEntries) {
      if (entry.blockTypeName.toLowerCase() == blockType.toLowerCase()) {
        if (entry.height > 0 && entry.width > 0) {
          final key = '${_formatNum(entry.height)} × ${_formatNum(entry.width)}';
          map.putIfAbsent(key, () => []).add(entry);
          dims[key] = (h: entry.height, w: entry.width);
        }
      }
    }

    final List<SizeCount> result = [];
    final sortedKeys = map.keys.toList()..sort();
    for (var key in sortedKeys) {
      final list = map[key]!;
      final dim = dims[key]!;
      int totalSlabs = 0;
      int availSlabs = 0;
      int availBlocks = 0;
      double availArea = 0;

      for (var e in list) {
        totalSlabs += e.totalSlabCount;
        final consumedS = _consumedSlabsMap[e.id] ?? 0;
        final consumedA = _consumedAreaMap[e.id] ?? 0.0;
        final remS = e.totalSlabCount - consumedS;
        final remA = e.estimatedArea - consumedA;
        if (remS > 0) {
          availBlocks++;
          availSlabs += remS;
          availArea += remA;
        }
      }

      result.add(SizeCount(
        height: dim.h,
        width: dim.w,
        label: key,
        totalBlocks: list.length,
        availableBlocks: availBlocks,
        totalSlabs: totalSlabs,
        availableSlabs: availSlabs,
        availableArea: availArea,
      ));
    }
    return result;
  }

  Map<String, List<StockEntry>> _getGroupedEntriesByBlockType(String blockType) {
    final Map<String, List<StockEntry>> grouped = {};
    for (var entry in _stockEntries) {
      if (entry.blockTypeName.toLowerCase() == blockType.toLowerCase()) {
        final consumedSlabs = _consumedSlabsMap[entry.id] ?? 0;
        final bool isActuallySold = (entry.totalSlabCount - consumedSlabs) <= 0;

        if (_filterStatus == 'Available' && isActuallySold) continue;
        if (_filterStatus == 'Sold' && !isActuallySold) continue;

        // Exact height filter
        if (_selectedExactHeight != null && entry.height != _selectedExactHeight) {
          continue;
        }

        // Exact size filter
        if (_selectedExactSize != null) {
          final sizeKey = '${_formatNum(entry.height)} × ${_formatNum(entry.width)}';
          if (sizeKey != _selectedExactSize) continue;
        }

        // Range filters
        if (_minHeight != null && entry.height < _minHeight!) continue;
        if (_maxHeight != null && entry.height > _maxHeight!) continue;
        if (_minWidth != null && entry.width < _minWidth!) continue;
        if (_maxWidth != null && entry.width > _maxWidth!) continue;

        // Search Query
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase().trim();
          final dimStr = '${entry.height.toStringAsFixed(0)}x${entry.width.toStringAsFixed(0)}';
          final dimStrSpaced = '${_formatNum(entry.height)} x ${_formatNum(entry.width)}';
          final blockNumClean = entry.blockNumber.toLowerCase().replaceAll('#', '');
          
          if (!entry.blockName.toLowerCase().contains(query) &&
              !entry.blockNumber.toLowerCase().contains(query) &&
              !blockNumClean.contains(query) &&
              !entry.blockTypeName.toLowerCase().contains(query) &&
              !dimStr.contains(query) &&
              !dimStrSpaced.contains(query) &&
              !_formatNum(entry.height).contains(query) &&
              !_formatNum(entry.width).contains(query)) {
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

  bool get _hasActiveFilters {
    return _filterStatus != 'Available' ||
        _selectedExactHeight != null ||
        _selectedExactSize != null ||
        _minHeight != null ||
        _maxHeight != null ||
        _minWidth != null ||
        _maxWidth != null ||
        _searchQuery.isNotEmpty;
  }

  int get _activeFilterCount {
    int count = 0;
    if (_filterStatus != 'Available') count++;
    if (_selectedExactHeight != null) count++;
    if (_selectedExactSize != null) count++;
    if (_minHeight != null || _maxHeight != null) count++;
    if (_minWidth != null || _maxWidth != null) count++;
    if (_searchQuery.isNotEmpty) count++;
    return count;
  }

  void _clearAllFilters() {
    setState(() {
      _filterStatus = 'Available';
      _selectedExactHeight = null;
      _selectedExactSize = null;
      _minHeight = null;
      _maxHeight = null;
      _minWidth = null;
      _maxWidth = null;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  // Replaced large overview section with very small line summary as requested
  Widget _buildTopDashboard(String typeName, Map<String, List<StockEntry>> groupedEntries) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    int originalTotalSlabs = 0;
    int availableSlabs = 0;
    double availableArea = 0.0;
    int totalBlocks = 0;

    for (var entries in groupedEntries.values) {
      totalBlocks += entries.length;
      for (var e in entries) {
        originalTotalSlabs += e.totalSlabCount;
        final consumedSlabs = _consumedSlabsMap[e.id] ?? 0;
        final consumedArea = _consumedAreaMap[e.id] ?? 0.0;
        
        availableSlabs += (e.totalSlabCount - consumedSlabs);
        availableArea += (e.estimatedArea - consumedArea);
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222D) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 15,
            color: isDark ? Colors.lightBlueAccent : const Color(0xFF2563EB),
          ),
          const SizedBox(width: 8),
          Text(
            '$totalBlocks ${totalBlocks == 1 ? "Block" : "Blocks"}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: isDark ? Colors.white38 : Colors.black26,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Available: $availableSlabs Slabs (${availableArea.toStringAsFixed(1)} SqFt)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.lightBlueAccent : const Color(0xFF2563EB),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (originalTotalSlabs > 0) ...[
            Text(
              'Total: $originalTotalSlabs',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /*
  // Old large overview dashboard kept in comment as requested:
  Widget _buildTopDashboardOld(String typeName, Map<String, List<StockEntry>> groupedEntries) {
    ...
  }
  */

  Widget _buildMetricCard({
    required String title,
    required int slabs,
    required double area,
    required String subtitle,
    required bool isPrimary,
    required bool isDark,
  }) {
    final bgColor = isPrimary 
      ? (isDark ? const Color(0xFF1E3A8A).withOpacity(0.35) : const Color(0xFFEFF6FF))
      : (isDark ? const Color(0xFF262C3A) : const Color(0xFFF8FAFC));
      
    final primaryTextColor = isPrimary 
      ? (isDark ? Colors.lightBlueAccent : const Color(0xFF1E40AF))
      : (isDark ? Colors.white70 : const Color(0xFF475569));
      
    final valueColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPrimary 
              ? (isDark ? Colors.blue.withOpacity(0.35) : const Color(0xFFBFDBFE))
              : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              Icon(
                isPrimary ? Icons.inventory_rounded : Icons.history_rounded,
                size: 14,
                color: primaryTextColor.withOpacity(0.7),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${area.toStringAsFixed(0)} SqFt',
            style: TextStyle(
              color: valueColor,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$slabs Slabs • $subtitle',
            style: TextStyle(
              color: primaryTextColor.withOpacity(0.85),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Quick horizontal height filter strip
  Widget _buildQuickHeightFilterStrip(String blockType) {
    final heightCounts = _computeHeightCounts(blockType);
    if (heightCounts.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 40,
      margin: const EdgeInsets.only(top: 4, bottom: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: heightCounts.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = _selectedExactHeight == null;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: const Text('All Heights'),
                selected: isSelected,
                showCheckmark: false,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.blue.shade900)
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
                backgroundColor: isDark ? const Color(0xFF1E222D) : const Color(0xFFF1F5F9),
                selectedColor: isDark ? Colors.blue.withOpacity(0.35) : const Color(0xFFDBEAFE),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected ? Colors.blue : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                  ),
                ),
                onSelected: (val) {
                  setState(() {
                    _selectedExactHeight = null;
                  });
                },
              ),
            );
          }

          final item = heightCounts[index - 1];
          final isSelected = _selectedExactHeight == item.height;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              avatar: isSelected
                  ? const Icon(Icons.check_circle_rounded, size: 14, color: Colors.blue)
                  : null,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${_formatNum(item.height)}"'),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.blue.shade700
                          : (isDark ? Colors.white12 : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${item.availableBlocks} blk',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black54),
                      ),
                    ),
                  ),
                ],
              ),
              selected: isSelected,
              showCheckmark: false,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? (isDark ? Colors.white : Colors.blue.shade900)
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
              backgroundColor: isDark ? const Color(0xFF1E222D) : const Color(0xFFF8FAFC),
              selectedColor: isDark ? Colors.blue.withOpacity(0.35) : const Color(0xFFDBEAFE),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? Colors.blue : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                ),
              ),
              onSelected: (val) {
                setState(() {
                  _selectedExactHeight = val ? item.height : null;
                });
              },
            ),
          );
        },
      ),
    );
  }

  // Active filter chips row
  Widget _buildActiveFilterChips() {
    if (!_hasActiveFilters) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (_filterStatus != 'Available')
              Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: Chip(
                  label: Text('Status: $_filterStatus', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  deleteIcon: const Icon(Icons.close_rounded, size: 13),
                  onDeleted: () => setState(() => _filterStatus = 'Available'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: isDark ? Colors.blue.withOpacity(0.2) : const Color(0xFFEFF6FF),
                ),
              ),
            if (_selectedExactHeight != null)
              Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: Chip(
                  avatar: const Icon(Icons.height_rounded, size: 14),
                  label: Text('Height: ${_formatNum(_selectedExactHeight!)}"', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  deleteIcon: const Icon(Icons.close_rounded, size: 13),
                  onDeleted: () => setState(() => _selectedExactHeight = null),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: isDark ? Colors.blue.withOpacity(0.2) : const Color(0xFFEFF6FF),
                ),
              ),
            if (_selectedExactSize != null)
              Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: Chip(
                  avatar: const Icon(Icons.straighten_rounded, size: 14),
                  label: Text('Size: $_selectedExactSize', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  deleteIcon: const Icon(Icons.close_rounded, size: 13),
                  onDeleted: () => setState(() => _selectedExactSize = null),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: isDark ? Colors.blue.withOpacity(0.2) : const Color(0xFFEFF6FF),
                ),
              ),
            if (_minHeight != null)
              Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: Chip(
                  label: Text('Min H: ${_formatNum(_minHeight!)}', style: const TextStyle(fontSize: 11)),
                  deleteIcon: const Icon(Icons.close_rounded, size: 13),
                  onDeleted: () => setState(() => _minHeight = null),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            if (_maxHeight != null)
              Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: Chip(
                  label: Text('Max H: ${_formatNum(_maxHeight!)}', style: const TextStyle(fontSize: 11)),
                  deleteIcon: const Icon(Icons.close_rounded, size: 13),
                  onDeleted: () => setState(() => _maxHeight = null),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            if (_minWidth != null)
              Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: Chip(
                  label: Text('Min W: ${_formatNum(_minWidth!)}', style: const TextStyle(fontSize: 11)),
                  deleteIcon: const Icon(Icons.close_rounded, size: 13),
                  onDeleted: () => setState(() => _minWidth = null),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            if (_maxWidth != null)
              Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: Chip(
                  label: Text('Max W: ${_formatNum(_maxWidth!)}', style: const TextStyle(fontSize: 11)),
                  deleteIcon: const Icon(Icons.close_rounded, size: 13),
                  onDeleted: () => setState(() => _maxWidth = null),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: Colors.redAccent,
              ),
              onPressed: _clearAllFilters,
              icon: const Icon(Icons.clear_all_rounded, size: 16),
              label: const Text('Reset All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // Modern Search Bar
  Widget _buildSearchBar(String blockType) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasActiveFilter = _hasActiveFilters;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222D) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withOpacity(0.2) : const Color(0x08000000),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search Block name, number, size...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: false,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Quick status toggle
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E222D) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filterStatus,
                dropdownColor: isDark ? const Color(0xFF1E222D) : Colors.white,
                icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                items: const [
                  DropdownMenuItem(value: 'Available', child: Text('Available')),
                  DropdownMenuItem(value: 'Sold', child: Text('Sold')),
                  DropdownMenuItem(value: 'All', child: Text('All Stock')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _filterStatus = val);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Advanced Filter Button
          InkWell(
            onTap: () => _showFilterDialog(blockType),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: hasActiveFilter
                    ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF))
                    : (isDark ? const Color(0xFF1E222D) : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasActiveFilter
                      ? const Color(0xFF2563EB)
                      : (isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0)),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withOpacity(0.2) : const Color(0x08000000),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Badge(
                isLabelVisible: _activeFilterCount > 0,
                label: Text(
                  '$_activeFilterCount',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
                backgroundColor: const Color(0xFF2563EB),
                child: Icon(
                  Icons.tune_rounded,
                  size: 22,
                  color: hasActiveFilter
                      ? const Color(0xFF2563EB)
                      : (isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Summary Card per Block Name
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

    final totalAvailableSlabs = availablePolishedSlabs + availableUnpolishedSlabs;
    final totalOriginalSlabs = originalPolishedSlabs + originalUnpolishedSlabs;
    final totalAvailableArea = availablePolishedArea + availableUnpolishedArea;
    final bool isAllSold = totalAvailableSlabs <= 0 && totalOriginalSlabs > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222D) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : const Color(0x08000000),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: ExpansionTile(
          initiallyExpanded: _searchQuery.isNotEmpty || _selectedExactHeight != null || _selectedExactSize != null,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          iconColor: const Color(0xFF2563EB),
          collapsedIconColor: isDark ? Colors.white54 : const Color(0xFF94A3B8),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  blockName,
                  style: TextStyle(
                    fontWeight: FontWeight.w900, 
                    fontSize: 20, 
                    letterSpacing: -0.4,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isAllSold
                      ? (isDark ? Colors.red.withOpacity(0.2) : const Color(0xFFFEE2E8))
                      : (isDark ? Colors.green.withOpacity(0.2) : const Color(0xFFDCFCE7)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isAllSold ? 'SOLD OUT' : '$totalAvailableSlabs Slabs Available',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isAllSold
                        ? (isDark ? Colors.redAccent : const Color(0xFFDC2626))
                        : (isDark ? Colors.greenAccent : const Color(0xFF16A34A)),
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  if (entries.isNotEmpty && entries.first.blockNumber.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#${entries.first.blockNumber}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    '${entries.length} ${entries.length == 1 ? "Block" : "Blocks"} • ${totalAvailableArea.toStringAsFixed(1)} SqFt left',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Mini comparison cards: Polished vs Unpolished
              Row(
                children: [
                  Expanded(
                    child: _buildMiniStatPill(
                      title: 'Polished',
                      availSlabs: availablePolishedSlabs,
                      totalSlabs: originalPolishedSlabs,
                      availArea: availablePolishedArea,
                      color: const Color(0xFF2563EB),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMiniStatPill(
                      title: 'Unpolished',
                      availSlabs: availableUnpolishedSlabs,
                      totalSlabs: originalUnpolishedSlabs,
                      availArea: availableUnpolishedArea,
                      color: const Color(0xFFD97706),
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
          children: [
            Container(
              color: isDark ? const Color(0xFF141822) : const Color(0xFFF8FAFC),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
              child: Column(
                children: entries.asMap().entries.map((e) {
                  return _buildBlockItem(e.value, e.key);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    ).animate().fade().slideY(begin: 0.04, duration: 200.ms);
  }

  Widget _buildMiniStatPill({
    required String title,
    required int availSlabs,
    required int totalSlabs,
    required double availArea,
    required Color color,
    required bool isDark,
  }) {
    final double percent = totalSlabs > 0 ? (availSlabs / totalSlabs).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.1) : color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  '${availArea.toStringAsFixed(1)} SqFt',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$availSlabs / $totalSlabs',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 4,
              backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  // Individual block card in the expanded list
  Widget _buildBlockItem(StockEntry entry, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPolished = entry.isPolished;
    final primaryColor = isPolished ? const Color(0xFF2563EB) : const Color(0xFFD97706);
    
    final consumedSlabs = _consumedSlabsMap[entry.id] ?? 0;
    final consumedArea = _consumedAreaMap[entry.id] ?? 0.0;
    final int remainingSlabs = entry.totalSlabCount - consumedSlabs;
    final double remainingArea = entry.estimatedArea - consumedArea;
    final bool isSold = remainingSlabs <= 0;
    final double progress = entry.totalSlabCount > 0 ? (remainingSlabs / entry.totalSlabCount).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222D) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.25) : const Color(0x08000000),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isSold ? Colors.red : (isPolished ? const Color(0xFF2563EB) : const Color(0xFFD97706)),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Text(
                        entry.blockNumber.isNotEmpty ? 'Block #${entry.blockNumber}' : 'Block ${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? primaryColor.withOpacity(0.2) : primaryColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isPolished ? 'Polished' : 'Unpolished',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: primaryColor),
                        ),
                      ),
                      // PROMINENT DIMENSION BADGE
                      if (entry.height > 0 || entry.width > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.blue.withOpacity(0.25) : const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? Colors.blue.withOpacity(0.4) : const Color(0xFF93C5FD),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.straighten_rounded, size: 14, color: isDark ? Colors.lightBlueAccent : const Color(0xFF1D4ED8)),
                              const SizedBox(width: 4),
                              Text(
                                '${_formatNum(entry.height)}" × ${_formatNum(entry.width)}"',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.lightBlueAccent : const Color(0xFF1E40AF),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (isSold)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('SOLD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                        ),
                    ],
                  ),
                ),
                // Action Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.info_outline_rounded, size: 20),
                      color: isDark ? Colors.lightBlueAccent : const Color(0xFF2563EB),
                      tooltip: 'View Details',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _showBlockDetailsDialog(entry, index),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 19),
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      tooltip: 'Edit Block',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
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
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 19),
                      color: Colors.redAccent,
                      tooltip: 'Delete Block',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _confirmDelete(entry),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Stock Details Box (Spacious and clear)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141822) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Available Slabs',
                              style: TextStyle(
                                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$remainingSlabs / ${entry.totalSlabCount}',
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Available Area',
                              style: TextStyle(
                                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${remainingArea.toStringAsFixed(1)} SqFt',
                              style: TextStyle(
                                color: primaryColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress > 0.3 ? primaryColor : Colors.redAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Linked Sheets section
            if (_linkedBooksMap.containsKey(entry.id) && _linkedBooksMap[entry.id]!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _linkedBooksMap[entry.id]!.map((book) {
                  final slabs = book.slabs.where((s) => s.length > 0 || s.width > 0).fold(0, (sum, slab) => sum + slab.quantity);
                  final area = book.slabs.fold(0.0, (sum, slab) => sum + slab.getArea(book.unit));
                  return InkWell(
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
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blue.withOpacity(0.12) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? Colors.blue.withOpacity(0.2) : const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.description_rounded, size: 14, color: isDark ? Colors.lightBlueAccent : const Color(0xFF2563EB)),
                          const SizedBox(width: 6),
                          Text(
                            '${book.name} ($slabs slabs • ${area.toStringAsFixed(0)} ${book.unit})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.lightBlueAccent : const Color(0xFF1D4ED8),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, size: 14),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Detailed Modal for a Block
  void _showBlockDetailsDialog(StockEntry entry, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final consumedSlabs = _consumedSlabsMap[entry.id] ?? 0;
    final consumedArea = _consumedAreaMap[entry.id] ?? 0.0;
    final remainingSlabs = entry.totalSlabCount - consumedSlabs;
    final remainingArea = entry.estimatedArea - consumedArea;
    final bool isSold = remainingSlabs <= 0;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: isDark ? const Color(0xFF1E222D) : Colors.white,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(22),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.blue.withOpacity(0.2) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.view_in_ar_rounded, color: Color(0xFF2563EB), size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.blockName,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${entry.blockNumber.isNotEmpty ? "#${entry.blockNumber} • " : ""}${entry.blockTypeName} (${entry.isPolished ? "Polished" : "Unpolished"})',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Prominent Slab Dimension Showcase
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark 
                            ? [const Color(0xFF1E3A8A).withOpacity(0.4), const Color(0xFF172554).withOpacity(0.4)]
                            : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.straighten_rounded, color: isDark ? Colors.lightBlueAccent : const Color(0xFF1D4ED8), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Cut Slab Dimensions',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: isDark ? Colors.lightBlueAccent : const Color(0xFF1E40AF),
                                letterSpacing: 0.3,
                              ),
                            ),
                            const Spacer(),
                            if (entry.height > 0 && entry.width > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${_formatNum(entry.height)}" × ${_formatNum(entry.width)}"',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.black26 : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Height', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text(
                                      entry.height > 0 ? '${_formatNum(entry.height)}"' : 'Not set',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: entry.height > 0 ? (isDark ? Colors.white : const Color(0xFF0F172A)) : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.black26 : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Width', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text(
                                      entry.width > 0 ? '${_formatNum(entry.width)}"' : 'Not set',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: entry.width > 0 ? (isDark ? Colors.white : const Color(0xFF0F172A)) : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (entry.height > 0 && entry.width > 0) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Approx. Area per slab: ${((entry.height * entry.width) / 144).toStringAsFixed(1)} SqFt',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : const Color(0xFF1E3A8A),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stock & Area Stats
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF141822) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Available Slabs', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text('$remainingSlabs', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                                  Text('of ${entry.totalSlabCount} total', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey)),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 40, color: isDark ? Colors.white12 : Colors.grey.shade300),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Available Area', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text('${remainingArea.toStringAsFixed(1)} SqFt', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF2563EB))),
                                  Text('of ${entry.estimatedArea.toStringAsFixed(1)} SqFt', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Date Added:', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF64748B))),
                            Text(DateFormat.yMMMd().format(entry.date), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : const Color(0xFF0F172A))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Stock Status:', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF64748B))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSold ? Colors.red.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isSold ? 'SOLD OUT' : 'AVAILABLE',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isSold ? Colors.redAccent : Colors.green),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
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
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          label: const Text('Edit Block'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Redesigned Filter BottomSheet with all available sizes and block counts
  void _showFilterDialog(String blockType) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Compute available heights and sizes for this block type
    final heightCounts = _computeHeightCounts(blockType);
    final sizeCounts = _computeSizeCounts(blockType);

    final minHController = TextEditingController(text: _minHeight != null ? _formatNum(_minHeight!) : '');
    final maxHController = TextEditingController(text: _maxHeight != null ? _formatNum(_maxHeight!) : '');
    final minWController = TextEditingController(text: _minWidth != null ? _formatNum(_minWidth!) : '');
    final maxWController = TextEditingController(text: _maxWidth != null ? _formatNum(_maxWidth!) : '');
    
    String tempStatus = _filterStatus;
    double? tempExactHeight = _selectedExactHeight;
    String? tempExactSize = _selectedExactSize;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E222D) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Calculate how many blocks match the current temporary filter
            int matchingBlocksCount = 0;
            for (var entry in _stockEntries) {
              if (entry.blockTypeName.toLowerCase() == blockType.toLowerCase()) {
                final consumedSlabs = _consumedSlabsMap[entry.id] ?? 0;
                final bool isActuallySold = (entry.totalSlabCount - consumedSlabs) <= 0;

                if (tempStatus == 'Available' && isActuallySold) continue;
                if (tempStatus == 'Sold' && !isActuallySold) continue;

                if (tempExactHeight != null && entry.height != tempExactHeight) continue;

                if (tempExactSize != null) {
                  final key = '${_formatNum(entry.height)} × ${_formatNum(entry.width)}';
                  if (key != tempExactSize) continue;
                }

                final minH = double.tryParse(minHController.text);
                final maxH = double.tryParse(maxHController.text);
                final minW = double.tryParse(minWController.text);
                final maxW = double.tryParse(maxWController.text);

                if (minH != null && entry.height < minH) continue;
                if (maxH != null && entry.height > maxH) continue;
                if (minW != null && entry.width < minW) continue;
                if (maxW != null && entry.width > maxW) continue;

                matchingBlocksCount++;
              }
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.blue.withOpacity(0.2) : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.tune_rounded, color: Color(0xFF2563EB), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Filter $blockType Inventory',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Quickly filter by height, size, or status',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              minHController.clear();
                              maxHController.clear();
                              minWController.clear();
                              maxWController.clear();
                              tempStatus = 'Available';
                              tempExactHeight = null;
                              tempExactSize = null;
                            });
                          },
                          child: const Text('Reset All', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Scrollable filter options
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      children: [
                        // 1. Stock Status
                        Text(
                          'Stock Status',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: ['Available', 'Sold', 'All'].map((s) {
                            final isSel = tempStatus == s;
                            return ChoiceChip(
                              label: Text(s == 'All' ? 'All Stock' : s),
                              selected: isSel,
                              selectedColor: isDark ? Colors.blue.withOpacity(0.35) : const Color(0xFFDBEAFE),
                              backgroundColor: isDark ? const Color(0xFF141822) : const Color(0xFFF1F5F9),
                              labelStyle: TextStyle(
                                fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                color: isSel ? const Color(0xFF2563EB) : (isDark ? Colors.white70 : Colors.black87),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: isSel ? const Color(0xFF2563EB) : Colors.transparent),
                              ),
                              onSelected: (val) {
                                if (val) setModalState(() => tempStatus = s);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 22),

                        // 2. AVAILABLE HEIGHTS WITH EXACT BLOCK COUNTS
                        Row(
                          children: [
                            Text(
                              'Available Slab Heights',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: isDark ? Colors.white70 : const Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${heightCounts.length} available)',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap a height to see blocks with that specific height:',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 10),

                        if (heightCounts.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('No heights recorded yet. Set height when adding stock.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: heightCounts.map((hItem) {
                              final isSel = tempExactHeight == hItem.height;
                              return InkWell(
                                onTap: () {
                                  setModalState(() {
                                    if (isSel) {
                                      tempExactHeight = null;
                                    } else {
                                      tempExactHeight = hItem.height;
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? (isDark ? Colors.blue.withOpacity(0.35) : const Color(0xFFDBEAFE))
                                        : (isDark ? const Color(0xFF141822) : const Color(0xFFF8FAFC)),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSel ? const Color(0xFF2563EB) : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                                      width: isSel ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isSel)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 6),
                                          child: Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF2563EB)),
                                        ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Height: ${_formatNum(hItem.height)}"',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                              color: isSel ? const Color(0xFF1D4ED8) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${hItem.totalBlocks} ${hItem.totalBlocks == 1 ? "Block" : "Blocks"} (${hItem.availableSlabs} slabs)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isSel ? const Color(0xFF1E40AF) : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 22),

                        // 3. AVAILABLE SIZES (H x W) WITH EXACT BLOCK COUNTS
                        Row(
                          children: [
                            Text(
                              'Available Dimensions (H × W)',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: isDark ? Colors.white70 : const Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${sizeCounts.length} available)',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap an exact dimension to filter matching blocks:',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 10),

                        if (sizeCounts.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('No dimensions recorded yet. Set height and width when adding stock.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: sizeCounts.map((sItem) {
                              final isSel = tempExactSize == sItem.label;
                              return InkWell(
                                onTap: () {
                                  setModalState(() {
                                    if (isSel) {
                                      tempExactSize = null;
                                    } else {
                                      tempExactSize = sItem.label;
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? (isDark ? Colors.blue.withOpacity(0.35) : const Color(0xFFDBEAFE))
                                        : (isDark ? const Color(0xFF141822) : const Color(0xFFF8FAFC)),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSel ? const Color(0xFF2563EB) : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                                      width: isSel ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isSel)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 6),
                                          child: Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF2563EB)),
                                        ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            sItem.label,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                              color: isSel ? const Color(0xFF1D4ED8) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${sItem.totalBlocks} ${sItem.totalBlocks == 1 ? "Block" : "Blocks"} (${sItem.availableSlabs} slabs)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isSel ? const Color(0xFF1E40AF) : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 24),

                        // 4. Custom Min/Max Range
                        Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(
                              'Custom Min/Max Range (Advanced)',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: isDark ? Colors.white70 : const Color(0xFF334155),
                              ),
                            ),
                            children: [
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: minHController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        labelText: 'Min Height',
                                        hintText: 'e.g. 50',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      ),
                                      onChanged: (_) => setModalState(() {}),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: maxHController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        labelText: 'Max Height',
                                        hintText: 'e.g. 120',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      ),
                                      onChanged: (_) => setModalState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: minWController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        labelText: 'Min Width',
                                        hintText: 'e.g. 30',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      ),
                                      onChanged: (_) => setModalState(() {}),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: maxWController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        labelText: 'Max Width',
                                        hintText: 'e.g. 80',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      ),
                                      onChanged: (_) => setModalState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),

                  // Bottom Sticky Apply Button
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E222D) : Colors.white,
                      border: Border(top: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0))),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        setState(() {
                          _filterStatus = tempStatus;
                          _selectedExactHeight = tempExactHeight;
                          _selectedExactSize = tempExactSize;
                          _minHeight = double.tryParse(minHController.text);
                          _maxHeight = double.tryParse(maxHController.text);
                          _minWidth = double.tryParse(minWController.text);
                          _maxWidth = double.tryParse(maxWController.text);
                        });
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Show $matchingBlocksCount Matching ${matchingBlocksCount == 1 ? "Block" : "Blocks"}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(StockEntry entry) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E222D) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Stock Entry?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete ${entry.blockName} (${entry.blockNumber.isNotEmpty ? "#${entry.blockNumber}" : ""})? This cannot be undone.'),
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
        if (grouped.isNotEmpty || _hasActiveFilters)
          _buildTopDashboard(title, grouped),

        // Search Bar & Filter Button
        _buildSearchBar(blockType),

        // Quick Height Filter strip
        _buildQuickHeightFilterStrip(blockType),

        // Active Filter Chips
        _buildActiveFilterChips(),

        // Empty State
        if (blockKeys.isEmpty)
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.inventory_2_outlined, size: 60, color: isDark ? Colors.white30 : const Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No $title Blocks Found',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        _hasActiveFilters
                            ? 'No blocks match your current filters. Try resetting the filters or modifying your search.'
                            : 'No $title stock records yet. Tap the button below to add your first block.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
                      ),
                    ),
                    if (_hasActiveFilters) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _clearAllFilters,
                        icon: const Icon(Icons.restart_alt_rounded, size: 18),
                        label: const Text('Clear All Filters'),
                      ),
                    ],
                  ],
                ).animate().fade().scale(duration: 300.ms),
              ),
            ),
          )
        else
          // Blocks List
          Expanded(
            child: ListView.builder(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(top: 6, bottom: 24),
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
    final types = _blockTypes;
    final showTabs = types.length > 1;

    Widget content = Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_rounded, size: 22, color: Color(0xFF2563EB)),
            const SizedBox(width: 8),
            const Text(
              'Stock Inventory',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5, fontSize: 20),
            ),
          ],
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        actions: [
          IconButton(
            tooltip: 'Reload Stock',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                visualDensity: VisualDensity.compact,
              ),
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
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Block', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
        bottom: showTabs ? PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E222D) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
              ),
            ),
            child: TabBar(
              indicator: BoxDecoration(
                color: isDark ? const Color(0xFF262C3A) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: isDark ? Colors.lightBlueAccent : const Color(0xFF2563EB),
              unselectedLabelColor: isDark ? Colors.white54 : const Color(0xFF64748B),
              labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              tabs: types.map((t) => Tab(text: t)).toList(),
            ),
          ),
        ) : null,
      ),
      body: showTabs
          ? TabBarView(
              children: types.map((t) => _buildListContent(t, t)).toList(),
            )
          : _buildListContent(types.first, types.first),
      // Floating button removed and moved to AppBar so it doesn't overlap or cut data; retained in comments:
      /*
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
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Block Stock', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.3)),
        ).animate().scale(delay: 200.ms, duration: 350.ms),
      ),
      */
    );

    if (showTabs) {
      return DefaultTabController(
        length: types.length,
        child: content,
      );
    }
    return content;
  }
}

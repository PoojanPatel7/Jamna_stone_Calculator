import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/stock_models.dart';
import '../../services/stock_storage_service.dart';
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

class _StockScreenState extends State<StockScreen> with SingleTickerProviderStateMixin {
  List<StockEntry> _stockEntries = [];
  bool _isLoading = true;
  late TabController _tabController;
  
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _stockEntries = await StockStorageService.loadStockEntries();
    setState(() => _isLoading = false);
  }

  Map<String, List<StockEntry>> _getGroupedEntriesByBlockName(String typeName) {
    final Map<String, List<StockEntry>> grouped = {};
    for (var entry in _stockEntries) {
      if (entry.blockTypeName == typeName) {
        if (_searchQuery.isNotEmpty && !entry.blockName.toLowerCase().contains(_searchQuery.toLowerCase())) {
          continue;
        }
        if (!grouped.containsKey(entry.blockName)) {
          grouped[entry.blockName] = [];
        }
        grouped[entry.blockName]!.add(entry);
      }
    }
    return grouped;
  }

  Widget _buildTopDashboard(String typeName, Map<String, List<StockEntry>> groupedEntries) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    int totalSlabs = 0;
    double totalArea = 0.0;
    int totalBlocks = groupedEntries.length;

    for (var entries in groupedEntries.values) {
      for (var e in entries) {
        totalSlabs += e.totalSlabCount;
        totalArea += e.estimatedArea;
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
            ? [const Color(0xFF1565C0), const Color(0xFF0D47A1)] 
            : [Colors.lightBlueAccent, Colors.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total $typeName Stock',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$totalBlocks Blocks',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Est. Area', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(
                      '${totalArea.toStringAsFixed(0)} SqFt',
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, height: 1.1),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text('Slabs', style: TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.bold)),
                    Text(
                      '$totalSlabs',
                      style: const TextStyle(color: Colors.blue, fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.1);
  }

  Widget _buildSummaryCard(String blockName, List<StockEntry> entries) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    int polishedSlabs = 0;
    double polishedArea = 0.0;
    int unpolishedSlabs = 0;
    double unpolishedArea = 0.0;

    for (var e in entries) {
      if (e.isPolished) {
        polishedSlabs += e.totalSlabCount;
        polishedArea += e.estimatedArea;
      } else {
        unpolishedSlabs += e.totalSlabCount;
        unpolishedArea += e.estimatedArea;
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
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              children: [
                _buildStatBox(
                  title: 'Polished',
                  slabs: polishedSlabs,
                  area: polishedArea,
                  color: isDark ? Colors.lightBlueAccent : Colors.blue,
                  bgColor: isDark ? Colors.blue.withOpacity(0.1) : const Color(0xFFE3F2FD),
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _buildStatBox(
                  title: 'Unpolished',
                  slabs: unpolishedSlabs,
                  area: unpolishedArea,
                  color: isDark ? Colors.brown.shade300 : const Color(0xFF8D6E63),
                  bgColor: isDark ? Colors.brown.withOpacity(0.1) : const Color(0xFFEFEBE9),
                  isDark: isDark,
                ),
              ],
            ),
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: isPolished ? primaryColor : Colors.orange,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Block ${index + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700, 
                                      color: isDark ? Colors.white : Colors.black, 
                                      fontSize: 17,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isPolished ? 'Polished' : 'Unpolished',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500, 
                                      color: isDark ? Colors.white54 : Colors.grey.shade500, 
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (entry.isSynced)
                                    const Icon(Icons.cloud_done_rounded, color: Colors.green, size: 16)
                                  else
                                    const Icon(Icons.sync_problem_rounded, color: Colors.orange, size: 16),
                                ],
                              ),
                              Row(
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
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Slabs', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13, fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 4),
                                      Text('${entry.totalSlabCount}', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Area', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13, fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 4),
                                      Text('${entry.estimatedArea.toStringAsFixed(1)} sqft', style: TextStyle(color: primaryColor, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                                    ],
                                  ),
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
            ),
          ],
        ),
      ),
    ).animate().fade().slideY(begin: 0.05, duration: 300.ms);
  }

  Widget _buildStatBox({required String title, required int slabs, required double area, required Color color, required Color bgColor, required bool isDark}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(isDark ? 0.3 : 0.5), width: 1.5),
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
            const SizedBox(height: 8),
            Text('${area.toStringAsFixed(0)} SqFt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
            Text('Total Area', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade600, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('$slabs slabs', style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w700)),
          ],
        ),
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

  Widget _buildTabContent(String typeName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final grouped = _getGroupedEntriesByBlockName(typeName);
    final blockKeys = grouped.keys.toList()..sort();

    return Column(
      children: [
        // Top Dashboard
        if (grouped.isNotEmpty)
          _buildTopDashboard(typeName, grouped),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search Block Name...',
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
        ).animate().fade().slideY(begin: -0.1),

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
                    'No $typeName Stock Found',
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Inventory', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
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
                Tab(text: 'Marble'),
                Tab(text: 'Granite'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabContent('Marble'),
          _buildTabContent('Granite'),
        ],
      ),
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
  }
}

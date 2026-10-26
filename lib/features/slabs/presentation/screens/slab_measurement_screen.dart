import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../data/models/slab_models.dart';
import '../../services/storage_service.dart';
import 'history_screen.dart';
import '../../../stock/data/models/stock_models.dart';
import '../../../stock/services/stock_storage_service.dart';
import '../../../../main.dart'; // For themeNotifier
import '../../../../core/localization/app_translations.dart';

class AppColors {
  static const Color primary = Colors.blue;
  static const Gradient primaryGradient = LinearGradient(
    colors: [Colors.lightBlueAccent, Colors.blue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class SlabMeasurementScreen extends StatefulWidget {
  final SlabBook? loadedBook;
  final VoidCallback? onBackTapped;
  const SlabMeasurementScreen({super.key, this.loadedBook, this.onBackTapped});

  @override
  State<SlabMeasurementScreen> createState() => _SlabMeasurementScreenState();
}

class _SlabMeasurementScreenState extends State<SlabMeasurementScreen> {
  List<SlabEntry> _slabs = [];
  int _nextSlabNo = 1;
  String _currentUnit = 'Feet';
  String? _bookId;
  String _bookName = 'Untitled Book';
  String _graniteName = '';
  String _partyName = '';
  String _numberPlate = '';
  DateTime _bookDate = DateTime.now();
  String? _linkedStockId;
  String? _linkedBlockDisplay;
  
  final List<String> _units = ['Feet', 'Inches', 'Cm', 'Meter'];
  
  List<String> _undoStack = [];
  List<String> _redoStack = [];
  String _formSessionId = UniqueKey().toString();
  
  bool _isTableView = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    if (widget.loadedBook != null) {
      _bookId = widget.loadedBook!.id;
      _bookName = widget.loadedBook!.name;
      _graniteName = widget.loadedBook!.graniteName ?? '';
      _partyName = widget.loadedBook!.partyName ?? '';
      _numberPlate = widget.loadedBook!.numberPlate ?? '';
      _bookDate = widget.loadedBook!.date;
      _currentUnit = widget.loadedBook!.unit;
      _linkedStockId = widget.loadedBook!.linkedStockId;
      _linkedBlockDisplay = widget.loadedBook!.linkedBlockDisplay;
      
      List<SlabEntry> expanded = [];
      for (var s in widget.loadedBook!.slabs) {
        if (s.quantity > 1) {
          for (int i = 0; i < s.quantity; i++) {
            expanded.add(SlabEntry(slabNo: s.slabNo + i, length: s.length, width: s.width, quantity: 1));
          }
        } else {
          expanded.add(SlabEntry(slabNo: s.slabNo, length: s.length, width: s.width, quantity: 1));
        }
      }
      _slabs = expanded;
      
      if (_linkedStockId == null) {
        if (_slabs.length < 200) {
          for (int i = _slabs.length; i < 200; i++) {
            _slabs.add(SlabEntry(slabNo: i + 1));
          }
        }
      }
      _recalculateSlabNumbers();
    }
  }

  void _saveBookLive() {
    if (_bookId == null) return;
    
    final book = SlabBook(
      id: _bookId!,
      name: _bookName,
      graniteName: _graniteName.trim().isEmpty ? null : _graniteName.trim(),
      partyName: _partyName.trim().isEmpty ? null : _partyName.trim(),
      numberPlate: _numberPlate.trim().isEmpty ? null : _numberPlate.trim(),
      linkedStockId: _linkedStockId,
      linkedBlockDisplay: _linkedBlockDisplay,
      date: _bookDate,
      unit: _currentUnit,
      slabs: _slabs,
    );
    StorageService.saveBook(book);
    
    // Update stock sold status if linked to a stock block
    if (_linkedStockId != null) {
      _updateLinkedStockStatus();
    }
  }

  Future<void> _updateLinkedStockStatus() async {
    if (_linkedStockId == null) return;
    final books = await StorageService.getBooksForStockId(_linkedStockId!);
    double totalBookArea = 0;
    for (var b in books) {
      totalBookArea += b.slabs.fold(0.0, (sum, slab) => sum + slab.getArea(b.unit));
    }
    await StockStorageService.updateStockSoldStatus(_linkedStockId!, totalBookArea);
  }

  void _recalculateSlabNumbers() {
    if (_slabs.isNotEmpty) {
      final last = _slabs.last;
      _nextSlabNo = last.slabNo + last.quantity;
    } else {
      _nextSlabNo = 1;
    }
    setState(() {});
  }

  void _saveStateForUndo() {
    _undoStack.add(jsonEncode(_slabs.map((e) => e.toJson()).toList()));
    if (_undoStack.length > 50) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(jsonEncode(_slabs.map((e) => e.toJson()).toList()));
    final previousState = _undoStack.removeLast();
    setState(() {
      _formSessionId = UniqueKey().toString();
      _slabs = (jsonDecode(previousState) as List).map((e) => SlabEntry.fromJson(e)).toList();
      _recalculateSlabNumbers();
      _saveBookLive();
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(jsonEncode(_slabs.map((e) => e.toJson()).toList()));
    final nextState = _redoStack.removeLast();
    setState(() {
      _formSessionId = UniqueKey().toString();
      _slabs = (jsonDecode(nextState) as List).map((e) => SlabEntry.fromJson(e)).toList();
      _recalculateSlabNumbers();
      _saveBookLive();
    });
  }

  void _addNewSlab() {
    _saveStateForUndo();
    setState(() {
      _slabs.add(SlabEntry(slabNo: _slabs.length + 1));
      _recalculateSlabNumbers();
      _saveBookLive();
    });
  }

  void _checkAndAutoAddRows(int index, SlabEntry slab) {
    if (_linkedStockId != null) return; // Do not auto add rows if linked to stock
    if (index == _slabs.length - 1 && (slab.length > 0 || slab.width > 0)) {
      for (int i = 0; i < 100; i++) {
        _slabs.add(SlabEntry(slabNo: _slabs.length + 1));
      }
    }
  }
  
  void _copyPreviousRow(int index) {
    if (index > 0) {
      int lastFilledIndex = -1;
      for (int i = index - 1; i >= 0; i--) {
        if (_slabs[i].length > 0 || _slabs[i].width > 0) {
          lastFilledIndex = i;
          break;
        }
      }
      
      if (lastFilledIndex != -1) {
        _saveStateForUndo();
        setState(() {
          _formSessionId = UniqueKey().toString();
          double len = _slabs[lastFilledIndex].length;
          double wid = _slabs[lastFilledIndex].width;
          for (int i = lastFilledIndex + 1; i <= index; i++) {
            _slabs[i].length = len;
            _slabs[i].width = wid;
          }
          _checkAndAutoAddRows(index, _slabs[index]);
          _saveBookLive();
        });
      }
    }
  }

  void _clearRow(int index) {
    _saveStateForUndo();
    setState(() {
      _formSessionId = UniqueKey().toString();
      _slabs[index].length = 0.0;
      _slabs[index].width = 0.0;
      _saveBookLive();
    });
  }

  double get _totalArea {
    return _slabs.fold<double>(0.0, (double sum, slab) => sum + slab.getArea(_currentUnit));
  }
  
  int get _totalQuantity {
    return _slabs.where((s) => s.length > 0 || s.width > 0).length;
  }
  
  String get _displayUnit {
    if (_currentUnit == 'Inches' || _currentUnit == 'Feet') {
      return 'Sq Feet';
    } else if (_currentUnit == 'Cm' || _currentUnit == 'Meter') {
      return 'Sq Meter';
    }
    return 'Sq $_currentUnit';
  }
  
  Widget _buildCreateBookView() {
    final graniteController = TextEditingController();
    final partyController = TextEditingController();
    final plateController = TextEditingController();
    DateTime tempDate = DateTime.now();
    List<StockEntry> availableStocks = [];
    Map<String, int> stockConsumedSlabs = {};
    Map<String, double> stockConsumedArea = {};
    StockEntry? selectedStock;
    bool stocksLoaded = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StatefulBuilder(builder: (context, setLocalState) {
      if (!stocksLoaded) {
        stocksLoaded = true;
        Future.wait([
          StockStorageService.loadStockEntries(),
          StorageService.loadHistory(),
        ]).then((results) {
          final allStocks = results[0] as List<StockEntry>;
          final history = results[1] as List<SlabBook>;
          
          Map<String, int> consumedSlabsMap = {};
          Map<String, double> consumedAreaMap = {};
          
          for (var book in history) {
            if (book.linkedStockId != null) {
              double area = book.slabs.fold(0.0, (sum, slab) => sum + slab.getArea(book.unit));
              int slabs = book.slabs.where((s) => s.length > 0 || s.width > 0).fold(0, (sum, slab) => sum + slab.quantity);
              
              consumedAreaMap[book.linkedStockId!] = (consumedAreaMap[book.linkedStockId!] ?? 0.0) + area;
              consumedSlabsMap[book.linkedStockId!] = (consumedSlabsMap[book.linkedStockId!] ?? 0) + slabs;
            }
          }
          
          final filtered = allStocks.where((entry) {
            final consumedSlabs = consumedSlabsMap[entry.id] ?? 0;
            return (entry.totalSlabCount - consumedSlabs) > 0;
          }).toList();
          
          setLocalState(() {
            availableStocks = filtered;
            stockConsumedSlabs = consumedSlabsMap;
            stockConsumedArea = consumedAreaMap;
          });
        });
      }

      return Scaffold(
        appBar: AppBar(
          title: Text('new_book'.tr, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5)),
          centerTitle: true,
          elevation: 0,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05)),
                boxShadow: [
                  if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 8)),
                ],
              ),
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('create_start'.tr, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.5), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('Fill in the details below to start measuring slabs.', style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54), textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  _buildPremiumTextField(controller: graniteController, label: 'granite_name'.tr, icon: Icons.landscape_rounded, isDark: isDark),
                  const SizedBox(height: 16),
                  _buildPremiumTextField(controller: partyController, label: 'party_name'.tr, icon: Icons.business_rounded, isDark: isDark),
                  const SizedBox(height: 16),
                  _buildPremiumTextField(controller: plateController, label: 'number_plate'.tr, icon: Icons.local_shipping_rounded, isDark: isDark),
                  const SizedBox(height: 24),
                  
                  const Divider(),
                  const SizedBox(height: 20),
                  Text('Stock Linkage (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
                  const SizedBox(height: 12),
                  
                  DropdownButtonFormField<String?>(
                    value: selectedStock?.id,
                    decoration: InputDecoration(
                      labelText: 'Select Available Stock Block',
                      labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8F9FA),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: Icon(Icons.inventory_2_rounded, color: isDark ? Colors.blueAccent : Colors.blue.shade700),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('None (No stock link)', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      ...availableStocks.map((stock) {
                        final remaining = stock.totalSlabCount - (stockConsumedSlabs[stock.id] ?? 0);
                        final dimPart = (stock.height > 0 && stock.width > 0)
                            ? ' • ${stock.height % 1 == 0 ? stock.height.toInt() : stock.height}×${stock.width % 1 == 0 ? stock.width.toInt() : stock.width}'
                            : '';
                        final label = '${stock.blockName} (#${stock.blockNumber}) - $remaining slabs left$dimPart';
                        return DropdownMenuItem<String?>(
                          value: stock.id,
                          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setLocalState(() {
                        if (val == null) {
                          selectedStock = null;
                        } else {
                          selectedStock = availableStocks.firstWhere((s) => s.id == val);
                        }
                      });
                    },
                    isExpanded: true,
                    dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                  ),
                  if (selectedStock != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.blue.withOpacity(0.3) : Colors.blue.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, size: 20, color: isDark ? Colors.lightBlueAccent : Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Left in Stock: ${selectedStock!.totalSlabCount - (stockConsumedSlabs[selectedStock!.id] ?? 0)} slabs',
                                  style: TextStyle(fontSize: 13, color: isDark ? Colors.lightBlueAccent : Colors.blue.shade800, fontWeight: FontWeight.bold),
                                ),
                                if (selectedStock!.height > 0 || selectedStock!.width > 0) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.straighten_rounded, size: 14, color: isDark ? Colors.lightBlueAccent : Colors.blue.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Slab Size: ${selectedStock!.height > 0 ? (selectedStock!.height % 1 == 0 ? selectedStock!.height.toInt() : selectedStock!.height) : "-"} × ${selectedStock!.width > 0 ? (selectedStock!.width % 1 == 0 ? selectedStock!.width.toInt() : selectedStock!.width) : "-"}',
                                        style: TextStyle(fontSize: 12, color: isDark ? Colors.lightBlueAccent : Colors.blue.shade900, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  'Measurement sheet will be created with exactly ${selectedStock!.totalSlabCount - (stockConsumedSlabs[selectedStock!.id] ?? 0)} rows.',
                                  style: TextStyle(fontSize: 11, color: isDark ? Colors.lightBlueAccent.withOpacity(0.7) : Colors.blue.shade800.withOpacity(0.8)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: tempDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: Colors.blue.shade700,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) setLocalState(() => tempDate = picked);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 20, color: isDark ? Colors.white54 : Colors.black54),
                                const SizedBox(width: 12),
                                Expanded(child: Text('${tempDate.day}/${tempDate.month}/${tempDate.year}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _currentUnit,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8F9FA),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                          ),
                          items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)))).toList(),
                          onChanged: (val) {
                            if (val != null) setLocalState(() => _currentUnit = val);
                          },
                          dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      if (graniteController.text.trim().isEmpty || partyController.text.trim().isEmpty || plateController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
                        return;
                      }
                      setState(() {
                        _bookId = DateTime.now().millisecondsSinceEpoch.toString();
                        _graniteName = graniteController.text.trim();
                        _partyName = partyController.text.trim();
                        _numberPlate = plateController.text.trim();
                        _bookName = '$_partyName - $_graniteName';
                        _bookDate = tempDate;
                        
                        int rowCount = 200; // default to 200 for unlinked
                        if (selectedStock != null) {
                          _linkedStockId = selectedStock!.id;
                          _linkedBlockDisplay = '${selectedStock!.blockName} (#${selectedStock!.blockNumber})';
                          rowCount = selectedStock!.totalSlabCount - (stockConsumedSlabs[selectedStock!.id] ?? 0);
                          if (rowCount <= 0) rowCount = 200; // fallback if somehow 0
                        } else {
                          _linkedStockId = null;
                          _linkedBlockDisplay = null;
                        }
                        
                        _slabs = List.generate(
                          rowCount,
                          (i) => SlabEntry(
                            slabNo: i + 1,
                            length: selectedStock != null && selectedStock!.height > 0 ? selectedStock!.height : 0.0,
                            width: selectedStock != null && selectedStock!.width > 0 ? selectedStock!.width : 0.0,
                          ),
                        );
                        _recalculateSlabNumbers();
                        _saveBookLive();
                      });
                    },
                    child: Text('create_start'.tr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  ),
                ],
              ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildPremiumTextField({required TextEditingController controller, required String label, required IconData icon, required bool isDark}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8F9FA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        prefixIcon: Icon(icon, color: isDark ? Colors.white54 : Colors.black45),
      ),
      style: const TextStyle(fontWeight: FontWeight.w600),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_bookId == null) {
      return _buildCreateBookView();
    }
    
    return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.loadedBook != null ? 'Edit: $_bookName' : 'Slab Measurement'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isTableView ? Icons.grid_view_rounded : Icons.table_chart_rounded),
            tooltip: _isTableView ? 'Card View' : 'Table View',
            onPressed: () {
              setState(() {
                _isTableView = !_isTableView;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.undo_rounded),
            tooltip: 'Undo',
            onPressed: _undoStack.isNotEmpty ? _undo : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo_rounded),
            tooltip: 'Redo',
            onPressed: _redoStack.isNotEmpty ? _redo : null,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) async {
              switch (value) {
                case 'share':
                case 'export':
                  _sharePdfDirectly();
                  break;
                case 'pdf': _openPdfPreview(); break;

                case 'clear':
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Clear All Rows?'),
                        content: const Text('This will remove all measurement rows from the current screen. Saved books in History will NOT be affected.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Clear'),
                          ),
                        ],
                      );
                    },
                  );
                  if (confirm == true) {
                    _saveStateForUndo();
                    setState(() {
                      _formSessionId = UniqueKey().toString();
                      for (var slab in _slabs) {
                        slab.length = 0.0;
                        slab.width = 0.0;
                      }
                      _saveBookLive();
                    });
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'save', child: Row(children: [Icon(Icons.save_rounded, size: 20), SizedBox(width: 8), Text('Save Book')])),
              const PopupMenuItem(value: 'share', child: Row(children: [Icon(Icons.share_rounded, color: Colors.blue, size: 20), SizedBox(width: 8), Text('Share PDF')])),
              const PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf_rounded, size: 20), SizedBox(width: 8), Text('PDF Preview')])),

              const PopupMenuDivider(),
              const PopupMenuItem(value: 'clear', child: Row(children: [Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 20), SizedBox(width: 8), Text('Clear All', style: TextStyle(color: Colors.red))])),
              const PopupMenuItem(value: 'close', child: Row(children: [Icon(Icons.close_rounded, size: 20), SizedBox(width: 8), Text('Close Menu')])),
            ],
          )
        ],
      ),
      body: Column(
        children: [
          _buildTopSummary(),
          Expanded(
            child: _isTableView ? _buildTableView() : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), 
              itemCount: _slabs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _buildSlabRow(index).animate().fadeIn(duration: 200.ms).slideX(begin: 0.05, end: 0);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildTopSummary() {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return Container(
      margin: EdgeInsets.fromLTRB(16, 8, 16, isLandscape ? 4 : 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Area', style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('${_totalArea.toStringAsFixed(2)} $_displayUnit', style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w900)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Slabs', style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('$_totalQuantity', style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w900)),
                ],
              ),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
                child: DropdownButton<String>(
                  value: _currentUnit,
                  dropdownColor: AppColors.primary,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black87, size: 20),
                  style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                  items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _currentUnit = val);
                      _saveBookLive();
                    }
                  },
                ),
              ),
            ],
          ),
          if (_bookId != null) ...[
            const Divider(color: Colors.black26, height: 20),
            Text(_bookName, style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('Party: ${_partyName.isNotEmpty ? _partyName : "N/A"}', style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold))),
                Expanded(child: Text('Granite: ${_graniteName.isNotEmpty ? _graniteName : "N/A"}', style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('Date: ${_bookDate.day}/${_bookDate.month}/${_bookDate.year}', style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold))),
                if (_numberPlate.isNotEmpty)
                  Expanded(child: Text('Plate: $_numberPlate', style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
              ],
            ),
            if (_linkedBlockDisplay != null && _linkedBlockDisplay!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link_rounded, size: 16, color: Colors.black54),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Linked Block: $_linkedBlockDisplay',
                        style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTableView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
            border: Border(bottom: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300, width: 1.5)),
          ),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text('No.', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? Colors.white70 : Colors.black87), textAlign: TextAlign.center)),
              const SizedBox(width: 4),
              Expanded(flex: 3, child: Text('Length', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? Colors.white70 : Colors.black87), textAlign: TextAlign.center)),
              const SizedBox(width: 4),
              Expanded(flex: 3, child: Text('Width', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? Colors.white70 : Colors.black87), textAlign: TextAlign.center)),
              const SizedBox(width: 4),
              Expanded(flex: 3, child: Text('Area', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? Colors.white70 : Colors.black87), textAlign: TextAlign.center)),
              const SizedBox(width: 4),
              Expanded(flex: 3, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? Colors.white70 : Colors.black87), textAlign: TextAlign.center)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: _slabs.length,
            itemBuilder: (context, index) {
              SlabEntry slab = _slabs[index];
              final isEven = index % 2 == 0;
              final rowBgColor = isDark
                  ? (isEven ? const Color(0xFF121212) : const Color(0xFF1A1A1A))
                  : (isEven ? Colors.white : Colors.grey.shade50);

              return Container(
                color: rowBgColor,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2, 
                      child: Text('${index + 1}', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black54), textAlign: TextAlign.center)
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      flex: 3,
                      child: _NumberInputField(
                        key: ValueKey('$_formSessionId-$index-length'),
                        label: 'L',
                        fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                        value: slab.length == 0 ? '' : slab.length.toString(),
                        onChanged: (val) {
                            _saveStateForUndo();
                            slab.length = double.tryParse(val) ?? 0.0;
                            _checkAndAutoAddRows(index, slab);
                            _saveBookLive();
                            if (mounted) setState((){});
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      flex: 3,
                      child: _NumberInputField(
                        key: ValueKey('$_formSessionId-$index-width'),
                        label: 'W',
                        fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                        value: slab.width == 0 ? '' : slab.width.toString(),
                        onChanged: (val) {
                            _saveStateForUndo();
                            slab.width = double.tryParse(val) ?? 0.0;
                            _checkAndAutoAddRows(index, slab);
                            _saveBookLive();
                            if (mounted) setState((){});
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      flex: 3,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.shade100),
                        ),
                        child: Text(
                          slab.getArea(_currentUnit).toStringAsFixed(2),
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? Colors.lightBlueAccent : Colors.blue.shade800),
                          textAlign: TextAlign.center,
                        ),
                      )
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      flex: 3,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Flexible(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: index > 0 ? () => _copyPreviousRow(index) : null,
                              child: Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: Icon(Icons.arrow_downward_rounded, size: 20, color: index > 0 ? (isDark ? Colors.blueAccent : Colors.blue.shade600) : Colors.grey),
                              ),
                            ),
                          ),
                          Flexible(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _clearRow(index),
                              child: const Padding(
                                padding: EdgeInsets.all(6.0),
                                child: Icon(Icons.clear_rounded, size: 20, color: Colors.redAccent),
                              ),
                            ),
                          ),
                        ],
                      )
                    ),
                  ]
                ),
              );
            }
          )
        )
      ]
    );
  }

  Widget _buildSlabRow(int index) {
    final slab = _slabs[index];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.blue.withOpacity(0.15) : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Slab ${index + 1}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? Colors.lightBlueAccent : Colors.blue.shade700)),
              ),
              Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.withOpacity(0.1) : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      tooltip: 'Copy from above',
                      icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                      color: isDark ? Colors.blueAccent : Colors.blue.shade600,
                      onPressed: index > 0 ? () => _copyPreviousRow(index) : null,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.red.withOpacity(0.1) : Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      tooltip: 'Clear row',
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      color: Colors.redAccent,
                      onPressed: () => _clearRow(index),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _NumberInputField(
                  key: ValueKey('$_formSessionId-$index-length'),
                  label: 'Length',
                  prefixIcon: Icons.straighten_rounded,
                  iconColor: Colors.green,
                  fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
                  value: slab.length == 0 ? '' : slab.length.toString(),
                  onChanged: (val) {
                    _saveStateForUndo();
                    slab.length = double.tryParse(val) ?? 0.0;
                    _saveBookLive();
                    if (mounted) setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NumberInputField(
                  key: ValueKey('$_formSessionId-$index-width'),
                  label: 'Width',
                  prefixIcon: Icons.height_rounded,
                  iconColor: Colors.orange,
                  fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
                  value: slab.width == 0 ? '' : slab.width.toString(),
                  onChanged: (val) {
                    _saveStateForUndo();
                    slab.width = double.tryParse(val) ?? 0.0;
                    _saveBookLive();
                    if (mounted) setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.3))
                  ),
                  child: Column(
                    children: [
                      const Text('Area', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        slab.getArea(_currentUnit).toStringAsFixed(2),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                )
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Direct Share PDF matching History Page style
  Future<void> _sharePdfDirectly() async {
    final validSlabs = _slabs.where((s) => s.length > 0 || s.width > 0).toList();
    if (validSlabs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No measurement data to share!'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    String baseName = '';
    if (_partyName.trim().isNotEmpty) {
      baseName += _partyName.trim();
    }
    if (_graniteName.trim().isNotEmpty) {
      if (baseName.isNotEmpty) baseName += '-';
      baseName += _graniteName.trim();
    }
    if (baseName.isEmpty) {
      baseName = _bookName.trim().isNotEmpty 
          ? _bookName.trim() 
          : 'Book_${_bookId ?? DateTime.now().millisecondsSinceEpoch}';
    }
    final safeName = baseName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    final pdf = _buildPdfDocument(safeName);
    final bytes = await pdf.save();

    await Printing.sharePdf(bytes: bytes, filename: '$safeName.pdf');
  }

  // --- Previous export bottom-sheet & file name prompt retained in comments as requested ---
  /*
  Future<void> _exportData() async {
    if (_slabs.isEmpty) return;
    
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('Export & Save as PDF'),
                onTap: () {
                  Navigator.pop(context);
                  _askForFileName(isPdf: true, action: 'save');
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share PDF directly'),
                onTap: () {
                  Navigator.pop(context);
                  _askForFileName(isPdf: true, action: 'share');
                },
              ),
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Export as Image(s)'),
                onTap: () {
                  Navigator.pop(context);
                  _askForFileName(isPdf: false, action: 'save');
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share Image(s) directly'),
                onTap: () {
                  Navigator.pop(context);
                  _askForFileName(isPdf: false, action: 'share');
                },
              ),
            ],
          ),
        );
      }
    );
  }
  */

  Future<Uint8List> _generatePdfData(PdfPageFormat format, {bool isPreview = false}) async {
    final pdf = _buildPdfDocument(_bookName, isPreview: isPreview);
    return pdf.save();
  }

  void _openPdfPreview() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) {
      return Scaffold(
        appBar: AppBar(title: const Text('PDF Preview')),
        body: PdfPreview(
          build: (format) => _generatePdfData(format, isPreview: true),
        ),
      );
    }));
  }

  /*
  Future<void> _askForFileName({required bool isPdf, required String action}) async {
    final String defaultName = _partyName.trim().isNotEmpty ? _partyName.trim() : _bookName.trim();
    final controller = TextEditingController(text: defaultName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter File Name'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'e.g. Block_123_Measurement'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(action == 'share' ? 'Share' : 'Export')),
          ],
        );
      }
    );
    
    if (result != null && result.isNotEmpty) {
      if (isPdf) {
        if (action == 'share') {
          await _sharePdf(result);
        } else {
          await _generateAndSavePdf(result);
        }
      } else {
        if (action == 'share') {
          await _shareImages(result);
        } else {
          await _generateAndSaveImages(result);
        }
      }
    }
  }
  */

  pw.Document _buildPdfDocument(String title, {bool isPreview = false}) {
    final pdf = pw.Document();
    
    final List<SlabEntry> expandedSlabs = [];
    for (var s in _slabs) {
      if (s.length <= 0 && s.width <= 0) continue;
      expandedSlabs.add(s);
    }
    
    if (expandedSlabs.isEmpty) {
      pdf.addPage(pw.Page(
        pageTheme: pw.PageTheme(
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(color: PdfColors.white),
          ),
        ),
        build: (context) => pw.Center(child: pw.Text('No Data'))
      ));
      return pdf;
    }

    for (int i = 0; i < expandedSlabs.length; i += 100) {
      final chunk = expandedSlabs.sublist(i, i + 100 > expandedSlabs.length ? expandedSlabs.length : i + 100);
      final leftChunk = chunk.sublist(0, chunk.length > 50 ? 50 : chunk.length);
      final rightChunk = chunk.length > 50 ? chunk.sublist(50) : <SlabEntry>[];
      
      final bool isLastPage = (i + 100) >= expandedSlabs.length;
      final int pageTotalQuantity = chunk.length;
      final double pageTotalArea = chunk.fold<double>(0.0, (sum, slab) => sum + slab.getArea(_currentUnit));

      pdf.addPage(
        pw.Page(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(16),
            buildBackground: (context) => pw.FullPage(
              ignoreMargins: true,
              child: pw.Container(color: PdfColors.white),
            ),
          ),
          build: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Center(
                        child: pw.Text('ESTIMATED SHEET', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Party: $_partyName', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Plate: ${(_numberPlate.isNotEmpty ? _numberPlate : "N/A")}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        ]
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Granite: ${(_graniteName.isNotEmpty ? _graniteName : "N/A")}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Date: ${_bookDate.day.toString().padLeft(2, '0')}/${_bookDate.month.toString().padLeft(2, '0')}/${_bookDate.year}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        ]
                      ),
                    ]
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Expanded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(child: _buildPdfTable(context, leftChunk)),
                      pw.SizedBox(width: 20),
                      pw.Expanded(child: rightChunk.isNotEmpty ? _buildPdfTable(context, rightChunk) : pw.Container()),
                    ]
                  )
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Page Slabs: $pageTotalQuantity', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                    pw.Text('Page Area: ${pageTotalArea.toStringAsFixed(2)} $_displayUnit', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  ]
                ),
                if (isLastPage) ...[
                  pw.Divider(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Slabs: $_totalQuantity', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Total Area: ${_totalArea.toStringAsFixed(2)} $_displayUnit', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    ]
                  ),
                ],
                pw.SizedBox(height: 10),
                if (isPreview)
                  pw.Center(
                    child: pw.Text('developed_by'.tr + ' Panchasara Poojan', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  )
              ]
            );
          }
        )
      );
    }
    return pdf;
  }

  pw.Widget _buildPdfTable(pw.Context context, List<SlabEntry> data) {
    return pw.TableHelper.fromTextArray(
      context: context,
      cellAlignment: pw.Alignment.center,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 1, horizontal: 2),
      headers: ['No.', 'L', 'W', 'Area'],
      data: data.map<List<String>>((s) {
        return [
          '${s.slabNo}',
          s.length.toString(),
          s.width.toString(),
          s.getArea(_currentUnit).toStringAsFixed(2)
        ];
      }).toList(),
    );
  }

  Future<void> _sharePdf(String fileName) async {
    final pdf = _buildPdfDocument(fileName);
    final bytes = await pdf.save();
    
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName.pdf');
    await file.writeAsBytes(bytes);
    
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'Slab Measurement: $fileName'));
  }

  Future<void> _generateAndSavePdf(String fileName) async {
    final pdf = _buildPdfDocument(fileName);
    final bytes = await pdf.save();
    
    String? outputFile = await FilePicker.saveFile(
      dialogTitle: 'Save Measurement PDF',
      fileName: '$fileName.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      bytes: bytes,
    );
    
    if (outputFile != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF downloaded successfully to: $outputFile'), backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _generateAndSaveImages(String fileName) async {
    final pdf = _buildPdfDocument(fileName);
    final bytes = await pdf.save();
    
    String? selectedDirectory = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select folder to save images',
    );
    
    if (selectedDirectory != null) {
      int pageNumber = 1;
      await for (final page in Printing.raster(bytes, dpi: 300)) {
        final imageFile = File('$selectedDirectory/${fileName}_page_$pageNumber.png');
        final pngBytes = await page.toPng();
        await imageFile.writeAsBytes(pngBytes);
        pageNumber++;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Images downloaded successfully to: $selectedDirectory'), backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _shareImages(String fileName) async {
    final pdf = _buildPdfDocument(fileName);
    final bytes = await pdf.save();
    
    final dir = await getTemporaryDirectory();
    int pageNumber = 1;
    List<XFile> imageFiles = [];
    
    await for (final page in Printing.raster(bytes, dpi: 300)) {
      final imageFile = File('${dir.path}/${fileName}_page_$pageNumber.png');
      final pngBytes = await page.toPng();
      await imageFile.writeAsBytes(pngBytes);
      imageFiles.add(XFile(imageFile.path));
      pageNumber++;
    }
    
    if (imageFiles.isNotEmpty) {
      await SharePlus.instance.share(ShareParams(files: imageFiles, text: 'Slab Measurement: $fileName'));
    }
  }
}

class _NumberInputField extends StatefulWidget {
  final String label;
  final String value;
  final Function(String) onChanged;
  final IconData? prefixIcon;
  final Color? iconColor;
  final Color? fillColor;
  final bool showPlusMinus;

  const _NumberInputField({
    Key? key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.prefixIcon,
    this.iconColor,
    this.fillColor,
    this.showPlusMinus = false,
  }) : super(key: key);

  @override
  State<_NumberInputField> createState() => _NumberInputFieldState();
}

class _NumberInputFieldState extends State<_NumberInputField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _increment() {
    double val = double.tryParse(_controller.text) ?? 0;
    _controller.text = (val + 1).toString().replaceAll(RegExp(r'\.0$'), '');
    widget.onChanged(_controller.text);
  }

  void _decrement() {
    double val = double.tryParse(_controller.text) ?? 0;
    if (val > 0) {
      _controller.text = (val - 1).toString().replaceAll(RegExp(r'\.0$'), '');
      widget.onChanged(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputField = TextFormField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: const TextStyle(fontSize: 12),
        prefixIcon: widget.prefixIcon != null 
          ? Icon(widget.prefixIcon, size: 18, color: widget.iconColor ?? Colors.grey)
          : null,
        alignLabelWithHint: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        isDense: true,
        filled: true,
        fillColor: widget.fillColor ?? Theme.of(context).scaffoldBackgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: widget.iconColor ?? AppColors.primary, width: 2),
        ),
      ),
      onChanged: widget.onChanged,
    );

    if (widget.showPlusMinus) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            InkWell(
              onTap: _decrement,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.remove_rounded, size: 20, color: Colors.redAccent),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(child: inputField),
            const SizedBox(width: 4),
            InkWell(
              onTap: _increment,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.add_rounded, size: 20, color: Colors.green),
              ),
            ),
          ],
        ),
      );
    }
    
    return inputField;
  }
}

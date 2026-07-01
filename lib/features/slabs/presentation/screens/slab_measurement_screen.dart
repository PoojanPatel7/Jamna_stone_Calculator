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
import '../../../../main.dart'; // For themeNotifier
import '../../../../core/localization/app_translations.dart';

class AppColors {
  static const Color amber = Color(0xFFFFC107);
  static const Gradient amberGradient = LinearGradient(
    colors: [Color(0xFFFFD54F), Color(0xFFFFC107)],
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
      
      if (_slabs.length < 200) {
        for (int i = _slabs.length; i < 200; i++) {
          _slabs.add(SlabEntry(slabNo: i + 1));
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
      date: _bookDate,
      unit: _currentUnit,
      slabs: _slabs,
    );
    StorageService.saveBook(book);
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
  
  Widget _buildCreateBookView() {
    final graniteController = TextEditingController();
    final partyController = TextEditingController();
    final plateController = TextEditingController();
    DateTime tempDate = DateTime.now();

    return StatefulBuilder(builder: (context, setLocalState) {
      return Scaffold(
        appBar: AppBar(title: Text('new_book'.tr), centerTitle: true),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('create_start'.tr, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    TextField(
                      controller: graniteController,
                      decoration: InputDecoration(
                        labelText: 'granite_name'.tr,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.landscape),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: partyController,
                      decoration: InputDecoration(
                        labelText: 'party_name'.tr,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: plateController,
                      decoration: InputDecoration(
                        labelText: 'number_plate'.tr,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.directions_car),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text('date'.tr),
                      subtitle: Text('${tempDate.day}/${tempDate.month}/${tempDate.year}'),
                      leading: const Icon(Icons.calendar_today),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: tempDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setLocalState(() => tempDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _currentUnit,
                      decoration: InputDecoration(
                        labelText: 'unit'.tr,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.straighten),
                      ),
                      items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setLocalState(() {
                            _currentUnit = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
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
                          _slabs = List.generate(200, (i) => SlabEntry(slabNo: i + 1));
                          _recalculateSlabNumbers();
                          _saveBookLive();
                        });
                      },
                      child: Text('create_start'.tr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                case 'export': _exportData(); break;
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
                      _slabs.clear();
                      _nextSlabNo = 1;
                      _recalculateSlabNumbers();
                      _saveBookLive();
                    });
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'save', child: Row(children: [Icon(Icons.save_rounded, size: 20), SizedBox(width: 8), Text('Save Book')])),
              const PopupMenuItem(value: 'export', child: Row(children: [Icon(Icons.share_rounded, size: 20), SizedBox(width: 8), Text('Export Data')])),
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80), 
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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isLandscape ? 4 : 12),
      margin: EdgeInsets.fromLTRB(16, 8, 16, isLandscape ? 4 : 12),
      decoration: BoxDecoration(
        gradient: AppColors.amberGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.amber.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Area', style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('${_totalArea.toStringAsFixed(2)} $_currentUnit', style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w900)),
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
                  dropdownColor: AppColors.amber,
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
        ],
      ),
    );
  }

  Widget _buildTableView() {
    return Column(
      children: [
        Container(
          color: AppColors.amber.withOpacity(0.2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: const Row(
            children: [
              Expanded(flex: 3, child: Text('Slab\nNo.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center)),
              SizedBox(width: 4),
              Expanded(flex: 4, child: Text('Length', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center)),
              SizedBox(width: 4),
              Expanded(flex: 4, child: Text('Width', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center)),
              SizedBox(width: 4),
              Expanded(flex: 4, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center)),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _slabs.length,
            separatorBuilder: (c, i) => Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.5)),
            itemBuilder: (context, index) {
              SlabEntry slab = _slabs[index];
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3, 
                      child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      flex: 4,
                      child: _NumberInputField(
                        key: ValueKey('$_formSessionId-$index-length'),
                        label: 'L',
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
                      flex: 4,
                      child: _NumberInputField(
                        key: ValueKey('$_formSessionId-$index-width'),
                        label: 'W',
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
                      flex: 4,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Flexible(
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              iconSize: 22,
                              tooltip: 'Copy from above row',
                              icon: const Icon(Icons.arrow_downward_rounded, color: Colors.blueAccent),
                              onPressed: index > 0 ? () => _copyPreviousRow(index) : null,
                            ),
                          ),
                          Flexible(
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              iconSize: 22,
                              tooltip: 'Clear row',
                              icon: const Icon(Icons.clear_rounded, color: Colors.redAccent),
                              onPressed: () => _clearRow(index),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.amber.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Slab ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.amber)),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Copy from above',
                    icon: const Icon(Icons.arrow_downward_rounded, color: Colors.blueAccent),
                    onPressed: index > 0 ? () => _copyPreviousRow(index) : null,
                  ),
                  IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.clear_rounded, color: Colors.redAccent),
                    onPressed: () => _clearRow(index),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _NumberInputField(
                  key: ValueKey('$_formSessionId-$index-length'),
                  label: 'Length',
                  prefixIcon: Icons.straighten_rounded,
                  iconColor: Colors.green,
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
                  value: slab.width == 0 ? '' : slab.width.toString(),
                  onChanged: (val) {
                    _saveStateForUndo();
                    slab.width = double.tryParse(val) ?? 0.0;
                    _saveBookLive();
                    if (mounted) setState(() {});
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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

  Future<void> _askForFileName({required bool isPdf, required String action}) async {
    final controller = TextEditingController(text: _bookName);
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
                    pw.Text('Total Slabs: $_totalQuantity', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Total Area: ${_totalArea.toStringAsFixed(2)} $_currentUnit', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  ]
                ),
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
  final bool showPlusMinus;

  const _NumberInputField({
    Key? key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.prefixIcon,
    this.iconColor,
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
        fillColor: Theme.of(context).scaffoldBackgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: widget.iconColor ?? AppColors.amber, width: 2),
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

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
  const SlabMeasurementScreen({super.key, this.loadedBook});

  @override
  State<SlabMeasurementScreen> createState() => _SlabMeasurementScreenState();
}

class _SlabMeasurementScreenState extends State<SlabMeasurementScreen> {
  List<SlabEntry> _slabs = [];
  int _nextSlabNo = 1;
  String _currentUnit = 'Feet';
  String? _bookId;
  String _bookName = 'Untitled Book';
  
  final List<String> _units = ['Feet', 'Inches', 'Cm', 'Meter'];
  
  List<String> _undoStack = [];
  List<String> _redoStack = [];
  String _formSessionId = UniqueKey().toString();

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    if (widget.loadedBook != null) {
      _bookId = widget.loadedBook!.id;
      _bookName = widget.loadedBook!.name;
      _currentUnit = widget.loadedBook!.unit;
      _slabs = widget.loadedBook!.slabs.map((e) => SlabEntry(
        slabNo: e.slabNo, length: e.length, width: e.width, quantity: e.quantity
      )).toList();
      _recalculateSlabNumbers();
    } else {
      final draft = await StorageService.loadDraft();
      if (draft['slabs'].isNotEmpty) {
        _slabs = draft['slabs'];
        _currentUnit = draft['unit'];
        _recalculateSlabNumbers();
      } else {
        _addNewSlab();
      }
    }
  }

  void _saveDraft() {
    // Always save to draft area — never silently overwrite saved history
    StorageService.saveDraft(_slabs, _currentUnit);
  }

  void _recalculateSlabNumbers() {
    int currentNo = 1;
    for (int i = 0; i < _slabs.length; i++) {
      _slabs[i].slabNo = currentNo;
      currentNo += _slabs[i].quantity;
    }
    _nextSlabNo = currentNo;
    setState(() {});
  }

  void _saveStateForUndo() {
    _undoStack.add(jsonEncode(_slabs.map((e) => e.toJson()).toList()));
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
      _saveDraft();
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
      _saveDraft();
    });
  }

  void _addNewSlab() {
    _saveStateForUndo();
    setState(() {
      _slabs.add(SlabEntry(slabNo: _nextSlabNo));
      _recalculateSlabNumbers();
      _saveDraft();
    });
  }
  
  void _duplicateSlab(int index) {
    _saveStateForUndo();
    setState(() {
      final source = _slabs[index];
      _slabs.insert(index + 1, SlabEntry(
        slabNo: 0, 
        length: source.length,
        width: source.width,
        quantity: source.quantity,
      ));
      _recalculateSlabNumbers();
      _saveDraft();
    });
  }

  Future<void> _removeSlab(int index) async {
    final slab = _slabs[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Slab?'),
          content: Text('Are you sure you want to delete Slab #${slab.slabNo}?\nLength: ${slab.length}\nWidth: ${slab.width}\nQty: ${slab.quantity}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, true), 
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      }
    );
    
    if (confirm == true) {
      _saveStateForUndo();
      setState(() {
        _slabs.removeAt(index);
        _recalculateSlabNumbers();
        _saveDraft();
      });
    }
  }

  double get _totalArea {
    return _slabs.fold<double>(0.0, (double sum, slab) => sum + slab.getArea(_currentUnit));
  }
  
  int get _totalQuantity {
    return _slabs.fold<int>(0, (int sum, slab) => sum + slab.quantity);
  }
  
  Future<void> _saveBookAction() async {
    // If editing an existing book, default name has "(New)" suffix
    String defaultName = _bookName;
    if (widget.loadedBook != null) {
      // Always save as a new copy when editing an existing book
      if (!defaultName.endsWith('(New)')) {
        defaultName = '$defaultName (New)';
      }
    }
    
    final controller = TextEditingController(text: defaultName);
    final resultName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(widget.loadedBook != null ? 'Save as New Copy' : 'Save Slab Book'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.loadedBook != null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Original record will be kept safe. This will save as a new copy.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'Enter book name'),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
          ],
        );
      }
    );
    
    if (resultName != null && resultName.trim().isNotEmpty) {
      _bookName = resultName.trim();
      
      if (widget.loadedBook != null) {
        // Always create a NEW entry — never overwrite original
        final newId = DateTime.now().millisecondsSinceEpoch.toString();
        final book = SlabBook(
          id: newId,
          name: _bookName,
          date: DateTime.now(),
          unit: _currentUnit,
          slabs: _slabs,
        );
        await StorageService.saveBook(book);
        _bookId = newId;
      } else {
        // Brand new book (not editing)
        final book = SlabBook(
          id: _bookId ?? DateTime.now().millisecondsSinceEpoch.toString(),
          name: _bookName,
          date: DateTime.now(),
          unit: _currentUnit,
          slabs: _slabs,
        );
        await StorageService.saveBook(book);
        if (_bookId == null) {
          await StorageService.clearDraft();
          _bookId = book.id;
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Book saved successfully'), backgroundColor: Colors.green),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        if (_slabs.isEmpty || (_slabs.length == 1 && _slabs[0].length == 0 && _slabs[0].width == 0)) {
          if (mounted) Navigator.of(context).pop();
          return;
        }
        
        final result = await showDialog<String>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Save Changes?'),
              content: const Text('Do you want to save this slab book before leaving?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, 'discard'), 
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Discard')
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, 'cancel'), 
                  child: const Text('Cancel')
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, 'save'), 
                  child: const Text('Save')
                ),
              ],
            );
          }
        );
        
        if (result == 'discard') {
          if (mounted) Navigator.of(context).pop();
        } else if (result == 'save') {
          await _saveBookAction();
          if (mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.loadedBook != null ? 'Edit: $_bookName' : 'Slab Measurement'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
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
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'PDF Preview',
            onPressed: _openPdfPreview,
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'History',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.save_rounded),
            tooltip: 'Save Book',
            onPressed: _saveBookAction,
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Export',
            onPressed: _exportData,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Clear All',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Clear All Rows?'),
                    content: const Text(
                      'This will remove all measurement rows from the current screen. Saved books in History will NOT be affected.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
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
                  _addNewSlab();
                  _saveDraft();
                });
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTopSummary(),
          Expanded(
            child: ListView.separated(
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewSlab,
        backgroundColor: AppColors.amber,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Row', style: TextStyle(fontWeight: FontWeight.bold)),
      ).animate().scale(delay: 300.ms),
    ));
  }

  Widget _buildTopSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        gradient: AppColors.amberGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.amber.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Unit: ', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _currentUnit,
                  dropdownColor: AppColors.amber,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.black87),
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _currentUnit = val;
                        _saveDraft();
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Text('Total Slabs', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
                  Text('$_totalQuantity', style: const TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(width: 1, height: 40, color: Colors.black26),
              Column(
                children: [
                  Text('Total Area ($_currentUnit)', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
                  Text(_totalArea.toStringAsFixed(2), style: const TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlabRow(int index) {
    final slab = _slabs[index];
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.amber.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
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
                  color: AppColors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  slab.quantity <= 1 ? 'Slab: ${slab.slabNo}' : 'Slab: ${slab.slabNo}-${slab.slabNo + slab.quantity - 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.amber),
                ),
              ),
              Row(
                children: [
                  Text('Area: ${slab.getArea(_currentUnit).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _duplicateSlab(index),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.copy_rounded, color: Colors.blueAccent, size: 20),
                    ),
                  ),
                  InkWell(
                    onTap: () => _removeSlab(index),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildNumberInput(
                  key: ValueKey('$_formSessionId-$index-length'),
                  label: 'Length',
                  initialValue: slab.length == 0 ? '' : slab.length.toString(),
                  onChanged: (val) {
                    _saveStateForUndo();
                    slab.length = double.tryParse(val) ?? 0.0;
                    setState(() {});
                    _saveDraft();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNumberInput(
                  key: ValueKey('$_formSessionId-$index-width'),
                  label: 'Width',
                  initialValue: slab.width == 0 ? '' : slab.width.toString(),
                  onChanged: (val) {
                    _saveStateForUndo();
                    slab.width = double.tryParse(val) ?? 0.0;
                    setState(() {});
                    _saveDraft();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNumberInput(
                  key: ValueKey('$_formSessionId-$index-qty'),
                  label: 'Qty',
                  initialValue: slab.quantity.toString(),
                  onChanged: (val) {
                    _saveStateForUndo();
                    slab.quantity = int.tryParse(val) ?? 1;
                    _recalculateSlabNumbers();
                    _saveDraft();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumberInput({Key? key, required String label, required String initialValue, required Function(String) onChanged}) {
    return TextFormField(
      key: key,
      initialValue: initialValue,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        alignLabelWithHint: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        isDense: true,
        filled: true,
        fillColor: Theme.of(context).scaffoldBackgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.amber),
        ),
      ),
      onChanged: onChanged,
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
            ],
          ),
        );
      }
    );
  }

  Future<Uint8List> _generatePdfData(PdfPageFormat format) async {
    final pdf = _buildPdfDocument(_bookName);
    return pdf.save();
  }

  void _openPdfPreview() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) {
      return Scaffold(
        appBar: AppBar(title: const Text('PDF Preview')),
        body: PdfPreview(
          build: _generatePdfData,
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
        await _generateAndSaveImages(result);
      }
    }
  }

  pw.Document _buildPdfDocument(String title) {
    final pdf = pw.Document();
    
    final List<SlabEntry> expandedSlabs = [];
    for (var s in _slabs) {
      for (int i = 0; i < s.quantity; i++) {
        expandedSlabs.add(SlabEntry(
          slabNo: s.slabNo + i,
          length: s.length,
          width: s.width,
          quantity: 1,
        ));
      }
    }
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(title, style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Unit: $_currentUnit', style: pw.TextStyle(fontSize: 18)),
                ]
              ),
            ),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              context: context,
              cellAlignment: pw.Alignment.center,
              headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 16),
              headers: ['No.', 'Length', 'Width', 'Area'],
              data: expandedSlabs.map<List<String>>((s) {
                return [
                  '${s.slabNo}',
                  s.length.toString(),
                  s.width.toString(),
                  '${s.getArea(_currentUnit).toStringAsFixed(2)} $_currentUnit'
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total Slabs: $_totalQuantity', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text('Total Area: ${_totalArea.toStringAsFixed(2)} $_currentUnit', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ]
            )
          ];
        }
      )
    );
    return pdf;
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
}

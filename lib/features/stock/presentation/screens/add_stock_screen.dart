import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/stock_models.dart';
import '../../services/stock_storage_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AddStockScreen extends StatefulWidget {
  final VoidCallback onSave;
  final StockEntry? entryToEdit;

  const AddStockScreen({super.key, required this.onSave, this.entryToEdit});

  @override
  State<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends State<AddStockScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _slabCountController = TextEditingController();
  final _areaController = TextEditingController();
  
  bool _isPolished = true;
  DateTime _selectedDate = DateTime.now();
  
  List<String> _blockNames = [];
  String? _selectedBlockName;
  String _selectedBlockType = 'Marble'; // Default to Marble
  
  @override
  void initState() {
    super.initState();
    if (widget.entryToEdit != null) {
      _selectedBlockType = widget.entryToEdit!.blockTypeName;
      _selectedBlockName = widget.entryToEdit!.blockName;
      _isPolished = widget.entryToEdit!.isPolished;
      _slabCountController.text = widget.entryToEdit!.totalSlabCount.toString();
      _areaController.text = widget.entryToEdit!.estimatedArea.toString();
      _selectedDate = widget.entryToEdit!.date;
    }
    _loadBlockNames();
  }
  
  Future<void> _loadBlockNames() async {
    final names = await StockStorageService.loadBlockNames();
    setState(() {
      _blockNames = names;
      if (widget.entryToEdit != null && !names.contains(widget.entryToEdit!.blockName)) {
        _blockNames.add(widget.entryToEdit!.blockName);
      }
      if (_blockNames.isNotEmpty && _selectedBlockName == null) {
        _selectedBlockName = _blockNames.first;
      }
    });
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showAddBlockNameDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Block Name'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Block Name',
              hintText: 'e.g., Block A',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  await StockStorageService.saveBlockName(name);
                  await _loadBlockNames();
                  setState(() {
                    _selectedBlockName = name;
                  });
                  if (mounted) Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _saveStock() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedBlockName == null || _selectedBlockName!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select or add a Block Name')),
        );
        return;
      }
      
      final stockEntry = StockEntry(
        id: widget.entryToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        blockName: _selectedBlockName!,
        isPolished: _isPolished,
        totalSlabCount: int.tryParse(_slabCountController.text) ?? 0,
        estimatedArea: double.tryParse(_areaController.text) ?? 0.0,
        date: _selectedDate,
        blockTypeId: _selectedBlockType,
        blockTypeName: _selectedBlockType,
      );
      
      await StockStorageService.saveStockEntry(stockEntry);
      widget.onSave(); // Navigate back or refresh
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Stock'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Block Type Segmented Control
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Block Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Marble'),
                              value: 'Marble',
                              groupValue: _selectedBlockType,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) => setState(() => _selectedBlockType = val!),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Granite'),
                              value: 'Granite',
                              groupValue: _selectedBlockType,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) => setState(() => _selectedBlockType = val!),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ).animate().fade().slideY(begin: 0.1, duration: 400.ms),
              const SizedBox(height: 16),
              
              // Block Name Selection with + Button
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Block Name',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                      ),
                      value: _selectedBlockName,
                      items: _blockNames.map((name) {
                        return DropdownMenuItem(
                          value: name,
                          child: Text(name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedBlockName = val;
                        });
                      },
                      validator: (val) => val == null ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: _showAddBlockNameDialog,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).primaryColor),
                      ),
                      child: Icon(Icons.add, color: Theme.of(context).primaryColor, size: 28),
                    ),
                  ),
                ],
              ).animate().fade().slideY(begin: 0.1, delay: 100.ms, duration: 400.ms),
              const SizedBox(height: 16),
              
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text('Polished'),
                              value: true,
                              groupValue: _isPolished,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) => setState(() => _isPolished = val!),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text('Unpolished'),
                              value: false,
                              groupValue: _isPolished,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) => setState(() => _isPolished = val!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _slabCountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Total Slab Count',
                          prefixIcon: const Icon(Icons.layers),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) => val == null || val.isEmpty ? 'Enter count' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _areaController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Estimated Area (Sq Ft)',
                          prefixIcon: const Icon(Icons.square_foot),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) => val == null || val.isEmpty ? 'Enter area' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      ListTile(
                        title: const Text('Date'),
                        subtitle: Text(DateFormat.yMMMd().format(_selectedDate)),
                        leading: const Icon(Icons.calendar_today),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onTap: () => _selectDate(context),
                      ),
                    ],
                  ),
                ),
              ).animate().fade().slideY(begin: 0.1, delay: 200.ms, duration: 400.ms),
              
              const SizedBox(height: 32),
              
              ElevatedButton.icon(
                onPressed: _saveStock,
                icon: const Icon(Icons.save),
                label: const Text('Save Stock', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ).animate().fade().scale(delay: 300.ms, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}


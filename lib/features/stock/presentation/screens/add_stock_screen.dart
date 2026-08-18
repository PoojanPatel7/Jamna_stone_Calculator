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
  final _blockNumberController = TextEditingController();
  
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
      _blockNumberController.text = widget.entryToEdit!.blockNumber;
      _isPolished = widget.entryToEdit!.isPolished;
      _slabCountController.text = widget.entryToEdit!.totalSlabCount.toString();
      _areaController.text = widget.entryToEdit!.estimatedArea.toString();
      _selectedDate = widget.entryToEdit!.date;
    }
    _loadData();
  }
  
  Future<void> _loadData() async {
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
                  await _loadData();
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
        blockNumber: _blockNumberController.text.trim(),
        isPolished: _isPolished,
        totalSlabCount: int.tryParse(_slabCountController.text) ?? 0,
        estimatedArea: double.tryParse(_areaController.text) ?? 0.0,
        date: _selectedDate,
        blockTypeId: _selectedBlockType,
        blockTypeName: _selectedBlockType,
        isSold: widget.entryToEdit?.isSold ?? false,
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
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Block Type', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
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
              
              TextFormField(
                controller: _blockNumberController,
                maxLength: 25,
                decoration: InputDecoration(
                  labelText: 'Block Number',
                  prefixIcon: const Icon(Icons.tag),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ).animate().fade().slideY(begin: 0.1, delay: 50.ms, duration: 400.ms),
              const SizedBox(height: 16),
              
              // Block Name Selection with + Button
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _blockNames.contains(_selectedBlockName) ? _selectedBlockName : null,
                      decoration: InputDecoration(
                        labelText: 'Block Name',
                        prefixIcon: const Icon(Icons.inventory_2),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                      ),
                      items: _blockNames.map((name) {
                        return DropdownMenuItem(value: name, child: Text(name));
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedBlockName = val;
                        });
                      },
                      validator: (val) => val == null ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _showAddBlockNameDialog,
                    icon: const Icon(Icons.add_circle),
                    color: Colors.blue,
                    iconSize: 36,
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

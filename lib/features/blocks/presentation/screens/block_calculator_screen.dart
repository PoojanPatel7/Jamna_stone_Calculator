import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';


class BlockCalculatorScreen extends StatefulWidget {
  const BlockCalculatorScreen({super.key});

  @override
  State<BlockCalculatorScreen> createState() => _BlockCalculatorScreenState();
}

class _BlockCalculatorScreenState extends State<BlockCalculatorScreen> {
  final _lengthCtrl = TextEditingController();
  final _widthCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  
  int _weightDivisor = 22500;
  double _computedWeight = 0.0;
  double _computedVolume = 0.0;
  
  List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _lengthCtrl.addListener(_calculateWeight);
    _widthCtrl.addListener(_calculateWeight);
    _heightCtrl.addListener(_calculateWeight);
    _loadHistory();
  }
  
  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history = prefs.getStringList('block_calc_history') ?? [];
    });
  }
  
  Future<void> _saveToHistory() async {
    if (_computedWeight <= 0) return;
    
    final l = _lengthCtrl.text.isEmpty ? "0" : _lengthCtrl.text;
    final w = _widthCtrl.text.isEmpty ? "0" : _widthCtrl.text;
    final h = _heightCtrl.text.isEmpty ? "0" : _heightCtrl.text;
    
    final entry = "L:$l × W:$w × H:$h | Div: $_weightDivisor | Wt: ${_computedWeight.toStringAsFixed(3)} Tons";
    
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history.insert(0, entry);
    });
    await prefs.setStringList('block_calc_history', _history);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to history'), duration: Duration(seconds: 1)),
      );
    }
  }
  
  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history.clear();
    });
    await prefs.remove('block_calc_history');
  }

  @override
  void dispose() {
    _lengthCtrl.dispose();
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  void _calculateWeight() {
    final l = double.tryParse(_lengthCtrl.text) ?? 0.0;
    final w = double.tryParse(_widthCtrl.text) ?? 0.0;
    final h = double.tryParse(_heightCtrl.text) ?? 0.0;
    
    final volume = l * w * h;
    final weight = _weightDivisor > 0 ? volume / _weightDivisor : 0.0;
    
    setState(() {
      _computedVolume = volume;
      _computedWeight = weight;
    });
  }

  void _clearAll() {
    _lengthCtrl.clear();
    _widthCtrl.clear();
    _heightCtrl.clear();
    setState(() {
      _computedVolume = 0;
      _computedWeight = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Block Calculator'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Clear',
            onPressed: _clearAll,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Hero(
                tag: 'block_calculator_card',
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.blueAccent.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.view_in_ar_rounded, size: 48, color: Colors.blueAccent),
                      const SizedBox(height: 16),
                      Text(
                        '${_computedWeight.toStringAsFixed(3)} Tons',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Volume: ${_computedVolume.toStringAsFixed(2)} cubic inches',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              const Text(
                'Dimensions (Inches)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(child: _buildInputField('Length', _lengthCtrl)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildInputField('Width', _widthCtrl)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildInputField('Height', _heightCtrl)),
                ],
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
              
              const SizedBox(height: 32),
              
              const Text(
                'Weight Divisor (Density)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1),
              const SizedBox(height: 8),
              Text(
                'Select the constant based on stone type',
                style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodySmall?.color),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 16),
              
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [22500, 25000, 27500, 30000].map((divisor) {
                  final isSelected = _weightDivisor == divisor;
                  return ChoiceChip(
                    label: Text('$divisor'),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _weightDivisor = divisor);
                        _calculateWeight();
                      }
                    },
                    selectedColor: Colors.blueAccent.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.blueAccent : null,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? Colors.blueAccent : Colors.grey.withOpacity(0.3),
                      ),
                    ),
                  );
                }).toList(),
                ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
              
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _computedWeight > 0 ? _saveToHistory : null,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save to History'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
              ).animate().fadeIn(delay: 500.ms),
              
              if (_history.isNotEmpty) ...[
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'History',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: _clearHistory,
                      child: const Text('Clear History', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ).animate().fadeIn(delay: 600.ms),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const Icon(Icons.history_rounded, color: Colors.blueAccent),
                        title: Text(_history[index], style: const TextStyle(fontSize: 14)),
                      ),
                    );
                  },
                ).animate().fadeIn(delay: 700.ms),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
        ),
        filled: true,
        fillColor: Theme.of(context).cardColor,
      ),
    );
  }
}

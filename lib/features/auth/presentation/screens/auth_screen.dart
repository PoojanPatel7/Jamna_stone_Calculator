import 'package:flutter/material.dart';
import '../../../slabs/services/auth_service.dart';
import '../../../main/presentation/screens/main_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isPinSet = false;
  bool _isLoading = true;
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final isSet = await AuthService.isPinSet();
    setState(() {
      _isPinSet = isSet;
      _isLoading = false;
    });
    
    if (isSet) {
      // Pin is set, user must enter it manually
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
  }

  void _onNumberTap(String num) {
    setState(() {
      _error = '';
      if (!_isPinSet) {
        if (!_isConfirming) {
          if (_pin.length < 4) _pin += num;
          if (_pin.length == 4) {
            _isConfirming = true;
          }
        } else {
          if (_confirmPin.length < 4) _confirmPin += num;
          if (_confirmPin.length == 4) {
            if (_pin == _confirmPin) {
              AuthService.setPin(_pin).then((_) => _navigateToHome());
            } else {
              _error = 'PINs do not match. Try again.';
              _pin = '';
              _confirmPin = '';
              _isConfirming = false;
            }
          }
        }
      } else {
        if (_pin.length < 4) _pin += num;
        if (_pin.length == 4) {
          AuthService.verifyPin(_pin).then((isValid) {
            if (isValid) {
              _navigateToHome();
            } else {
              setState(() {
                _error = 'Incorrect PIN';
                _pin = '';
              });
            }
          });
        }
      }
    });
  }

  void _onDeleteTap() {
    setState(() {
      _error = '';
      if (!_isPinSet) {
        if (!_isConfirming && _pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        } else if (_isConfirming && _confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else if (_isConfirming && _confirmPin.isEmpty) {
          _isConfirming = false;
          _pin = _pin.substring(0, _pin.length - 1);
        }
      } else {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    String title = _isPinSet ? 'Enter PIN' : (_isConfirming ? 'Confirm PIN' : 'Set a 4-Digit PIN');
    String currentInput = _isPinSet ? _pin : (_isConfirming ? _confirmPin : _pin);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_rounded, size: 64, color: Color(0xFFFFC107)).animate().scale(),
            const SizedBox(height: 24),
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('To secure your slab records', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < currentInput.length ? const Color(0xFFFFC107) : Colors.transparent,
                    border: Border.all(color: const Color(0xFFFFC107), width: 2),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            if (_error.isNotEmpty)
              Text(_error, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
                  .animate().shake(),
            const SizedBox(height: 32),
            _buildKeypad(),
            if (_isPinSet) ...[
              const SizedBox(height: 24),
              TextButton(
                onPressed: _showResetDialog,
                child: const Text('Forgot Password?', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showResetDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Developer Reset'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Enter Developer PIN'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('Cancel')
            ),
            ElevatedButton(
              onPressed: () async {
                if (controller.text == '9009') {
                  await AuthService.removePin();
                  if (mounted) {
                    Navigator.pop(context);
                    setState(() {
                      _isPinSet = false;
                      _pin = '';
                      _confirmPin = '';
                      _isConfirming = false;
                      _error = 'PIN Reset Successful. Set a new PIN.';
                    });
                  }
                } else {
                  Navigator.pop(context);
                  setState(() {
                    _error = 'Invalid Developer PIN';
                  });
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Reset'),
            ),
          ],
        );
      }
    );
  }

  Widget _buildKeypad() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _buildKey('1'), _buildKey('2'), _buildKey('3')
          ]),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _buildKey('4'), _buildKey('5'), _buildKey('6')
          ]),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _buildKey('7'), _buildKey('8'), _buildKey('9')
          ]),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            const SizedBox(width: 70),
            _buildKey('0'),
            _buildDeleteKey(),
          ]),
        ],
      ),
    );
  }

  Widget _buildKey(String text) {
    return InkWell(
      onTap: () => _onNumberTap(text),
      borderRadius: BorderRadius.circular(35),
      child: Container(
        width: 70,
        height: 70,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
          ]
        ),
        child: Text(text, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildDeleteKey() {
    return InkWell(
      onTap: _onDeleteTap,
      borderRadius: BorderRadius.circular(35),
      child: Container(
        width: 70,
        height: 70,
        alignment: Alignment.center,
        child: const Icon(Icons.backspace_outlined, size: 28),
      ),
    );
  }
}

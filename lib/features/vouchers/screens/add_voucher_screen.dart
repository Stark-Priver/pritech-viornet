import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/database/database.dart';
import '../../../core/providers/providers.dart';

class AddVoucherScreen extends ConsumerStatefulWidget {
  const AddVoucherScreen({super.key});

  @override
  ConsumerState<AddVoucherScreen> createState() => _AddVoucherScreenState();
}

class _AddVoucherScreenState extends ConsumerState<AddVoucherScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _priceController = TextEditingController();
  int _duration = 7;
  String _selectedPackage = '1 Week';
  final List<Map<String, dynamic>> _packages = [
    {'name': '1 Week', 'duration': 7, 'price': 5000.0},
    {'name': '2 Weeks', 'duration': 14, 'price': 9000.0},
    {'name': '1 Month', 'duration': 30, 'price': 15000.0},
    {'name': '3 Months', 'duration': 90, 'price': 40000.0},
  ];

  @override
  void dispose() {
    _codeController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _generateCode() async {
    final code = _generateVoucherCode();
    setState(() {
      _codeController.text = code;
    });
  }

  String _generateVoucherCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    var code = '';
    for (var i = 0; i < 12; i++) {
      code += chars[(random + i) % chars.length];
    }
    return '${code.substring(0, 4)}-${code.substring(4, 8)}-${code.substring(8, 12)}';
  }

  Future<void> _saveVoucher() async {
    if (!_formKey.currentState!.validate()) return;

    final database = ref.read(databaseProvider);

    try {
      await database.into(database.vouchers).insert(
            VouchersCompanion.insert(
              code: _codeController.text.trim(),
              username: _usernameController.text.trim().isEmpty
                  ? const Value.absent()
                  : Value(_usernameController.text.trim()),
              password: _passwordController.text.trim().isEmpty
                  ? const Value.absent()
                  : Value(_passwordController.text.trim()),
              duration: _duration,
              price: double.parse(_priceController.text),
              status: 'UNUSED',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voucher created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateBulkVouchers() async {
    final count = await showDialog<int>(
      context: context,
      builder: (context) => _BulkGenerateDialog(),
    );

    if (count == null || count <= 0) return;

    final database = ref.read(databaseProvider);

    try {
      for (var i = 0; i < count; i++) {
        await database.into(database.vouchers).insert(
              VouchersCompanion.insert(
                code: _generateVoucherCode(),
                duration: _duration,
                price: double.parse(_priceController.text),
                status: 'UNUSED',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count vouchers generated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Voucher'),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_copy),
            onPressed: _generateBulkVouchers,
            tooltip: 'Generate Bulk',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'Voucher Code',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.qr_code),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter voucher code';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _generateCode,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Generate'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedPackage,
              decoration: const InputDecoration(
                labelText: 'Package',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.card_giftcard),
              ),
              items: _packages.map((pkg) {
                return DropdownMenuItem<String>(
                  value: pkg['name'] as String,
                  child: Text('${pkg['name']} - TSh ${pkg['price']}'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPackage = value!;
                  final pkg = _packages.firstWhere((p) => p['name'] == value);
                  _duration = pkg['duration'];
                  _priceController.text = pkg['price'].toString();
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _duration.toString(),
              decoration: const InputDecoration(
                labelText: 'Duration (Days)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.timer),
              ),
              keyboardType: TextInputType.number,
              readOnly: true,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Price',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
                suffix: Text('TSh'),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter price';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Optional Credentials',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveVoucher,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: const Text('Create Voucher'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulkGenerateDialog extends StatefulWidget {
  @override
  State<_BulkGenerateDialog> createState() => _BulkGenerateDialogState();
}

class _BulkGenerateDialogState extends State<_BulkGenerateDialog> {
  final _controller = TextEditingController(text: '10');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generate Bulk Vouchers'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Number of vouchers',
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final count = int.tryParse(_controller.text);
            Navigator.pop(context, count);
          },
          child: const Text('Generate'),
        ),
      ],
    );
  }
}

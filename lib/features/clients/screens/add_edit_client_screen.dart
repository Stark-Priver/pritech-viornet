import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_models.dart';
import '../../../core/providers/providers.dart';

class AddEditClientScreen extends ConsumerStatefulWidget {
  final Client? client;

  const AddEditClientScreen({super.key, this.client});

  @override
  ConsumerState<AddEditClientScreen> createState() =>
      _AddEditClientScreenState();
}

class _AddEditClientScreenState extends ConsumerState<AddEditClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedPackage = '1 Week';
  bool _smsReminder = true;
  bool _isLoading = false;

  final List<String> _packages = [
    '1 Day',
    '1 Week',
    '2 Weeks',
    '1 Month',
    '3 Months',
    '6 Months',
    '1 Year',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.client != null) {
      _nameController.text = widget.client!.name;
      _phoneController.text = widget.client!.phone;
      _emailController.text = widget.client!.email ?? '';
      _locationController.text = widget.client!.address ?? '';
      _notesController.text = widget.client!.notes ?? '';
      _selectedPackage = '1 Week';
      _smsReminder = widget.client!.smsReminder;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(clientRepositoryProvider);

      final expiryDate = _calculateExpiryDate();

      if (widget.client == null) {
        // Create new client
        await repository.createClient({
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          if (_emailController.text.trim().isNotEmpty)
            'email': _emailController.text.trim(),
          'address': _locationController.text.trim(),
          'registration_date': DateTime.now().toIso8601String(),
          'expiry_date': expiryDate.toIso8601String(),
          'sms_reminder': _smsReminder,
          if (_notesController.text.trim().isNotEmpty)
            'notes': _notesController.text.trim(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Client added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Update existing client
        await repository.updateClient(widget.client!.id, {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          'address': _locationController.text.trim(),
          'expiry_date': expiryDate.toIso8601String(),
          'sms_reminder': _smsReminder,
          'notes': _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Client updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  DateTime _calculateExpiryDate() {
    final now = DateTime.now();
    switch (_selectedPackage) {
      case '1 Day':
        return now.add(const Duration(days: 1));
      case '1 Week':
        return now.add(const Duration(days: 7));
      case '2 Weeks':
        return now.add(const Duration(days: 14));
      case '1 Month':
        return DateTime(now.year, now.month + 1, now.day);
      case '3 Months':
        return DateTime(now.year, now.month + 3, now.day);
      case '6 Months':
        return DateTime(now.year, now.month + 6, now.day);
      case '1 Year':
        return DateTime(now.year + 1, now.month, now.day);
      default:
        return now.add(const Duration(days: 7));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.client == null ? 'Add Client' : 'Edit Client'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter client name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number *',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email (Optional)',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location *',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter location';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedPackage,
              decoration: const InputDecoration(
                labelText: 'Package *',
                prefixIcon: Icon(Icons.wifi),
                border: OutlineInputBorder(),
              ),
              items: _packages.map((package) {
                return DropdownMenuItem(
                  value: package,
                  child: Text(package),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPackage = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Subscription Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Starts: ${_formatDate(DateTime.now())}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    Text(
                      'Expires: ${_formatDate(_calculateExpiryDate())}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable SMS Reminders'),
              subtitle: const Text('Send reminder before expiry'),
              value: _smsReminder,
              onChanged: (value) {
                setState(() {
                  _smsReminder = value;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                prefixIcon: Icon(Icons.note),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveClient,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        widget.client == null ? 'Add Client' : 'Update Client'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

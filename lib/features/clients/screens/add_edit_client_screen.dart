import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_models.dart';
import '../../../core/providers/providers.dart';
import '../../auth/providers/auth_provider.dart';

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
  final _macController = TextEditingController();
  final _notesController = TextEditingController();

  bool _smsReminder = true;
  bool _isLoading = false;

  // Site & assignment
  int? _selectedSiteId;
  int? _assignedToId;
  List<Site> _sites = [];
  List<AppUser> _users = [];
  bool _formDataLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.client != null) {
      final c = widget.client!;
      _nameController.text = c.name;
      _phoneController.text = c.phone;
      _emailController.text = c.email ?? '';
      _locationController.text = c.address ?? '';
      _macController.text = c.macAddress ?? '';
      _notesController.text = c.notes ?? '';
      _smsReminder = c.smsReminder;
      _selectedSiteId = c.siteId;
      _assignedToId = c.assignedTo;
    }
    _loadFormData();
  }

  Future<void> _loadFormData() async {
    final db = ref.read(databaseProvider);
    final authNotifier = ref.read(authProvider.notifier);
    final canAccessAll = authNotifier.canAccessAllSites;
    final userSites = authNotifier.currentUserSites;

    final allSites = await db.getAllSites();
    final allUsers = canAccessAll ? await db.getAllUsers() : <AppUser>[];

    if (!mounted) return;
    setState(() {
      _sites = canAccessAll
          ? allSites
          : allSites.where((s) => userSites.contains(s.id)).toList();

      // Auto-select site when user has only one
      if (_selectedSiteId == null && _sites.length == 1) {
        _selectedSiteId = _sites.first.id;
      }

      _users = allUsers;
      _formDataLoading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    _macController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSiteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a site for this client'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(clientRepositoryProvider);
      final currentUser = ref.read(authProvider).user;

      if (widget.client == null) {
        // ── Create new client ──────────────────────────────────────────
        await repository.createClient({
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          if (_emailController.text.trim().isNotEmpty)
            'email': _emailController.text.trim(),
          if (_locationController.text.trim().isNotEmpty)
            'address': _locationController.text.trim(),
          if (_macController.text.trim().isNotEmpty)
            'mac_address': _macController.text.trim(),
          'site_id': _selectedSiteId,
          if (currentUser != null) 'registered_by': currentUser.id,
          if (_assignedToId != null) 'assigned_to': _assignedToId,
          'registration_date': DateTime.now().toIso8601String(),
          'is_active': true,
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
        // ── Update existing client ─────────────────────────────────────
        await repository.updateClient(widget.client!.id, {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          'address': _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
          'mac_address': _macController.text.trim().isEmpty
              ? null
              : _macController.text.trim(),
          'site_id': _selectedSiteId,
          'assigned_to': _assignedToId,
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

      if (mounted) Navigator.pop(context, true);
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAssign = ref.read(authProvider.notifier).canAccessAllSites;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.client == null ? 'Add Client' : 'Edit Client'),
      ),
      body: _formDataLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Personal details ─────────────────────────────────
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email (optional)',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Address / Location',
                      prefixIcon: Icon(Icons.location_on),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _macController,
                    decoration: const InputDecoration(
                      labelText: 'MAC Address (optional)',
                      prefixIcon: Icon(Icons.router),
                      border: OutlineInputBorder(),
                      hintText: 'e.g. AA:BB:CC:DD:EE:FF',
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Site & assignment ─────────────────────────────────
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'SITE & ASSIGNMENT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedSiteId,
                    decoration: const InputDecoration(
                      labelText: 'Site *',
                      prefixIcon: Icon(Icons.cell_tower),
                      border: OutlineInputBorder(),
                    ),
                    items: _sites
                        .map((s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.name),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedSiteId = v),
                    validator: (v) => v == null ? 'Please select a site' : null,
                  ),
                  if (canAssign && _users.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int?>(
                      initialValue: _assignedToId,
                      decoration: const InputDecoration(
                        labelText: 'Assign to User (optional)',
                        prefixIcon: Icon(Icons.person_pin),
                        border: OutlineInputBorder(),
                        helperText:
                            'Transfer this client to an agent or staff member',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('— Unassigned —'),
                        ),
                        ..._users.map((u) => DropdownMenuItem(
                              value: u.id,
                              child: Text('${u.name} (${u.role})'),
                            )),
                      ],
                      onChanged: (v) => setState(() => _assignedToId = v),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ── Preferences ──────────────────────────────────────
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'PREFERENCES',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Enable SMS Reminders'),
                    subtitle: const Text('Send a reminder before expiry'),
                    value: _smsReminder,
                    onChanged: (v) => setState(() => _smsReminder = v),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      prefixIcon: Icon(Icons.note),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 28),

                  // ── Save button ──────────────────────────────────────
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveClient,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        widget.client == null ? 'Add Client' : 'Save Changes',
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

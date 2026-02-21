import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_models.dart';
import '../../../core/providers/providers.dart';

class AddEditSiteScreen extends ConsumerStatefulWidget {
  final Site? site;

  const AddEditSiteScreen({super.key, this.site});

  @override
  ConsumerState<AddEditSiteScreen> createState() => _AddEditSiteScreenState();
}

class _AddEditSiteScreenState extends ConsumerState<AddEditSiteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactEmailController = TextEditingController();
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    if (widget.site != null) {
      _nameController.text = widget.site!.name;
      _locationController.text = widget.site!.location ?? '';
      _contactPersonController.text = widget.site!.contactPerson ?? '';
      _contactPhoneController.text = widget.site!.contactPhone ?? '';
      _isActive = widget.site!.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _contactPersonController.dispose();
    _contactPhoneController.dispose();
    _contactEmailController.dispose();
    super.dispose();
  }

  Future<void> _saveSite() async {
    if (!_formKey.currentState!.validate()) return;

    final database = ref.read(databaseProvider);

    try {
      if (widget.site == null) {
        // Create new site
        await database.createSite({
          'name': _nameController.text.trim(),
          'location': _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
          'contact_person': _contactPersonController.text.trim().isEmpty
              ? null
              : _contactPersonController.text.trim(),
          'contact_phone': _contactPhoneController.text.trim().isEmpty
              ? null
              : _contactPhoneController.text.trim(),
          'is_active': _isActive,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Site added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Update existing site
        await database.updateSite(widget.site!.id, {
          'name': _nameController.text.trim(),
          'location': _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
          'contact_person': _contactPersonController.text.trim().isEmpty
              ? null
              : _contactPersonController.text.trim(),
          'contact_phone': _contactPhoneController.text.trim().isEmpty
              ? null
              : _contactPhoneController.text.trim(),
          'is_active': _isActive,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Site updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      if (mounted) {
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
        title: Text(widget.site == null ? 'Add Site' : 'Edit Site'),
        actions: [
          if (widget.site != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Site Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter site name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Contact Information',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactPersonController,
              decoration: const InputDecoration(
                labelText: 'Contact Person',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactPhoneController,
              decoration: const InputDecoration(
                labelText: 'Contact Phone',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactEmailController,
              decoration: const InputDecoration(
                labelText: 'Contact Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Active'),
              subtitle: const Text('Site is currently operational'),
              value: _isActive,
              onChanged: (value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveSite,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: Text(widget.site == null ? 'Add Site' : 'Update Site'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Site'),
        content: const Text('Are you sure you want to delete this site?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final database = ref.read(databaseProvider);
      await database.deleteSite(widget.site!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Site deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    }
  }
}

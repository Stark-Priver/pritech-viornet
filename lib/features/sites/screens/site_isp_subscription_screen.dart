import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/services/isp_subscription_service.dart';
import '../../../core/providers/providers.dart';

class SiteIspSubscriptionScreen extends ConsumerStatefulWidget {
  final Site site;
  const SiteIspSubscriptionScreen({super.key, required this.site});

  @override
  ConsumerState<SiteIspSubscriptionScreen> createState() =>
      _SiteIspSubscriptionScreenState();
}

class _SiteIspSubscriptionScreenState
    extends ConsumerState<SiteIspSubscriptionScreen> {
  late final IspSubscriptionService _service;
  late final AppDatabase _db;

  @override
  void initState() {
    super.initState();
    _db = ref.read(databaseProvider);
    _service = IspSubscriptionService(_db);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ISP Subscription for ${widget.site.name}')),
      body: FutureBuilder<List<IspSubscription>>(
        future: _service.getIspSubscriptionsForSite(widget.site.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: \\${snapshot.error}'));
          }
          final subs = snapshot.data ?? [];

          // Sort by paidAt descending (most recent first)
          subs.sort((a, b) => b.paidAt.compareTo(a.paidAt));
          // Find next due (the soonest endsAt in the future)
          final now = DateTime.now();
          final nextDue = subs
              .where((s) => s.endsAt.isAfter(now))
              .fold<IspSubscription?>(null, (prev, s) {
            if (prev == null || s.endsAt.isBefore(prev.endsAt)) return s;
            return prev;
          });
          final totalPaid =
              subs.fold<double>(0, (sum, s) => sum + (s.amount ?? 0));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary Section
              if (subs.isNotEmpty) ...[
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Payments: \\${subs.length}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                            'Total Amount Paid: \\${totalPaid.toStringAsFixed(2)}'),
                        if (nextDue != null) ...[
                          const SizedBox(height: 8),
                          Text(
                              'Next Due: \\${nextDue.endsAt.toLocal().toString().split(' ')[0]}',
                              style: const TextStyle(color: Colors.red)),
                          Text('Provider: \\${nextDue.providerName}'),
                        ] else ...[
                          const SizedBox(height: 8),
                          const Text('No upcoming due payments.',
                              style: TextStyle(color: Colors.green)),
                        ]
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add ISP Subscription'),
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (ctx) => _IspSubscriptionDialog(
                        siteId: widget.site.id, service: _service),
                  );
                  setState(() {});
                },
              ),
              const SizedBox(height: 16),
              ...subs.map((sub) => Card(
                    child: ListTile(
                      title: Text(sub.providerName),
                      subtitle: Text(
                          'Paid: \\${sub.paidAt.toLocal()} | Ends: \\${sub.endsAt.toLocal()}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await _service.deleteIspSubscription(sub.id);
                          setState(() {});
                        },
                      ),
                      onTap: () => showDialog(
                        context: context,
                        builder: (ctx) => _IspSubscriptionDialog(
                          siteId: widget.site.id,
                          service: _service,
                          existing: sub,
                        ),
                      ).then((_) => setState(() {})),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _IspSubscriptionDialog extends StatefulWidget {
  final int siteId;
  final IspSubscriptionService service;
  final IspSubscription? existing;
  const _IspSubscriptionDialog(
      {required this.siteId, required this.service, this.existing});

  @override
  State<_IspSubscriptionDialog> createState() => _IspSubscriptionDialogState();
}

class _IspSubscriptionDialogState extends State<_IspSubscriptionDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _providerController;
  late TextEditingController _controlNumberController;
  late TextEditingController _registeredNameController;
  late TextEditingController _serviceNumberController;
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  DateTime? _paidAt;
  DateTime? _endsAt;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _providerController = TextEditingController(text: e?.providerName ?? '');
    _controlNumberController =
        TextEditingController(text: e?.paymentControlNumber ?? '');
    _registeredNameController =
        TextEditingController(text: e?.registeredName ?? '');
    _serviceNumberController =
        TextEditingController(text: e?.serviceNumber ?? '');
    _amountController =
        TextEditingController(text: e?.amount?.toString() ?? '');
    _notesController = TextEditingController(text: e?.notes ?? '');
    _paidAt = e?.paidAt;
    _endsAt = e?.endsAt;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null
          ? 'Add ISP Subscription'
          : 'Edit ISP Subscription'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _providerController,
                decoration: const InputDecoration(labelText: 'Provider Name'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _controlNumberController,
                decoration:
                    const InputDecoration(labelText: 'Payment Control Number'),
              ),
              TextFormField(
                controller: _registeredNameController,
                decoration: const InputDecoration(labelText: 'Registered Name'),
              ),
              TextFormField(
                controller: _serviceNumberController,
                decoration: const InputDecoration(labelText: 'Service Number'),
              ),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: Text(_paidAt == null
                          ? 'Paid At'
                          : _paidAt!.toLocal().toString().split(' ')[0]),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _paidAt ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => _paidAt = picked);
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: Text(_endsAt == null
                          ? 'Ends At'
                          : _endsAt!.toLocal().toString().split(' ')[0]),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _endsAt ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => _endsAt = picked);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate() ||
                _paidAt == null ||
                _endsAt == null) {
              return;
            }
            if (widget.existing == null) {
              await widget.service.addIspSubscription(
                siteId: widget.siteId,
                providerName: _providerController.text,
                paidAt: _paidAt!,
                endsAt: _endsAt!,
                paymentControlNumber: _controlNumberController.text.isNotEmpty
                    ? _controlNumberController.text
                    : null,
                registeredName: _registeredNameController.text.isNotEmpty
                    ? _registeredNameController.text
                    : null,
                serviceNumber: _serviceNumberController.text.isNotEmpty
                    ? _serviceNumberController.text
                    : null,
                amount: double.tryParse(_amountController.text),
                notes: _notesController.text.isNotEmpty
                    ? _notesController.text
                    : null,
              );
            } else {
              await widget.service.updateIspSubscription(
                id: widget.existing!.id,
                siteId: widget.siteId,
                providerName: _providerController.text,
                paidAt: _paidAt!,
                endsAt: _endsAt!,
                paymentControlNumber: _controlNumberController.text.isNotEmpty
                    ? _controlNumberController.text
                    : null,
                registeredName: _registeredNameController.text.isNotEmpty
                    ? _registeredNameController.text
                    : null,
                serviceNumber: _serviceNumberController.text.isNotEmpty
                    ? _serviceNumberController.text
                    : null,
                amount: double.tryParse(_amountController.text),
                notes: _notesController.text.isNotEmpty
                    ? _notesController.text
                    : null,
              );
            }
            if (!mounted) return;
            // ignore: use_build_context_synchronously
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

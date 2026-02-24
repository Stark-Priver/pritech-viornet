import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/supabase_data_service.dart';
import '../../../core/services/isp_subscription_service.dart';
import '../../auth/providers/auth_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _service = IspSubscriptionService(SupabaseDataService());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ISP Subscriptions - ${widget.site.name}'),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.site.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: widget.site.isActive ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<IspSubscription>>(
        future: _service.getIspSubscriptionsForSite(widget.site.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
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
              // Summary Cards Section
              if (subs.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        icon: Icons.payment,
                        title: 'Total Payments',
                        value: subs.length.toString(),
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        icon: Icons.attach_money,
                        title: 'Total Paid',
                        value: totalPaid.toStringAsFixed(2),
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (nextDue != null)
                  _buildNextDueCard(nextDue)
                else
                  _buildNoUpcomingCard(),
                const SizedBox(height: 24),
              ] else
                _buildEmptyStateCard(),

              // Add Button
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddEditIspSubscriptionScreen(
                            siteId: widget.site.id,
                            service: _service,
                            createdBy: ref.read(authProvider).user?.id ?? 1,
                          ),
                        ),
                      ).then((_) => setState(() {}));
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_circle_outline,
                              color: Colors.white, size: 24),
                          const SizedBox(width: 12),
                          const Text(
                            'Add ISP Subscription',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Subscriptions List
              if (subs.isNotEmpty) ...[
                Text(
                  'Payment History',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                ...subs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final sub = entry.value;
                  return _buildSubscriptionCard(sub, index, subs.length);
                }),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextDueCard(IspSubscription nextDue) {
    final daysUntilDue = nextDue.endsAt.difference(DateTime.now()).inDays;
    final isUrgent = daysUntilDue <= 7;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUrgent
              ? [Colors.orange.shade300, Colors.red.shade400]
              : [Colors.green.shade300, Colors.teal.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color:
                (isUrgent ? Colors.red : Colors.green).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isUrgent ? Icons.warning_amber : Icons.check_circle,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isUrgent ? 'Renewal Urgent' : 'Next Renewal',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nextDue.providerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Due: ${nextDue.endsAt.toLocal().toString().split(' ')[0]} ($daysUntilDue days)',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoUpcomingCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade300, Colors.teal.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All Paid',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'No upcoming ISP subscription renewals',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant, width: 1),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.router, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No ISP Subscriptions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first ISP subscription to track payments',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(IspSubscription sub, int index, int total) {
    final isExpired = sub.endsAt.isBefore(DateTime.now());
    final daysRemaining = sub.endsAt.difference(DateTime.now()).inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpired
              ? Colors.red[200]!
              : Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddEditIspSubscriptionScreen(
                  siteId: widget.site.id,
                  service: _service,
                  existing: sub,
                  createdBy: ref.read(authProvider).user?.id ?? 1,
                ),
              ),
            ).then((_) => setState(() {}));
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isExpired
                            ? Colors.red.withValues(alpha: 0.1)
                            : Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.router,
                        color: isExpired ? Colors.red : Colors.blue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sub.providerName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (sub.registeredName != null)
                            Text(
                              sub.registeredName!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isExpired
                            ? Colors.red.withValues(alpha: 0.1)
                            : daysRemaining <= 7
                                ? Colors.orange.withValues(alpha: 0.1)
                                : Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isExpired
                            ? 'Expired'
                            : daysRemaining <= 7
                                ? '$daysRemaining days'
                                : 'Active',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isExpired
                              ? Colors.red
                              : daysRemaining <= 7
                                  ? Colors.orange
                                  : Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoRow(
                        icon: Icons.calendar_today,
                        label: 'Paid',
                        value: sub.paidAt.toLocal().toString().split(' ')[0],
                      ),
                    ),
                    Expanded(
                      child: _buildInfoRow(
                        icon: Icons.event_available,
                        label: 'Expires',
                        value: sub.endsAt.toLocal().toString().split(' ')[0],
                      ),
                    ),
                  ],
                ),
                if (sub.amount != null) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    icon: Icons.attach_money,
                    label: 'Amount',
                    value: sub.amount!.toStringAsFixed(2),
                  ),
                ],
                if (sub.serviceNumber != null) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    icon: Icons.confirmation_number,
                    label: 'Service Number',
                    value: sub.serviceNumber!,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddEditIspSubscriptionScreen(
                              siteId: widget.site.id,
                              service: _service,
                              existing: sub,
                              createdBy: ref.read(authProvider).user?.id ?? 1,
                            ),
                          ),
                        ).then((_) => setState(() {}));
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _confirmDelete(sub),
                      icon:
                          const Icon(Icons.delete, size: 18, color: Colors.red),
                      label: const Text('Delete',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(IspSubscription sub) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subscription'),
        content: Text(
            'Are you sure you want to delete the subscription for ${sub.providerName}?'),
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
      await _service.deleteIspSubscription(sub.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
      }
    }
  }
}

class AddEditIspSubscriptionScreen extends StatefulWidget {
  final int siteId;
  final IspSubscriptionService service;
  final IspSubscription? existing;
  final int createdBy;

  const AddEditIspSubscriptionScreen({
    super.key,
    required this.siteId,
    required this.service,
    this.existing,
    required this.createdBy,
  });

  @override
  State<AddEditIspSubscriptionScreen> createState() =>
      _AddEditIspSubscriptionScreenState();
}

class _AddEditIspSubscriptionScreenState
    extends State<AddEditIspSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _providerController;
  late TextEditingController _controlNumberController;
  late TextEditingController _registeredNameController;
  late TextEditingController _serviceNumberController;
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  DateTime? _paidAt;
  DateTime? _endsAt;
  bool _isLoading = false;

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
  void dispose() {
    _providerController.dispose();
    _controlNumberController.dispose();
    _registeredNameController.dispose();
    _serviceNumberController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() ||
        _paidAt == null ||
        _endsAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.existing == null) {
        await widget.service.addIspSubscription(
          siteId: widget.siteId,
          providerName: _providerController.text.trim(),
          paidAt: _paidAt!,
          endsAt: _endsAt!,
          paymentControlNumber: _controlNumberController.text.trim().isEmpty
              ? null
              : _controlNumberController.text.trim(),
          registeredName: _registeredNameController.text.trim().isEmpty
              ? null
              : _registeredNameController.text.trim(),
          serviceNumber: _serviceNumberController.text.trim().isEmpty
              ? null
              : _serviceNumberController.text.trim(),
          amount: double.tryParse(_amountController.text),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

        // Auto-record ISP subscription as an INTERNET expense
        final subscriptionAmount =
            double.tryParse(_amountController.text) ?? 0.0;
        if (subscriptionAmount > 0) {
          try {
            final expenseFields = <String, dynamic>{
              'category': 'INTERNET',
              'description': 'ISP - ${_providerController.text.trim()}',
              'amount': subscriptionAmount,
              'site_id': widget.siteId,
              'expense_date': _paidAt!.toIso8601String(),
            };
            final notesVal = _notesController.text.trim();
            if (notesVal.isNotEmpty) {
              expenseFields['notes'] =
                  'Auto-recorded from ISP subscription. $notesVal';
            }
            expenseFields['created_by'] = widget.createdBy;
            await SupabaseDataService().createExpense(expenseFields);
          } catch (e) {
            // Never block ISP save on expense side-effect failure,
            // but log so we can diagnose issues.
            debugPrint('[ISP→Expense] Failed to auto-record expense: $e');
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'ISP subscription added and expense recorded automatically'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await widget.service.updateIspSubscription(
          id: widget.existing!.id,
          siteId: widget.siteId,
          providerName: _providerController.text.trim(),
          paidAt: _paidAt!,
          endsAt: _endsAt!,
          paymentControlNumber: _controlNumberController.text.trim().isEmpty
              ? null
              : _controlNumberController.text.trim(),
          registeredName: _registeredNameController.text.trim().isEmpty
              ? null
              : _registeredNameController.text.trim(),
          serviceNumber: _serviceNumberController.text.trim().isEmpty
              ? null
              : _serviceNumberController.text.trim(),
          amount: double.tryParse(_amountController.text),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ISP subscription updated successfully'),
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null
            ? 'Add ISP Subscription'
            : 'Edit ISP Subscription'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Provider Section
            _buildSectionHeader('Provider Information', Icons.router),
            const SizedBox(height: 16),
            TextFormField(
              controller: _providerController,
              decoration: InputDecoration(
                labelText: 'Provider Name *',
                hintText: 'e.g., Tanzaniacom, Vodacom',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.business),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Provider name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _registeredNameController,
              decoration: InputDecoration(
                labelText: 'Registered Name',
                hintText: 'Name registered with provider',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _serviceNumberController,
              decoration: InputDecoration(
                labelText: 'Service Number',
                hintText: 'Account or service number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.confirmation_number),
              ),
            ),
            const SizedBox(height: 24),

            // Payment Section
            _buildSectionHeader('Payment Details', Icons.payment),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount',
                hintText: '0.00',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controlNumberController,
              decoration: InputDecoration(
                labelText: 'Payment Control Number',
                hintText: 'Receipt or reference number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.receipt),
              ),
            ),
            const SizedBox(height: 24),

            // Dates Section
            _buildSectionHeader('Subscription Period', Icons.calendar_today),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _paidAt ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _paidAt = picked);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  color: Colors.blue, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Paid At *',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _paidAt == null
                                ? 'Select date'
                                : _paidAt!.toLocal().toString().split(' ')[0],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _paidAt == null
                                  ? Colors.grey[400]
                                  : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endsAt ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _endsAt = picked);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.event_available,
                                  color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Expires At *',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _endsAt == null
                                ? 'Select date'
                                : _endsAt!.toLocal().toString().split(' ')[0],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _endsAt == null
                                  ? Colors.grey[400]
                                  : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Notes Section
            _buildSectionHeader('Additional Notes', Icons.note),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes',
                hintText: 'Any additional information',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.note),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),

            // Save Button
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isLoading ? null : _save,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                widget.existing == null
                                    ? Icons.add_circle_outline
                                    : Icons.save,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                widget.existing == null
                                    ? 'Add Subscription'
                                    : 'Update Subscription',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Cancel Button
            OutlinedButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              child: const Text('Cancel'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

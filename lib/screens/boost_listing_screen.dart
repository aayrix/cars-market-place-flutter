import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/error_messages.dart';

class BoostListingScreen extends StatefulWidget {
  const BoostListingScreen({super.key, required this.listingId});
  final String listingId;
  @override
  State<BoostListingScreen> createState() => _BoostListingScreenState();
}

class _BoostListingScreenState extends State<BoostListingScreen> {
  int _days = 7;
  bool _busy = false;
  Future<void> _request() async {
    setState(() => _busy = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw StateError('Sign in to request a listing boost.');
      await Supabase.instance.client.from('boost_requests').insert({'user_id': userId, 'listing_id': widget.listingId, 'plan_days': _days});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Boost request sent. We will confirm payment manually.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorMessages.from(error))));
    } finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Boost your listing')), body: ListView(padding: const EdgeInsets.all(20), children: [
    const Text('Choose how long you would like your listing featured.'),
    Wrap(spacing: 8, children: [for (final days in [7, 15, 30]) ChoiceChip(label: Text('$days days'), selected: _days == days, onSelected: (_) => setState(() => _days = days))]),
    const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Manual payment: JazzCash / Easypaisa\nPayment number and amount will be provided when your request is reviewed. Do not send payment until our team confirms the details.'))),
    const SizedBox(height: 12), FilledButton(onPressed: _busy ? null : _request, child: Text(_busy ? 'Sending…' : 'Request boost')),
  ]));
}

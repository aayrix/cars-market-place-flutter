import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/location_service.dart';
import '../utils/error_messages.dart';

/// Lets the user pick (or confirm) a location to share in a chat.
///
/// Returns a map like:
///   {'latitude': double, 'longitude': double, 'title': String,
///    'isLive': bool, 'durationMinutes': int?}
/// or `null` if cancelled.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late final MapController _mapController;
  late final StreamSubscription<Position> _positionStream;
  late final TextEditingController _labelController;
  Position? _position;
  LatLng? _center;
  bool _live = false;
  int? _durationMinutes;
  bool _loading = true;
  bool _sending = false;

  static const _durations = <int?>[15, 30, 60, null];
  static const _durationLabels = <String?>['15 min', '30 min', '1 hour', 'Until stopped'];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _center = const LatLng(33.3106, 72.4165); // Mianwali fallback
    _labelController = TextEditingController(text: 'My location');
    _positionStream = LocationService.instance
        .positionStream(distanceFilterMeters: 5)
        .listen((position) {
      if (!mounted) return;
      setState(() {
        _position = position;
        if (_center == null || _center == const LatLng(33.3106, 72.4165)) {
          _center = LatLng(position.latitude, position.longitude);
        }
        _loading = false;
      });
    }, onError: (error) {
      if (!mounted) return;
      setState(() => _loading = false);
    });
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _positionStream.cancel();
    _mapController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final pos = await LocationService.instance.currentPosition();
      if (!mounted) return;
      setState(() {
        _position = pos;
        _center = LatLng(pos.latitude, pos.longitude);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ErrorMessages.from(
          error,
          fallback: 'Could not get your current location.',
        )),
      ));
    }
  }

  void _goToMyLocation() {
    if (_position == null) return;
    _mapController.move(
      LatLng(_position!.latitude, _position!.longitude),
      15,
    );
    setState(() => _center = LatLng(_position!.latitude, _position!.longitude));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share location'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center!,
                    initialZoom: 15,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                    onTap: (_, latLng) => setState(() => _center = latLng),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'Apni Gari',
                      maxZoom: 19,
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _center ??
                              const LatLng(33.3106, 72.4165),
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 36,
                          ),
                        ),
                        if (_position != null)
                          Marker(
                            point: LatLng(
                              _position!.latitude,
                              _position!.longitude,
                            ),
                            width: 24,
                            height: 24,
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.blue,
                              size: 22,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (_loading)
                  Container(
                    color: cs.surface.withValues(alpha: 0.85),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: _MapHint(
                    hint: _position == null
                        ? 'Finding your location…'
                        : 'Move the pin, then tap Share location.',
                  ),
                ),
              ],
            ),
          ),
          _LocationPanel(
            controller: _labelController,
            live: _live,
            durationMinutes: _durationMinutes,
            durations: _durations,
            durationLabels: _durationLabels,
            onLiveChanged: (v) => setState(() => _live = v ?? false),
            onDurationChanged: (v) =>
                setState(() => _durationMinutes = v),
            onMyLocation: _goToMyLocation,
            onShare: _sending ? null : _share,
            sharing: _sending,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: _goToMyLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  Future<void> _share() async {
    if (_center == null || _labelController.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      if (!mounted) return;
      Navigator.pop(context, <String, dynamic>{
        'latitude': _center!.latitude,
        'longitude': _center!.longitude,
        'title': _labelController.text.trim(),
        'isLive': _live,
        'durationMinutes':
            _live ? _durationMinutes : null,
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _MapHint extends StatelessWidget {
  const _MapHint({required this.hint});
  final String hint;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest
          .withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      hint,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 12,
      ),
    ),
  );
}

class _LocationPanel extends StatelessWidget {
  const _LocationPanel({
    required this.controller,
    required this.live,
    required this.durationMinutes,
    required this.durations,
    required this.durationLabels,
    required this.onLiveChanged,
    required this.onDurationChanged,
    required this.onMyLocation,
    required this.onShare,
    required this.sharing,
  });

  final TextEditingController controller;
  final bool live;
  final int? durationMinutes;
  final List<int?> durations;
  final List<String?> durationLabels;
  final ValueChanged<bool?> onLiveChanged;
  final ValueChanged<int?> onDurationChanged;
  final VoidCallback onMyLocation;
  final VoidCallback? onShare;
  final bool sharing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Location label',
                hintText: 'e.g. My workshop',
                prefixIcon: Icon(Icons.label_outline),
              ),
              maxLength: 60,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: live,
                  onChanged: onLiveChanged,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Share live location (keeps updating)',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            if (live) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: List.generate(durations.length, (i) {
                  final d = durations[i];
                  final selected = d == durationMinutes;
                  return ChoiceChip(
                    label: Text(durationLabels[i]!),
                    selected: selected,
                    onSelected: (_) =>
                        onDurationChanged(selected ? null : d),
                  );
                }),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Live updates stop after the chosen time, or when you close the chat.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: sharing ? null : onMyLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Use my location'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: sharing ? null : onShare,
                  icon: sharing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(sharing ? 'Sharing…' : 'Share location'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

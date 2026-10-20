import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/car_listing.dart';
import '../providers/listings_provider.dart';
import '../services/location_service.dart';
import '../widgets/listing_card.dart';

class NearbyCarsScreen extends StatefulWidget {
  const NearbyCarsScreen({super.key});

  @override
  State<NearbyCarsScreen> createState() => _NearbyCarsScreenState();
}

class _NearbyCarsScreenState extends State<NearbyCarsScreen> {
  static const _mianwali = LatLng(32.5839, 71.5370);
  static const _radiusMeters = 50000.0;
  final _mapController = MapController();
  Position? _position;
  bool _loading = true;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    setState(() {
      _loading = true;
      _locationError = null;
    });
    try {
      final position = await LocationService.instance.currentPosition();
      if (!mounted) {
        return;
      }
      setState(() {
        _position = position;
        _loading = false;
      });
      _mapController.move(LatLng(position.latitude, position.longitude), 12);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _locationError = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final listings = context.watch<ListingsProvider>().listings.toList();
    final origin = _position == null
        ? null
        : LatLng(_position!.latitude, _position!.longitude);
    final distance = const Distance();
    final nearby =
        origin == null
              ? <CarListing>[]
              : listings.where((car) {
                  if (car.latitude == null || car.longitude == null) {
                    return false;
                  }
                  return distance.as(
                        LengthUnit.Meter,
                        origin,
                        LatLng(car.latitude!, car.longitude!),
                      ) <=
                      _radiusMeters;
                }).toList()
          ..sort((a, b) {
            return distance
                .as(
                  LengthUnit.Meter,
                  origin!,
                  LatLng(a.latitude!, a.longitude!),
                )
                .compareTo(
                  distance.as(
                    LengthUnit.Meter,
                    origin,
                    LatLng(b.latitude!, b.longitude!),
                  ),
                );
          });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cars near you'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _locate,
            tooltip: 'Update location',
            icon: const Icon(Icons.my_location),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 310,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: origin ?? _mianwali,
                  initialZoom: origin == null ? 10 : 12,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.apnigari.app',
                  ),
                  if (origin != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: origin,
                          width: 42,
                          height: 42,
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.blue,
                            size: 30,
                          ),
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      for (final car in nearby)
                        Marker(
                          point: LatLng(car.latitude!, car.longitude!),
                          width: 46,
                          height: 46,
                          child: Tooltip(
                            message: car.title,
                            child: const Icon(
                              Icons.location_on,
                              color: Color(0xFF087E8B),
                              size: 42,
                            ),
                          ),
                        ),
                    ],
                  ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('© OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverToBoxAdapter(child: LinearProgressIndicator()),
          if (_locationError != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.location_off_outlined),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Enable location to sort cars by distance. $_locationError',
                          ),
                        ),
                        TextButton(
                          onPressed: _locate,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Text(
                _position == null
                    ? 'NEARBY CARS'
                    : 'NEAREST CARS · WITHIN 50 KM',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          if (nearby.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Text(
                  _position == null
                      ? 'Turn on location to find cars nearby. Only cars with a shared map location within 50 km are shown.'
                      : 'No cars with a shared map location were found within 50 km. Sellers can add an approximate location while posting.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              sliver: SliverList.builder(
                itemCount: nearby.length,
                itemBuilder: (context, index) {
                  final car = nearby[index];
                  final meters = distance.as(
                    LengthUnit.Meter,
                    origin!,
                    LatLng(car.latitude!, car.longitude!),
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 2, bottom: 7),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.near_me,
                                  size: 18,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  _distanceLabel(meters),
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ListingCard(listing: car),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  String _distanceLabel(double meters) => meters < 1000
      ? '${meters.round()} m away'
      : '${(meters / 1000).toStringAsFixed(1)} km away';
}

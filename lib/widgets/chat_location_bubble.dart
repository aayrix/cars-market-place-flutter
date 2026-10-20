import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// Map preview for a shared location message. Tapping opens Google Maps.
class ChatLocationBubble extends StatefulWidget {
  const ChatLocationBubble({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.title,
    required this.mine,
    this.expiresAt,
    this.updatedAt,
    this.onTap,
  });

  final double latitude;
  final double longitude;
  final String title;
  final bool mine;
  final DateTime? expiresAt;
  final DateTime? updatedAt;
  final VoidCallback? onTap;

  bool get _isLive {
    final expires = expiresAt;
    return expires != null && expires.isAfter(DateTime.now().toUtc());
  }

  String _updatedText(BuildContext context) {
    final updated = updatedAt;
    if (updated == null) return '';
    final diff = DateTime.now().toUtc().difference(updated);
    final minutes = diff.inMinutes;
    if (minutes < 1) return 'Just now';
    if (minutes < 60) return 'Updated $minutes min ago';
    final hours = minutes ~/ 60;
    return 'Updated $hours ${hours == 1 ? 'hour' : 'hours'} ago';
  }

  @override
  State<ChatLocationBubble> createState() => _ChatLocationBubbleState();
}

class _ChatLocationBubbleState extends State<ChatLocationBubble> {
  late final MapController _mapController = MapController();

  Future<void> _openGoogleMaps(BuildContext context) async {
    final url =
        'https://www.google.com/maps/search/?api=1&query=${widget.latitude},${widget.longitude}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps app.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final live = widget._isLive;

    return GestureDetector(
      onTap: () => _openGoogleMaps(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.title.isEmpty ? 'Shared location' : widget.title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (live) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'LIVE',
                    style: TextStyle(
                      color: colors.onErrorContainer,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(widget.latitude, widget.longitude),
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
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
                        point: LatLng(widget.latitude, widget.longitude),
                        width: 36,
                        height: 36,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (widget.updatedAt != null || live) ...[
            const SizedBox(height: 4),
            Text(
              live
                  ? 'Live location • sharing until ${_expiresText()}'
                  : widget._updatedText(context),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _expiresText() {
    final expires = widget.expiresAt!;
    final now = DateTime.now().toUtc();
    final diff = expires.difference(now).inMinutes;
    if (diff < 60) return '$diff min';
    return '${diff ~/ 60}h ${diff % 60}min';
  }
}

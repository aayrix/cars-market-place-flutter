import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens Google Maps with directions to the shared location.
class LocationViewScreen extends StatelessWidget {
  const LocationViewScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.title,
    this.senderName,
  });

  final double latitude;
  final double longitude;
  final String title;
  final String? senderName;

  @override
  Widget build(BuildContext context) {
    // Open Google Maps directions immediately when this screen is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openGoogleMapsDirections(context);
    });

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(title.isEmpty ? 'Shared location' : title),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Opening directions in Google Maps...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openGoogleMapsDirections(BuildContext context) async {
    // Google Maps directions URL: from current location to shared location
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not open Google Maps.'),
        ));
        Navigator.of(context).pop();
      }
    }
  }
}

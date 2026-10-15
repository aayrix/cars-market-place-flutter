import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/mianwali_data.dart';
import '../providers/auth_provider.dart';
import '../providers/listings_provider.dart';
import '../providers/theme_settings.dart';
import '../services/social_service.dart';
import '../utils/pick_photo.dart';
import 'login_screen.dart';
import 'my_listings_screen.dart';

class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;
    final profile = auth.safeProfile;
    final activeListings = context.watch<ListingsProvider>().mineFor(
      auth.userId,
    );

    void openProfileEditor() {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const EditProfileScreen()),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        if (auth.authNotice != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.mark_email_read_outlined),
                const SizedBox(width: 10),
                Expanded(child: Text(auth.authNotice!)),
                IconButton(
                  tooltip: 'Dismiss',
                  onPressed: auth.clearAuthNotice,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                auth.isSignedIn ? profile.displayName : 'Your profile',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Settings',
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              ),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            InkWell(
              onTap: auth.isSignedIn ? openProfileEditor : null,
              customBorder: const CircleBorder(),
              child: CircleAvatar(
                radius: 42,
                backgroundImage: profile.avatarUrl.isEmpty
                    ? null
                    : NetworkImage(profile.avatarUrl),
                child: profile.avatarUrl.isEmpty
                    ? const Icon(Icons.person_outline, size: 38)
                    : null,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _AccountMetric(
                    value: '${activeListings.length}',
                    label: 'Ads',
                  ),
                  FutureBuilder<int>(
                    future: auth.userId == null
                        ? Future.value(0)
                        : SocialService().connectionCount(auth.userId!),
                    builder: (context, snapshot) => _AccountMetric(
                      value: '${snapshot.data ?? 0}',
                      label: 'Connections',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          auth.isSignedIn ? profile.displayName : 'Not signed in',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (profile.city.isNotEmpty)
          Text(profile.city, style: TextStyle(color: cs.onSurfaceVariant)),
        const SizedBox(height: 18),
        const SizedBox(height: 18),
        if (!auth.isSignedIn) ...[
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
              );
            },
            icon: const Icon(Icons.login),
            label: const Text('Sign in'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const LoginScreen(mode: LoginMode.signUp),
                ),
              );
            },
            icon: const Icon(Icons.person_add_alt_outlined),
            label: const Text('Create account'),
          ),
        ] else ...[
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const MyListingsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.list_alt_outlined),
            label: const Text('My listings'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const EditProfileScreen(),
                ),
              );
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit profile'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: auth.isLoading
                ? null
                : () async {
                    await context.read<AuthProvider>().signOut();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Signed out.')),
                    );
                  },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
        const SizedBox(height: 18),
        Text(
          'Cars are listed across $kCityName, $kCountryHint.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _AccountMetric extends StatelessWidget {
  const _AccountMetric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final appearance = context.watch<ThemeSettings>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'PREFERENCES',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              secondary: Icon(
                appearance.darkMode
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
              ),
              title: const Text('Dark mode'),
              subtitle: const Text('Use a darker appearance across the app'),
              value: appearance.darkMode,
              onChanged: appearance.setDarkMode,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'ACCOUNT',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Profile settings'),
                  subtitle: const Text('Name, photo, phone and city'),
                  enabled: auth.isSignedIn,
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Log out'),
                  enabled: auth.isSignedIn && !auth.isLoading,
                  onTap: () async {
                    await context.read<AuthProvider>().signOut();
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Signed out.')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Edits the signed-in user's `profiles` row.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _city;
  XFile? _avatarFile;
  Uint8List? _avatarPreview;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthProvider>().safeProfile;
    _name = TextEditingController(text: profile.fullName);
    _phone = TextEditingController(text: profile.phone);
    _city = TextEditingController(text: profile.city);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    String? error;
    if (_avatarFile != null) {
      error = await auth.updateAvatar(_avatarFile!);
    }
    error ??= await auth.updateProfile(
      fullName: _name.text,
      phone: _phone.text,
      city: _city.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    context.read<ListingsProvider>().updateSellerProfile(auth.safeProfile);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile saved.')));
  }

  Future<void> _pickAvatar() async {
    try {
      final image = await pickPhoto(context);
      if (image == null || !mounted) return;
      final imageBytes = await image.readAsBytes();
      if (!mounted) return;
      final croppedBytes = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute<Uint8List>(
          builder: (_) => _AvatarCropScreen(imageBytes: imageBytes),
        ),
      );
      if (croppedBytes == null || !mounted) return;
      setState(() {
        // The preview and uploaded file are exactly the crop the user chose.
        _avatarFile = XFile.fromData(
          croppedBytes,
          name: 'profile-avatar.png',
          mimeType: 'image/png',
        );
        _avatarPreview = croppedBytes;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the photo picker: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = context.watch<AuthProvider>().safeProfile.avatarUrl;
    final ImageProvider<Object>? avatarImage = _avatarPreview != null
        ? MemoryImage(_avatarPreview!)
        : (avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null);
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Center(
              child: Column(
                children: [
                  InkWell(
                    onTap: _saving ? null : _pickAvatar,
                    customBorder: const CircleBorder(),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundImage: avatarImage,
                          child: avatarImage == null
                              ? const Icon(Icons.person_outline, size: 44)
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: CircleAvatar(
                            radius: 17,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            child: const Icon(
                              Icons.camera_alt_outlined,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _saving ? null : _pickAvatar,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(
                      _avatarPreview == null
                          ? 'Add profile photo'
                          : 'Change photo',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                hintText: '03XX XXXXXXX',
              ),
              validator: (v) => (v == null || v.trim().length < 10)
                  ? 'Enter a valid number'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _city,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'City'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarCropScreen extends StatefulWidget {
  const _AvatarCropScreen({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<_AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<_AvatarCropScreen> {
  final _cropBoundaryKey = GlobalKey();
  late final Future<Size> _imageSize = _readImageSize();

  Future<Size> _readImageSize() async {
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    try {
      final frame = await codec.getNextFrame();
      try {
        return Size(
          frame.image.width.toDouble(),
          frame.image.height.toDouble(),
        );
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  Future<void> _useCrop() async {
    final renderObject = _cropBoundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return;

    try {
      final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
      final croppedImage = await renderObject.toImage(
        pixelRatio: math.min(3.0, math.max(2.0, devicePixelRatio)).toDouble(),
      );
      try {
        final data = await croppedImage.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (data == null) throw StateError('Could not crop the photo.');
        if (mounted) Navigator.of(context).pop(data.buffer.asUint8List());
      } finally {
        croppedImage.dispose();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not use this crop: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Size>(
    future: _imageSize,
    builder: (context, snapshot) {
      final ready = snapshot.hasData;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Adjust profile photo'),
          actions: [
            TextButton(
              onPressed: ready ? _useCrop : null,
              child: const Text('Use photo'),
            ),
          ],
        ),
        body: !ready
            ? Center(
                child: snapshot.hasError
                    ? const Text('Could not load this photo.')
                    : const CircularProgressIndicator(),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final cropSize = math
                      .min(
                        360.0,
                        math.min(
                          constraints.maxWidth - 32,
                          constraints.maxHeight - 150,
                        ),
                      )
                      .toDouble();
                  final size = snapshot.data!;
                  final baseScale =
                      cropSize / math.min(size.width, size.height);
                  final imageWidth = size.width * baseScale;
                  final imageHeight = size.height * baseScale;

                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRect(
                              child: RepaintBoundary(
                                key: _cropBoundaryKey,
                                child: SizedBox.square(
                                  dimension: cropSize,
                                  child: InteractiveViewer(
                                    constrained: false,
                                    alignment: Alignment.center,
                                    boundaryMargin: EdgeInsets.zero,
                                    minScale: 1,
                                    maxScale: 4,
                                    child: SizedBox(
                                      width: imageWidth,
                                      height: imageHeight,
                                      child: Image.memory(
                                        widget.imageBytes,
                                        fit: BoxFit.fill,
                                        filterQuality: FilterQuality.high,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            IgnorePointer(
                              child: SizedBox.square(
                                dimension: cropSize,
                                child: CustomPaint(
                                  painter: _AvatarCropGuidePainter(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'Drag to position your face. Pinch to zoom.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      );
    },
  );
}

class _AvatarCropGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final circle = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height / 2),
          radius: size.width / 2,
        ),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, full, circle),
      Paint()..color = Colors.black.withValues(alpha: 0.42),
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 1,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

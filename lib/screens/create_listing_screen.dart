import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/pakistani_vehicle_catalog.dart';
import '../models/car_category.dart';
import '../models/car_listing.dart';
import '../providers/auth_provider.dart';
import '../providers/listings_provider.dart';
import '../utils/ag_design.dart';
import '../utils/number_formatters.dart';
import '../utils/listing_image.dart';
import '../utils/local_file_image_io.dart'
    if (dart.library.html) '../utils/local_file_image_web.dart';
import '../services/location_service.dart';

class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({super.key, this.editing});

  final CarListing? editing;

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  static const List<String> _fuels = <String>[
    'Petrol',
    'Diesel',
    'CNG',
    'Hybrid',
    'Electric',
  ];
  static const List<String> _transmissions = <String>['Manual', 'Automatic'];
  static const List<String> _bikeTypes = [
    'Commuter',
    'Scooter',
    'Sport',
    'Cruiser',
    'Touring',
    'Dirt / Trail',
    'Electric',
  ];
  static const List<String> _bikeEngineOptions = [
    '50 cc',
    '70 cc',
    '100 cc',
    '125 cc',
    '150 cc',
    '200 cc',
    '250 cc',
    '300 cc',
    '400 cc',
    '600 cc',
    '1000 cc',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _variant;
  late final TextEditingController _mileage;
  late final TextEditingController _description;
  late final TextEditingController _city;

  late CarCategory _category;
  late String _fuel;
  late String _transmission;
  late String _bikeType;
  int? _engineCc;
  late double _year;
  late double _price;

  final List<String> _imagePaths = <String>[];
  final List<String> _retainedRemoteUrls = <String>[];

  bool _saving = false;
  double? _latitude;
  double? _longitude;
  bool _gettingLocation = false;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    final profile = context.read<AuthProvider>().safeProfile;

    _brand = TextEditingController(text: e?.brand ?? '');
    _model = TextEditingController(text: e?.model ?? '');
    _variant = TextEditingController(text: e?.variant ?? '');
    _mileage = TextEditingController(
      text: e?.mileage != null ? formatGroupedInt(e!.mileage) : '',
    );
    _description = TextEditingController(text: e?.description ?? '');
    _city = TextEditingController(
      text: e?.city.isNotEmpty == true
          ? e!.city
          : (profile.city.isNotEmpty ? profile.city : 'Mianwali'),
    );

    _category = e?.category ?? CarCategory.sedan;
    _latitude = e?.latitude;
    _longitude = e?.longitude;
    _fuel = e?.fuel ?? _fuels.first;
    _transmission = e?.transmission ?? _transmissions.first;
    _engineCc =
        e?.engineCc ?? (e?.category == CarCategory.motorcycle ? 125 : null);
    _bikeType = e?.bikeType ?? _bikeTypes.first;
    _year = (e?.year ?? DateTime.now().year - 3)
        .clamp(1990, DateTime.now().year)
        .toDouble();
    _price =
        ((e?.price ?? (_category == CarCategory.motorcycle ? 250000 : 3000000))
                .clamp(
                  _category == CarCategory.motorcycle ? 10000 : 100000,
                  _category == CarCategory.motorcycle ? 5000000 : 50000000,
                ))
            .toDouble();

    if (e != null) {
      for (final path in e.imagePaths) {
        final value = path.trim();
        final isRemote =
            value.startsWith('http://') || value.startsWith('https://');
        if (isRemote) {
          _retainedRemoteUrls.add(value);
        } else if (!kIsWeb && _localFileExists(value)) {
          _imagePaths.add(value);
        }
      }
    }
  }

  bool _localFileExists(String path) {
    try {
      return localFileExists(path);
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _brand.dispose();
    _model.dispose();
    _variant.dispose();
    _mileage.dispose();
    _description.dispose();
    _city.dispose();
    super.dispose();
  }

  int get _photoCount => _imagePaths.length + _retainedRemoteUrls.length;

  Future<void> _useCurrentLocation() async {
    setState(() => _gettingLocation = true);
    try {
      final position = await LocationService.instance.currentPosition();
      if (!mounted) return;
      setState(() {
        // Store a neighborhood-level pin rather than exposing a seller's
        // precise GPS location to every marketplace visitor.
        _latitude = double.parse(position.latitude.toStringAsFixed(3));
        _longitude = double.parse(position.longitude.toStringAsFixed(3));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location saved for nearby search.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get your location: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _pickGalleryImages() async {
    final slots = 4 - _photoCount;
    if (slots <= 0) {
      _showPhotoLimitMessage();
      return;
    }
    final files = await ImagePicker().pickMultiImage(imageQuality: 82);
    if (!mounted || files.isEmpty) return;
    final selected = files.take(slots).map((file) => file.path).toList();
    setState(() => _imagePaths.addAll(selected));
    if (files.length > slots) _showPhotoLimitMessage();
  }

  Future<void> _pickCameraImage() async {
    if (_photoCount >= 4) {
      _showPhotoLimitMessage();
      return;
    }
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
    );
    if (file != null && mounted) setState(() => _imagePaths.add(file.path));
  }

  void _showPhotoLimitMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('A car listing can have up to 4 pictures.')),
    );
  }

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickGalleryImages();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickCameraImage();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_isEdit && _photoCount < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least 3 photos to publish this listing.'),
        ),
      );
      return;
    }
    final enteredMileage = parseGroupedInt(_mileage.text);
    if (_year.round() < 1950 ||
        _year.round() > DateTime.now().year + 1 ||
        enteredMileage == null ||
        enteredMileage > 1000000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check the model year and mileage.')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final provider = context.read<ListingsProvider>();

    if (!_isEdit && !auth.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to post a vehicle.')),
      );
      return;
    }

    setState(() => _saving = true);

    final brand = _brand.text.trim();
    final model = _model.text.trim();
    final mileage = parseGroupedInt(_mileage.text);
    final description = _description.text.trim();
    final city = _city.text.trim();
    final year = _year.round();
    final price = _price.round();

    final unusual = _category == CarCategory.motorcycle
        ? price < 15000 || price > 5000000
        : price < 100000 || price > 100000000;
    if (!_isEdit && unusual) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Price looks unusual'),
          content: Text(
            'PKR ${formatGroupedInt(price)} is outside the typical range for this vehicle. Check that the price is correct.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Review'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Post anyway'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }
    final duplicate = provider.listings.any(
      (item) =>
          !_isEdit &&
          item.sellerId == auth.userId &&
          item.brand.toLowerCase() == brand.toLowerCase() &&
          item.model.toLowerCase() == model.toLowerCase() &&
          item.year == year &&
          item.price == price &&
          DateTime.now().difference(item.createdAt).inDays <= 30,
    );
    if (duplicate) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Possible duplicate'),
          content: const Text(
            'You posted a similar vehicle recently. Do you still want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    String? error;
    if (_isEdit) {
      error = await provider.updateCar(
        editing: widget.editing!,
        category: _category,
        brand: brand,
        model: model,
        year: year,
        price: price,
        mileage: mileage,
        engineCc: _category == CarCategory.motorcycle ? _engineCc : null,
        bikeType: _category == CarCategory.motorcycle ? _bikeType : null,
        variant: _variant.text.trim(),
        fuel: _fuel,
        transmission: _transmission,
        description: description.isEmpty ? null : description,
        city: city,
        latitude: _latitude,
        longitude: _longitude,
        retainedImageUrls: List<String>.from(_retainedRemoteUrls),
        newLocalPaths: List<String>.from(_imagePaths),
      );
    } else {
      error = await provider.addCar(
        sellerId: auth.userId ?? '',
        category: _category,
        brand: brand,
        model: model,
        year: year,
        price: price,
        mileage: mileage,
        engineCc: _category == CarCategory.motorcycle ? _engineCc : null,
        bikeType: _category == CarCategory.motorcycle ? _bikeType : null,
        variant: _variant.text.trim(),
        fuel: _fuel,
        transmission: _transmission,
        description: description.isEmpty ? null : description,
        city: city,
        latitude: _latitude,
        longitude: _longitude,
        pickedImagePaths: List<String>.from(_imagePaths),
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEdit ? 'Car updated.' : 'Your car is now live.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = _isEdit ? 'Edit car' : 'Add car';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(title), elevation: 0),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AGDesign.md,
            AGDesign.md,
            AGDesign.md,
            AGDesign.xxl,
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(AGDesign.md),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(AGDesign.radiusMd),
                border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
              ),
              child: Text(
                'Fill in the real details of your car. Accurate info builds '
                'trust with buyers.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: AGDesign.xl),
            Text(
              'Vehicle details',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AGDesign.sm),
            Text('Vehicle type', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AGDesign.sm),
            Wrap(
              spacing: AGDesign.xs,
              runSpacing: AGDesign.xs,
              children: CarCategory.values
                  .map(
                    (category) => ChoiceChip(
                      label: Text(category.label),
                      selected: _category == category,
                      onSelected: (_) => setState(() {
                        _category = category;
                        if (category == CarCategory.motorcycle) {
                          _engineCc ??= 125;
                          _bikeType = _bikeTypes.first;
                          _price = _price.clamp(10000, 5000000).toDouble();
                        } else {
                          _price = _price.clamp(100000, 50000000).toDouble();
                        }
                        _brand.clear();
                        _model.clear();
                      }),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: AGDesign.md),
            _AutocompleteField(
              label: _category == CarCategory.motorcycle
                  ? 'Bike brand'
                  : 'Brand',
              hint: _category == CarCategory.motorcycle
                  ? 'e.g. Honda, Yamaha, Suzuki'
                  : 'e.g. Toyota, Suzuki, Honda',
              controller: _brand,
              options: _makeOptions,
              onChanged: (_) => setState(() {
                _model.clear();
                _variant.clear();
              }),
            ),
            const SizedBox(height: AGDesign.md),
            _AutocompleteField(
              label: _category == CarCategory.motorcycle
                  ? 'Bike model'
                  : 'Model',
              hint: _category == CarCategory.motorcycle
                  ? 'e.g. CD 70, CG 125, YBR 125'
                  : 'e.g. Corolla, Alto, Civic',
              controller: _model,
              options: _modelsForBrand,
              onChanged: (_) => setState(() => _variant.clear()),
              onSelected: (model) {
                if (_category == CarCategory.motorcycle) {
                  final cc = suggestedBikeEngineCc(model);
                  if (cc != null) setState(() => _engineCc = cc);
                }
              },
            ),
            const SizedBox(height: AGDesign.md),
            _AutocompleteField(
              label: 'Variant / trim',
              hint: 'Choose a trim or type another',
              controller: _variant,
              options: _variantsForModel,
            ),
            if (_category == CarCategory.motorcycle) ...[
              const SizedBox(height: AGDesign.md),
              _DropdownField(
                label: 'Bike type',
                value: _bikeType,
                items: _bikeTypes,
                onChanged: (value) => setState(() {
                  _bikeType = value!;
                  _fuel = _bikeType == 'Electric' ? 'Electric' : 'Petrol';
                }),
              ),
              const SizedBox(height: AGDesign.md),
              _DropdownField(
                label: 'Engine capacity',
                value: '${_engineCc ?? 125} cc',
                items: _bikeEngineOptions,
                onChanged: (value) => setState(
                  () => _engineCc = int.tryParse(value.split(' ').first),
                ),
              ),
            ],
            const SizedBox(height: AGDesign.md),
            _SliderCard(
              label: 'Year',
              valueText: _year.round().toString(),
              child: Slider(
                min: 1990,
                max: DateTime.now().year.toDouble(),
                divisions: DateTime.now().year - 1990,
                value: _year,
                label: _year.round().toString(),
                onChanged: (v) => setState(() => _year = v),
              ),
            ),
            const SizedBox(height: AGDesign.md),
            _SliderCard(
              label: 'Price (PKR)',
              valueText: formatGroupedInt(_price.round()),
              child: Slider(
                min: _category == CarCategory.motorcycle ? 10000 : 100000,
                max: _category == CarCategory.motorcycle ? 5000000 : 50000000,
                divisions: 499,
                value: _price,
                label: formatGroupedInt(_price.round()),
                onChanged: (v) => setState(() => _price = v),
              ),
            ),
            const SizedBox(height: AGDesign.md),
            _TextField(
              controller: _mileage,
              keyboardType: TextInputType.number,
              inputFormatters: const [CommaSeparatedNumberInputFormatter()],
              label: _category == CarCategory.motorcycle
                  ? 'Odometer (km)'
                  : 'Mileage (km)',
              hint: 'e.g. 35,000',
              validator: (v) {
                final text = v?.trim() ?? '';
                if (text.isEmpty) return 'Required';
                final value = parseGroupedInt(text);
                if (value == null || value < 0) return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: AGDesign.md),
            if (_category != CarCategory.motorcycle)
              _DropdownField(
                label: 'Fuel',
                value: _fuel,
                items: _fuels,
                onChanged: (v) => setState(() => _fuel = v!),
              ),
            if (_category != CarCategory.motorcycle)
              const SizedBox(height: AGDesign.md),
            if (_category != CarCategory.motorcycle)
              _DropdownField(
                label: 'Transmission',
                value: _transmission,
                items: _transmissions,
                onChanged: (v) => setState(() => _transmission = v!),
              ),
            const SizedBox(height: AGDesign.md),
            _TextField(
              controller: _city,
              textCapitalization: TextCapitalization.words,
              label: 'City',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: AGDesign.xs),
            OutlinedButton.icon(
              onPressed: _gettingLocation ? null : _useCurrentLocation,
              icon: _gettingLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _latitude == null
                          ? Icons.location_searching
                          : Icons.location_on,
                    ),
              label: Text(
                _latitude == null
                    ? 'Add approximate location for nearby search (optional)'
                    : 'Approximate location added · tap to update',
              ),
            ),
            if (_latitude != null)
              TextButton(
                onPressed: () => setState(() {
                  _latitude = null;
                  _longitude = null;
                }),
                child: const Text('Remove shared location'),
              ),
            const SizedBox(height: AGDesign.md),
            _TextField(
              controller: _description,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              label: 'Description',
              hint: 'Condition, documents, extras, reason for selling…',
              validator: (v) => (v == null || v.trim().length < 10)
                  ? 'Add at least a short description'
                  : null,
            ),
            const SizedBox(height: AGDesign.xl),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Photos',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '$_photoCount/4',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AGDesign.sm),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Material(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: _showImageSourceSheet,
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 100,
                        height: 100,
                        child: Icon(
                          Icons.add_photo_alternate_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  ..._retainedRemoteUrls.map(
                    (url) => _ImageTile(
                      child: listingImageThumbnail(
                        context,
                        url,
                        width: 100,
                        height: 100,
                        fit: BoxFit.contain,
                      ),
                      onRemove: () =>
                          setState(() => _retainedRemoteUrls.remove(url)),
                    ),
                  ),
                  ..._imagePaths.map(
                    (path) => _ImageTile(
                      child: listingImageThumbnail(
                        context,
                        path,
                        width: 100,
                        height: 100,
                        fit: BoxFit.contain,
                      ),
                      onRemove: () => setState(() => _imagePaths.remove(path)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AGDesign.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AGDesign.radiusMd),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEdit ? 'Save changes' : 'Publish car'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _isMotorcycle => _category == CarCategory.motorcycle;

  List<String> get _makeOptions {
    final catalog = _isMotorcycle ? pakistanBikeCatalog : pakistanCarCatalog;
    final extras = _isMotorcycle
        ? extraPakistanBikeMakes
        : extraPakistanCarMakes;
    return {...catalog.keys, ...extras}.toList()..sort();
  }

  Map<String, List<String>> get _brandCatalog {
    final catalog = _isMotorcycle ? pakistanBikeCatalog : pakistanCarCatalog;
    for (final entry in catalog.entries) {
      if (entry.key.toLowerCase() == _brand.text.trim().toLowerCase()) {
        return entry.value;
      }
    }
    return const {};
  }

  List<String> get _modelsForBrand => _brandCatalog.isNotEmpty
      ? _brandCatalog.keys.toList()
      : _isMotorcycle
      ? pakistanBikeCatalog.values
            .expand((models) => models.keys)
            .toSet()
            .toList()
      : _legacyModelOptions(_brand.text.trim());

  List<String> get _variantsForModel {
    for (final entry in _brandCatalog.entries) {
      if (entry.key.toLowerCase() == _model.text.trim().toLowerCase()) {
        return entry.value;
      }
    }
    return const [];
  }

  List<String> _legacyModelOptions(String brand) {
    switch (brand.toLowerCase()) {
      case 'toyota':
        return [
          'Corolla',
          'Yaris',
          'Hilux',
          'Hilux Revo',
          'Hilux Vigo',
          'Land Cruiser',
          'Prado',
          'Camry',
        ];
      case 'honda':
        return ['City', 'Civic', 'BR-V', 'HR-V', 'Accord', 'Fit'];
      case 'suzuki':
        return [
          'Alto',
          'Wagon R',
          'Swift',
          'Cultus',
          'Mehran',
          'Vitara',
          'Every',
          'Ravi',
          'Bolan',
        ];
      default:
        return [
          'Sportage',
          'Elantra',
          'Tucson',
          'Sonata',
          'Revo',
          'D-Max',
          'T9 Hunter',
          'Shark',
          'Oshan X7',
          'Alsvin',
          'CS75 Plus',
          'ZS',
          'H6',
        ];
    }
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({required this.child, required this.onRemove});

  final Widget child;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AGDesign.xs),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: child,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: IconButton(
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close, size: 18),
                color: Colors.white,
                onPressed: onRemove,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AutocompleteField extends StatelessWidget {
  const _AutocompleteField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.options,
    this.onChanged,
    this.onSelected,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final List<String> options;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (TextEditingValue value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) return options;
        return options.where((e) => e.toLowerCase().contains(query));
      },
      onSelected: (String selected) {
        controller.text = selected;
        onChanged?.call(selected);
        onSelected?.call(selected);
      },
      fieldViewBuilder: (context, fieldController, focusNode, onSubmit) {
        if (fieldController.text != controller.text) {
          fieldController.text = controller.text;
          fieldController.selection = TextSelection.fromPosition(
            TextPosition(offset: fieldController.text.length),
          );
        }
        return TextFormField(
          controller: fieldController,
          focusNode: focusNode,
          onChanged: (v) {
            controller.text = v;
            onChanged?.call(v);
          },
          textCapitalization: TextCapitalization.words,
          decoration: AGDesign.inputDecoration(
            context: context,
            label: label,
            hint: hint,
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        );
      },
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: items.contains(value) ? value : items.first,
      decoration: AGDesign.inputDecoration(context: context, label: label),
      items: items
          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
          .toList(),
      onChanged: (v) => onChanged(v ?? value),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    required this.label,
    this.hint,
    this.validator,
  });

  final TextEditingController controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final TextCapitalization textCapitalization;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      decoration: AGDesign.inputDecoration(
        context: context,
        label: label,
        hint: hint,
      ),
      validator: validator,
    );
  }
}

class _SliderCard extends StatelessWidget {
  const _SliderCard({
    required this.label,
    required this.valueText,
    required this.child,
  });

  final String label;
  final String valueText;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AGDesign.radiusMd),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleSmall),
              Text(
                valueText,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }
}

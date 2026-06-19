import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/mianwali_data.dart';
import '../models/car_category.dart';
import '../models/car_listing.dart';
import '../providers/listings_provider.dart';
import '../utils/listing_image.dart';
import '../utils/local_file_image_io.dart'
    if (dart.library.html) '../utils/local_file_image_web.dart';

class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({
    super.key,
    this.editing,
  });

  /// When non-null, saves changes to an existing cloud listing.
  final CarListing? editing;

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  static const List<String> _bodyTypeSuggestions = <String>[
    'Sedan',
    'SUV',
    'Hatchback',
    'Pickup',
    'Compact',
    'Crossover',
    'Jeep',
    'Van',
  ];
  static const List<String> _modelSuggestions = <String>[
    'Toyota Corolla',
    'Toyota Yaris',
    'Suzuki Alto',
    'Suzuki Wagon R',
    'Honda City',
    'Honda Civic',
    'Honda BR-V',
    'Kia Sportage',
    'Hyundai Elantra',
    'Toyota Hilux',
    'Toyota Hilux Revo',
    'Toyota Hilux Vigo',
    'JAC T9 Hunter',
    'BYD Shark',
    'Isuzu D-Max',
  ];
  static const List<String> _pickupModelSuggestions = <String>[
    'Toyota Hilux Revo',
    'Toyota Hilux Vigo',
    'JAC T9 Hunter',
    'BYD Shark',
  ];
  static const List<_ColorOption> _exteriorColorOptions = <_ColorOption>[
    _ColorOption('White', Colors.white),
    _ColorOption('Black', Colors.black),
    _ColorOption('Silver', Color(0xFFC0C0C0)),
    _ColorOption('Grey', Color(0xFF808080)),
    _ColorOption('Blue', Colors.blue),
    _ColorOption('Red', Colors.red),
    _ColorOption('Green', Colors.green),
  ];
  static const List<String> _registrationProvinces = <String>[
    'Punjab',
    'Sindh',
    'KPK',
    'Islamabad',
    'Balochistan',
  ];
  late final TextEditingController _bodyType;
  late final TextEditingController _modelName;
  late final TextEditingController _registration;
  late final TextEditingController _color;
  late final TextEditingController _engineCc;
  late final TextEditingController _sellerName;
  late final TextEditingController _sellerPhone;
  late final TextEditingController _notes;

  late CarCategory _category;
  late String _location;
  late String _registrationProvince;
  /// New local files to upload.
  final List<String> _imagePaths = [];
  /// Existing remote URLs retained when editing (order preserved).
  final List<String> _retainedRemoteUrls = [];

  bool _saving = false;
  late double _selectedYear;
  late double _selectedPrice;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _bodyType = TextEditingController(text: e?.bodyType ?? '');
    _modelName = TextEditingController(text: e?.modelName ?? '');
    _registration = TextEditingController(text: e?.registrationNumber ?? '');
    _color = TextEditingController(text: e?.color ?? '');
    _engineCc = TextEditingController(
      text: e?.engineCc != null ? '${e!.engineCc}' : '',
    );
    _sellerName = TextEditingController(text: e?.sellerName ?? '');
    _sellerPhone = TextEditingController(text: e?.sellerPhone ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _selectedYear = (e?.modelYear ?? DateTime.now().year).toDouble();
    _selectedPrice = ((e?.askingPricePkr ?? 2500000).clamp(500000, 15000000))
        .toDouble();
    _category = e?.category ?? CarCategory.sedan;
    _location = e?.locationArea ?? kMianwaliLocations.first;
    _seedRegistrationFields(e?.registrationNumber ?? '');

    if (e != null) {
      for (final p in e.imagePaths) {
        final t = p.trim();
        final net = t.startsWith('http://') || t.startsWith('https://');
        if (net) {
          _retainedRemoteUrls.add(t);
        } else if (!kIsWeb && localFileExists(t)) {
          _imagePaths.add(t);
        }
      }
    }
  }

  @override
  void dispose() {
    _bodyType.dispose();
    _modelName.dispose();
    _registration.dispose();
    _color.dispose();
    _engineCc.dispose();
    _sellerName.dispose();
    _sellerPhone.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 82);
    if (file != null && mounted) {
      setState(() => _imagePaths.add(file.path));
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final pricePkr = _selectedPrice.round();
    final year = _selectedYear.round();

    setState(() => _saving = true);
    try {
      final lp = context.read<ListingsProvider>();
      final parsedEngineCc = int.tryParse(_engineCc.text.trim());
      if (_isEdit) {
        final e = widget.editing!;
        final err = await lp.updateListing(
          editing: e,
          category: _category,
          bodyType: _bodyType.text.trim(),
          modelName: _modelName.text.trim(),
          modelYear: year,
          registrationNumber: _composedRegistrationNumber(),
          color: _color.text.trim(),
          engineCc: parsedEngineCc,
          locationArea: _location,
          sellerName: _sellerName.text.trim(),
          sellerPhone: _sellerPhone.text.trim(),
          askingPricePkr: pricePkr,
          notes: _notes.text,
          retainedImageUrls: List<String>.from(_retainedRemoteUrls),
          newLocalPaths: List<String>.from(_imagePaths),
        );
        if (!mounted) return;
        if (err != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err)),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing updated.')),
        );
      } else {
        final err = await lp.addListing(
          category: _category,
          bodyType: _bodyType.text.trim(),
          modelName: _modelName.text.trim(),
          modelYear: year,
          registrationNumber: _composedRegistrationNumber(),
          color: _color.text.trim(),
          engineCc: parsedEngineCc,
          locationArea: _location,
          sellerName: _sellerName.text.trim(),
          sellerPhone: _sellerPhone.text.trim(),
          askingPricePkr: pricePkr,
          notes: _notes.text,
          pickedImagePaths: List.from(_imagePaths),
        );
        if (!mounted) return;
        if (err != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err)),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your car advertisement is live.')),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? 'Edit listing' : 'Sell your car';
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withOpacity(0.35),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.primary.withOpacity(0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'All listings are for $kCityName only. Add clear photos and complete details for stronger trust.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB3261E),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'PRO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Vehicle details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            _buildBodyTypeAutocomplete(),
            const SizedBox(height: 12),
            Text('Category', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<CarCategory>(
                segments: CarCategory.values
                    .map(
                      (c) => ButtonSegment(
                        value: c,
                        label: Text(c.label, textAlign: TextAlign.center),
                      ),
                    )
                    .toList(),
                selected: {_category},
                onSelectionChanged: (s) {
                  setState(() => _category = s.first);
                }),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Area in Mianwali'),
              // ignore: deprecated_member_use
              value: _location,
              items: kMianwaliLocations
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _location = v ?? _location),
            ),
            const SizedBox(height: 16),
            _buildModelAutocomplete(),
            if (_category == CarCategory.pickup) ...[
              const SizedBox(height: 12),
              _buildPickupQuickSection(),
            ],
            const SizedBox(height: 12),
            _SliderCard(
              label: 'Model year',
              valueText: _selectedYear.round().toString(),
              child: Slider(
                min: 1990,
                max: DateTime.now().year.toDouble(),
                divisions: DateTime.now().year - 1990,
                value: _selectedYear,
                label: _selectedYear.round().toString(),
                onChanged: (v) => setState(() => _selectedYear = v),
              ),
            ),
            const SizedBox(height: 12),
            _buildExteriorColorSelector(),
            const SizedBox(height: 12),
            TextFormField(
              controller: _engineCc,
              decoration: const InputDecoration(
                labelText: 'Engine CC',
                hintText: 'e.g. 2400',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                final text = v?.trim() ?? '';
                if (text.isEmpty) return 'Required';
                final cc = int.tryParse(text);
                if (cc == null || cc < 600) return 'Enter valid CC';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildRegistrationSection(),
            const SizedBox(height: 12),
            const SizedBox(height: 10),
            _SliderCard(
              label: 'Asking price (PKR)',
              valueText: '${_selectedPrice.round()}',
              child: Slider(
                min: 500000,
                max: 15000000,
                divisions: 145,
                value: _selectedPrice,
                label: '${_selectedPrice.round()}',
                onChanged: (v) => setState(() => _selectedPrice = v),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),
            Text(
              'Photos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Material(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
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
                  ..._retainedRemoteUrls.map((url) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: listingImageThumbnail(
                              url,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Material(
                              color: Colors.black54,
                              shape: const CircleBorder(),
                              child: IconButton(
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.close, size: 18),
                                color: Colors.white,
                                onPressed: () {
                                  setState(
                                    () => _retainedRemoteUrls.remove(url),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  ..._imagePaths.map((path) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: listingImageThumbnail(
                              path,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Material(
                              color: Colors.black54,
                              shape: const CircleBorder(),
                              child: IconButton(
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.close, size: 18),
                                color: Colors.white,
                                onPressed: () {
                                  setState(() => _imagePaths.remove(path));
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Your contact',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sellerName,
              decoration: const InputDecoration(labelText: 'Your name'),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sellerPhone,
              decoration: const InputDecoration(
                labelText: 'Mobile number',
                hintText: '03XX XXXXXXX',
              ),
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  (v == null || v.trim().length < 10) ? 'Enter a valid number' : null,
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? 'Save changes' : 'Publish advertisement'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelAutocomplete() {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _modelName.text),
      optionsBuilder: (TextEditingValue value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return _modelSuggestions;
        return _modelSuggestions.where((e) => e.toLowerCase().contains(q));
      },
      onSelected: (String selected) {
        _modelName.text = selected;
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        controller.text = _modelName.text;
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          onChanged: (v) => _modelName.text = v,
          decoration: const InputDecoration(
            labelText: 'Make & model',
            hintText: 'Type to see suggestions (e.g. Toyota Corolla)',
            helperText: 'Auto-suggestions help you enter faster',
          ),
          textCapitalization: TextCapitalization.words,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        );
      },
    );
  }

  Widget _buildBodyTypeAutocomplete() {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _bodyType.text),
      optionsBuilder: (TextEditingValue value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return _bodyTypeSuggestions;
        return _bodyTypeSuggestions.where((e) => e.toLowerCase().contains(q));
      },
      onSelected: (String selected) {
        _bodyType.text = selected;
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        controller.text = _bodyType.text;
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          onChanged: (v) => _bodyType.text = v,
          decoration: const InputDecoration(
            labelText: 'Body type',
            hintText: 'Sedan, SUV, Hatchback, Pickup...',
            helperText: 'Includes Pickup option for quick selection',
          ),
          textCapitalization: TextCapitalization.words,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        );
      },
    );
  }

  Widget _buildPickupQuickSection() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pickup quick selection',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _pickupModelSuggestions
                .map(
                  (model) => ActionChip(
                    label: Text(model),
                    onPressed: () => setState(() => _modelName.text = model),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildExteriorColorSelector() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Exterior colour',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _exteriorColorOptions.map((option) {
            final selected =
                _color.text.trim().toLowerCase() == option.name.toLowerCase();
            final borderColor = selected ? cs.primary : cs.outlineVariant;
            return InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => setState(() => _color.text = option.name),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: option.color,
                  border: Border.all(color: borderColor, width: selected ? 2 : 1),
                ),
                child: selected
                    ? Icon(
                        Icons.check,
                        size: 16,
                        color: option.color.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _color,
          decoration: const InputDecoration(
            labelText: 'Selected colour',
            hintText: 'Tap icon or type custom colour',
          ),
          textCapitalization: TextCapitalization.words,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _buildRegistrationSection() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Registration details',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _registrationProvince,
            decoration: const InputDecoration(labelText: 'Province / Region'),
            items: _registrationProvinces
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _registrationProvince = value);
            },
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _registration,
            decoration: const InputDecoration(
              labelText: 'Registration number',
              hintText: 'e.g. ABC-123 or LEA-22-1234',
            ),
            textCapitalization: TextCapitalization.characters,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  void _seedRegistrationFields(String fullRegistration) {
    _registrationProvince = _registrationProvinces.first;
    final value = fullRegistration.trim();
    for (final p in _registrationProvinces) {
      final prefix = '$p - ';
      if (value.startsWith(prefix)) {
        _registrationProvince = p;
        _registration.text = value.substring(prefix.length);
        return;
      }
    }
    _registration.text = value;
  }

  String _composedRegistrationNumber() {
    final number = _registration.text.trim().toUpperCase();
    return '$_registrationProvince - $number';
  }
}

class _ColorOption {
  const _ColorOption(this.name, this.color);

  final String name;
  final Color color;
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
        borderRadius: BorderRadius.circular(12),
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

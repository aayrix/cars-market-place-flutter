/// Local suggestions based on the Pakistan-market lineup supplied for this app.
/// Sellers can still type models and variants that are missing from the list.
const Map<String, Map<String, List<String>>> pakistanCarCatalog = {
  'Toyota': {
    'Corolla': [
      'XLi 1.3',
      'GLi 1.3 Manual',
      'GLi 1.3 Automatic VVTi',
      'Altis 1.6 Manual',
      'Altis 1.6 Automatic',
      'Altis X Manual 1.6',
      'Altis X Automatic 1.6',
      'Altis X Special Edition 1.6',
      'Altis Grande 1.8 CVT',
      'Altis Grande X 1.8 CVT',
    ],
    'Yaris': [
      'GLI MT 1.3',
      'GLI CVT 1.3',
      'ATIV MT 1.3',
      'ATIV CVT 1.3',
      'ATIV X MT 1.5',
      'ATIV X CVT 1.5',
    ],
    'Corolla Cross': ['1.8 Petrol', '1.8 HEV', '1.8 HEV X'],
    'Fortuner': ['2.7 G', '2.7 V', '2.8 Sigma 4', 'Legender'],
    'Hilux': ['Revo G', 'Revo V', 'Revo Rocco', 'GR-S'],
  },
  'Suzuki': {
    'Alto': ['VX', 'VXR', 'VXL AGS'],
    'Cultus': ['VXR', 'VXL', 'AGS'],
    'Swift': ['GL MT', 'GL CVT', 'GLX CVT'],
    'Wagon R': ['VXR', 'VXL', 'AGS'],
    'Bolan': ['Van', 'Cargo'],
    'Ravi': ['Euro II Pickup'],
  },
  'Honda': {
    'City': [
      '1.2L M/T',
      '1.2L CVT',
      '1.5L Aspire M/T',
      '1.5L Aspire CVT (Prosmatec)',
    ],
    'Civic': ['Oriel 1.5 VTEC Turbo CVT', 'RS Turbo'],
    'BR-V': ['i-VTEC S'],
    'HR-V': ['VTi', 'VTi-S'],
  },
  'Hyundai': {
    'Elantra': ['GLS'],
    'Sonata': ['2.0', '2.5'],
    'Tucson': ['FWD GLS', 'AWD Ultimate'],
    'Porter': ['H-100'],
  },
  'Kia': {
    'Picanto': ['MT', 'AT'],
    'Stonic': ['EX', 'EX+'],
    'Sportage': ['Alpha', 'FWD', 'AWD'],
    'Sorento': ['FWD 2.4L', 'AWD 2.4L', 'FWD 3.5L', 'AWD 3.5L'],
  },
  'Changan': {
    'Alsvin': ['Comfort MT', 'Comfort DCT', 'Lumiere'],
    'Oshan X7': ['Comfort', 'FutureSense'],
    'Karvaan': ['Plus'],
  },
  'Haval': {
    'Jolion': ['2WD', 'HEV'],
    'H6': ['HEV', 'PHEV'],
  },
  'MG': {
    'HS': ['Excite', 'Essence', 'PHEV'],
    'ZS': ['ZS EV'],
  },
  'DFSK': {
    'Glory 580': ['Standard', 'Premium'],
    'Glory i-Auto': ['Standard'],
    'Prince': ['Standard'],
  },
  'Proton': {
    'Saga': ['Standard', 'Premium'],
    'X50': ['Standard', 'Premium'],
    'X70': ['Premium'],
  },
  'BYD': {
    'Atto 3': ['EV'],
    'Seal': ['EV'],
    'Shark': ['Plug-in Hybrid'],
  },
};

const Map<String, Map<String, List<String>>> pakistanBikeCatalog = {
  'Honda': {
    'CD 70': ['Standard'],
    'CD 70 Dream': ['Standard'],
    'Pridor': ['100cc'],
    'CG 125': ['Standard', 'Special Edition (SE)', 'CG 125S', 'CG 125S Gold'],
    'CB 125F': ['Standard'],
    'CB 150F': ['Standard'],
    'CG 150': ['Standard'],
    'Icon e': ['Electric scooter'],
  },
  'Yamaha': {
    'YB 125Z': ['Standard'],
    'YB 125Z-DX': ['Standard'],
    'YBR 125': ['Standard'],
    'YBR 125G': ['Standard', 'Gold'],
    'YBZ': ['Older model'],
    'Dhoom 70': ['Older model'],
  },
  'Suzuki': {
    'GD 110S': ['Standard'],
    'GS 150': ['Standard', 'SE'],
    'GR 150': ['Standard', 'CBS', 'ABS'],
    'Gixxer 150': ['Limited'],
    'GS 125': ['Older model'],
  },
  'United': {
    'US 70': ['Standard'],
    'US 100': ['Standard'],
    'US 125': ['Standard'],
    'US 150 Deluxe': ['Standard'],
    'Zonda 70': ['Older model'],
    'Jazba': ['Standard'],
  },
  'Road Prince': {
    'RP 70': ['Standard'],
    'RP 100': ['Standard'],
    'RP 125': ['Standard'],
    'RP Dhoom 70': ['Standard'],
    'Wego 150': ['Scooter'],
    'Cargo 100': ['Loader'],
  },
  'Unique': {
    'UD 70': ['Standard'],
    'UD 100': ['Standard'],
    'UD 125': ['Standard'],
    'UD 150': ['Pride', 'Deluxe'],
    'Uniq 125': ['Standard'],
  },
  'Super Power': {
    'SP 70': ['Standard'],
    'SP 100': ['Standard'],
    'SP 125': ['Standard'],
    'SP 150': ['Euro II'],
    'Archi': ['Scooter'],
    'Cargo': ['Loader'],
  },
  'Super Star': {
    'SS 70': ['Standard'],
    'SS 100': ['Standard'],
    'SS 125': ['Standard'],
    'SS 150': ['Standard'],
  },
  'Metro': {
    'MR 70': ['Standard'],
    'MR 100': ['Standard'],
    'MR 125': ['Standard'],
    'MR 150': ['Standard'],
    'Metro Peak': ['Electric scooter'],
  },
  'Hi-Speed': {
    'SR 70': ['Standard'],
    'SR 100': ['Standard'],
    'SR 150': ['Standard'],
  },
  'Eagle': {
    'EG 70': ['Standard'],
    'EG 100': ['Standard'],
    'EG 125': ['Standard'],
    'Eagle EV': ['Electric'],
  },
  'Pak Hero': {
    'HR 70': ['Standard'],
    'HR 100': ['Standard'],
    'Splendor': ['Older model'],
    'Cruiser 125': ['Standard'],
  },
  'Ravi': {
    'Piaggio': ['Standard'],
  },
  'Yadea': {
    'C1S': ['Electric'],
    'T9': ['Electric'],
  },
  'Jolta': {
    'Rangoon': ['Electric'],
    'JE-2': ['Electric'],
  },
  'Zero': {
    'Electric Bike': ['Electric'],
  },
  'Maple Leaf': {
    'Electric Bike': ['Electric'],
  },
};

const List<String> extraPakistanCarMakes = [
  'Daihatsu',
  'Nissan',
  'Mitsubishi',
  'Isuzu',
  'JAC',
  'BYD',
  'Changan',
  'MG',
  'Haval',
  'Proton',
  'Ford',
  'Chevrolet',
  'DFSK',
  'Other',
];

const List<String> extraPakistanBikeMakes = [
  'Crown',
  'Benelli',
  'Kawasaki',
  'Other',
];

int? suggestedBikeEngineCc(String model) {
  final normalized = model.toLowerCase();
  if (normalized.contains('icon e') ||
      normalized.contains('ev') ||
      normalized.contains('electric') ||
      normalized.contains('peak')) {
    return null;
  }
  final match = RegExp(
    r'\b(70|100|110|125|150|200|250|300|400|600|1000)\b',
  ).firstMatch(normalized);
  return match == null ? null : int.tryParse(match.group(1)!);
}

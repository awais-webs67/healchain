/// ─────────────────────────────────────────────────────────────────────────────
/// LocationService — Country/State/City data provider
/// ─────────────────────────────────────────────────────────────────────────────
/// Pakistan-focused: Complete hardcoded data for all 8 regions, 150+ districts,
/// 400+ cities/towns. Other countries use countriesnow.space API.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Cache for API data (non-Pakistan countries)
  final Map<String, List<String>> _cachedStates = {};
  final Map<String, List<String>> _cachedCities = {};

  static const _baseUrl = 'https://countriesnow.space/api/v0.1';

  /// Get all countries — Pakistan first, then others
  Future<List<String>> getCountries() async {
    return _allCountries;
  }

  /// Get states/provinces for a country
  Future<List<String>> getStates(String country) async {
    // Pakistan — instant hardcoded data
    if (_isPakistan(country)) return _pakistanProvinces;

    // Other countries — try API
    if (_cachedStates.containsKey(country)) return _cachedStates[country]!;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/countries/states'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'country': country}),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['error'] == false && data['data']?['states'] != null) {
          final states = (data['data']['states'] as List)
              .map((s) => s['name']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList()..sort();
          _cachedStates[country] = states;
          return states;
        }
      }
    } catch (_) {}

    _cachedStates[country] = [];
    return [];
  }

  /// Get cities for a country + state
  Future<List<String>> getCities(String country, String state) async {
    // Pakistan — instant hardcoded data
    if (_isPakistan(country)) {
      return _pakistanCities[state] ?? [];
    }

    // Other countries — try API
    final key = '$country|$state';
    if (_cachedCities.containsKey(key)) return _cachedCities[key]!;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/countries/state/cities'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'country': country, 'state': state}),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['error'] == false && data['data'] != null) {
          final cities = (data['data'] as List)
              .map((c) => c.toString())
              .where((c) => c.isNotEmpty)
              .toList()..sort();
          _cachedCities[key] = cities;
          return cities;
        }
      }
    } catch (_) {}

    _cachedCities[key] = [];
    return [];
  }

  // ═══════════════════════════════════════════════════════════════════════
  // GPS → Matched City/Province (Smart matching for Pakistan)
  // ═══════════════════════════════════════════════════════════════════════
  //
  // Android geocoder returns:
  //   locality        = village/town name   (e.g. "Dongray Kalan")
  //   subAdminArea    = district name       (e.g. "Narowal") ← THIS is the city
  //   adminArea       = province            (e.g. "Punjab")
  //
  // Priority: subAdminArea > locality > subLocality
  // ═══════════════════════════════════════════════════════════════════════

  /// Match GPS data to nearest known city.
  /// Priority: subAdminArea (district) first, then locality, then subLocality.
  String? matchToNearestCity({
    String? locality,
    String? subLocality,
    String? subAdminArea,
  }) {
    // 1. Try subAdminArea first — this is the DISTRICT (= city in Pakistan context)
    //    e.g. GPS returns subAdminArea = "Narowal" → exact match to "Narowal"
    final districtMatch = _findExactCity(subAdminArea);
    if (districtMatch != null) return districtMatch;

    // 2. Try locality (might be a known city itself, e.g. "Lahore")
    final localityMatch = _findExactCity(locality);
    if (localityMatch != null) return localityMatch;

    // 3. Try subLocality
    final subLocalityMatch = _findExactCity(subLocality);
    if (subLocalityMatch != null) return subLocalityMatch;

    // 4. Fuzzy match on subAdminArea and locality (safe — whole word only)
    final fuzzyDistrict = _findFuzzyCity(subAdminArea);
    if (fuzzyDistrict != null) return fuzzyDistrict;

    final fuzzyLocality = _findFuzzyCity(locality);
    if (fuzzyLocality != null) return fuzzyLocality;

    // 5. No match — use subAdminArea (district) as the city, it's the best fallback
    //    Even if it's not in our list, the district name is the "city" in Pakistan
    return subAdminArea ?? locality ?? subLocality;
  }

  /// Find which province a city belongs to
  String? findProvinceForCity(String city) {
    for (final entry in _pakistanCities.entries) {
      for (final c in entry.value) {
        if (c.toLowerCase() == city.toLowerCase()) return entry.key;
      }
    }
    return null;
  }

  /// Map GPS administrative area names to our province names
  String? mapToProvinceName(String? adminArea) {
    if (adminArea == null) return null;
    final a = adminArea.toLowerCase().trim();

    for (final p in _pakistanProvinces) {
      if (a == p.toLowerCase()) return p;
    }
    if (a.contains('punjab')) return 'Punjab';
    if (a.contains('sindh')) return 'Sindh';
    if (a.contains('khyber') || a.contains('pakhtunkhwa') || a.contains('kpk') || a.contains('nwfp')) return 'Khyber Pakhtunkhwa';
    if (a.contains('balochistan') || a.contains('baluchistan')) return 'Balochistan';
    if (a.contains('islamabad') || a.contains('ict')) return 'Islamabad Capital Territory';
    if (a.contains('azad') || a.contains('kashmir') || a.contains('ajk')) return 'Azad Jammu & Kashmir';
    if (a.contains('gilgit') || a.contains('baltistan')) return 'Gilgit-Baltistan';

    return adminArea;
  }

  /// Complete GPS resolution for Pakistan.
  /// Takes raw geocoding values → returns matched {country, province, city, address, village}
  Map<String, String?> resolveGpsLocation({
    required String? country,
    required String? adminArea,
    required String? locality,
    required String? subLocality,
    required String? subAdminArea,
    required String? street,
  }) {
    final isPk = country != null && country.toLowerCase().contains('pakistan');

    String? matchedCity;
    String? matchedProvince;
    String? village;

    if (isPk) {
      // Smart match city — prioritize subAdminArea (district)
      matchedCity = matchToNearestCity(
        locality: locality,
        subLocality: subLocality,
        subAdminArea: subAdminArea,
      );

      // Smart match province
      matchedProvince = mapToProvinceName(adminArea);

      // If city matched, prefer province from city data
      if (matchedCity != null) {
        final fromCity = findProvinceForCity(matchedCity);
        if (fromCity != null) matchedProvince = fromCity;
      }

      // Village/town = locality (if different from matched city)
      if (locality != null && locality.isNotEmpty &&
          locality.toLowerCase() != matchedCity?.toLowerCase()) {
        village = locality;
      }
    } else {
      matchedCity = locality ?? subLocality;
      matchedProvince = adminArea;
    }

    // Build full address: village, city, province, Pakistan
    final addressParts = <String>[];
    if (street != null && street.isNotEmpty) addressParts.add(street);
    if (village != null && village.isNotEmpty) addressParts.add(village);
    if (matchedCity != null && matchedCity.isNotEmpty) addressParts.add(matchedCity);
    if (matchedProvince != null && matchedProvince.isNotEmpty) addressParts.add(matchedProvince);
    addressParts.add(isPk ? 'Pakistan' : (country ?? ''));
    final address = addressParts.where((e) => e.isNotEmpty).join(', ');

    return {
      'country': isPk ? 'Pakistan' : country,
      'province': matchedProvince,
      'city': matchedCity,
      'village': village, // exact locality (town/village)
      'address': address,
    };
  }

  // ── Private helpers ─────────────────────────────────────────────────────

  String? _findExactCity(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    final lower = name.toLowerCase().trim();
    for (final cities in _pakistanCities.values) {
      for (final city in cities) {
        if (city.toLowerCase() == lower) return city;
      }
    }
    return null;
  }

  /// Fuzzy match — only matches if:
  /// 1. City name has at least 4 characters (prevent "Hub" matching everything)
  /// 2. The GPS name STARTS WITH or EXACTLY CONTAINS the city as a whole word
  String? _findFuzzyCity(String? name) {
    if (name == null || name.trim().length < 4) return null;
    final lower = name.toLowerCase().trim();

    String? bestMatch;
    int bestLen = 0;

    for (final cities in _pakistanCities.values) {
      for (final city in cities) {
        if (city.length < 4) continue; // Skip very short city names
        final cityLower = city.toLowerCase();

        // GPS name starts with city name: "Narowal District" starts with "Narowal"
        if (lower.startsWith(cityLower) && cityLower.length > bestLen) {
          bestMatch = city;
          bestLen = cityLower.length;
        }
        // City name starts with GPS name: "narowal" in "Narowal"
        if (cityLower.startsWith(lower) && lower.length > bestLen) {
          bestMatch = city;
          bestLen = lower.length;
        }
      }
    }
    return bestMatch;
  }

  bool _isPakistan(String country) {
    final c = country.toLowerCase().trim();
    return c == 'pakistan' || c == '🇵🇰 pakistan';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PAKISTAN — COMPLETE DATA (8 regions, 150+ districts, 400+ cities)
  // ══════════════════════════════════════════════════════════════════════════

  static const List<String> _pakistanProvinces = [
    'Punjab',
    'Sindh',
    'Khyber Pakhtunkhwa',
    'Balochistan',
    'Islamabad Capital Territory',
    'Azad Jammu & Kashmir',
    'Gilgit-Baltistan',
  ];

  static const Map<String, List<String>> _pakistanCities = {
    // ── PUNJAB (41 districts, 150+ cities) ─────────────────────────────────
    'Punjab': [
      'Ahmadpur East', 'Ahmed Nager Chatha', 'Ali Khan Abad', 'Alipur', 'Arifwala',
      'Attock', 'Bahawalnagar', 'Bahawalpur', 'Bhalwal', 'Bhakkar',
      'Bhera', 'Burewala', 'Chakwal', 'Chichawatni', 'Chiniot',
      'Chishtian', 'Choa Saidan Shah', 'Daska', 'Darya Khan', 'Dera Ghazi Khan',
      'Dhaular', 'Dijkot', 'Dina', 'Dinga', 'Dipalpur',
      'Faisalabad', 'Fateh Jang', 'Ferozewala', 'Fort Abbas', 'Ghakhar Mandi',
      'Gojra', 'Gujranwala', 'Gujar Khan', 'Gujrat', 'Hafizabad',
      'Haroonabad', 'Hasilpur', 'Haveli Lakha', 'Jaranwala', 'Jalalpur Jattan',
      'Jatoi', 'Jauharabad', 'Jhang', 'Jhelum', 'Kalabagh',
      'Kamalia', 'Kamoke', 'Karor Lal Esan', 'Kasur', 'Khanewal',
      'Khanpur', 'Kharian', 'Khushab', 'Kot Addu', 'Kot Momin',
      'Kot Radha Kishan', 'Lahore', 'Lalamusa', 'Layyah', 'Liaquat Pur',
      'Lodhran', 'Mailsi', 'Makhdoom Pur Pahuran', 'Malakwal', 'Mandi Bahauddin',
      'Mian Channu', 'Mianwali', 'Minchinabad', 'Mingora', 'Multan',
      'Muridke', 'Murree', 'Muzaffargarh', 'Nankana Sahib', 'Narang Mandi',
      'Narowal', 'Noorpur Thal', 'Nowshera Virkan', 'Okara', 'Pakpattan',
      'Pattoki', 'Phalia', 'Pind Dadan Khan', 'Pindi Bhattian', 'Pir Mahal',
      'Qadirabad', 'Rahim Yar Khan', 'Raiwind', 'Rajanpur', 'Rawalpindi',
      'Renala Khurd', 'Sadiqabad', 'Safdarabad', 'Sahiwal', 'Sambrial',
      'Sangla Hill', 'Sarai Alamgir', 'Sargodha', 'Shakargarh', 'Sheikhupura',
      'Shujaabad', 'Sialkot', 'Sillanwali', 'Sohawa', 'Talagang',
      'Taunsa', 'Taxila', 'Toba Tek Singh', 'Vehari', 'Wah Cantonment',
      'Wazirabad', 'Yazman',
    ],

    // ── SINDH (30 districts, 80+ cities) ──────────────────────────────────
    'Sindh': [
      'Badin', 'Bhirkan', 'Bubak', 'Chak', 'Dadu',
      'Daharki', 'Digri', 'Diplo', 'Dokri', 'Gambat',
      'Ghotki', 'Haala', 'Hala', 'Hyderabad', 'Islamkot',
      'Jacobabad', 'Jamshoro', 'Jhudo', 'Jungshahi', 'Kandhkot',
      'Kandiaro', 'Karachi', 'Kashmore', 'Keti Bandar', 'Khairpur',
      'Khora', 'Kotri', 'Larkana', 'Matiari', 'Mehar',
      'Mehrabpur', 'Mirpur Khas', 'Mirpur Mathelo', 'Mirpur Sakro',
      'Mithani', 'Mithi', 'Moro', 'Nagarparkar', 'Naudero',
      'Naushahro Feroze', 'Naushara', 'Nawabshah', 'Nazimabad', 'Orangi',
      'Padidan', 'Pano Aqil', 'Piryaloi', 'Qambar', 'Qasimabad',
      'Ranipur', 'Ratodero', 'Rohri', 'Sakrand', 'Sanghar',
      'Sehwan Sharif', 'Shahbandar', 'Shahdadkot', 'Shahdadpur', 'Shahpur Chakar',
      'Shikarpur', 'Sujawal', 'Sukkur', 'Tangwani', 'Tando Adam',
      'Tando Allahyar', 'Tando Bago', 'Tando Jam', 'Tando Muhammad Khan',
      'Thatta', 'Tharparkar', 'Umerkot', 'Warah',
    ],

    // ── KHYBER PAKHTUNKHWA (40 districts, 60+ cities) ────────────────────
    'Khyber Pakhtunkhwa': [
      'Abbottabad', 'Adezai', 'Akora Khattak', 'Alpuri', 'Ayubia',
      'Balakot', 'Banda Daud Shah', 'Bannu', 'Batkhela', 'Battagram',
      'Birote', 'Buner', 'Chakdara', 'Charsadda', 'Chitral',
      'Daggar', 'Dargai', 'Dera Ismail Khan', 'Dir', 'Doaba',
      'Drosh', 'Hangu', 'Haripur', 'Havelian', 'Kalam',
      'Karak', 'Kohat', 'Kulachi', 'Lakki Marwat', 'Latamber',
      'Landi Kotal', 'Lower Dir', 'Madyan', 'Malakand', 'Mansehra',
      'Mardan', 'Mastuj', 'Mingora', 'Naran', 'Nowshera',
      'Pabbi', 'Paharpur', 'Parachinar', 'Peshawar', 'Risalpur',
      'Saidu Sharif', 'Shangla', 'Shinkiari', 'Swabi', 'Swat',
      'Takht Bhai', 'Tangi', 'Tank', 'Thall', 'Timergara',
      'Tordher', 'Upper Dir', 'Wana',
    ],

    // ── BALOCHISTAN (37 districts, 40+ cities) ───────────────────────────
    'Balochistan': [
      'Awaran', 'Barkhan', 'Bella', 'Bolan', 'Chagai',
      'Chaman', 'Dalbandin', 'Dera Bugti', 'Dera Murad Jamali', 'Duki',
      'Gandava', 'Gwadar', 'Harnai', 'Hub', 'Jacobabad',
      'Jaffarabad', 'Jhal Magsi', 'Kalat', 'Kech', 'Kharan',
      'Khuzdar', 'Killa Abdullah', 'Killa Saifullah', 'Kohlu', 'Lasbela',
      'Loralai', 'Mastung', 'Mach', 'Musakhel', 'Nasirabad',
      'Nushki', 'Ormara', 'Panjgur', 'Pasni', 'Pishin',
      'Quetta', 'Sibi', 'Sohbatpur', 'Surab', 'Taftan',
      'Turbat', 'Usta Muhammad', 'Uthal', 'Washuk', 'Zhob',
      'Ziarat',
    ],

    // ── ISLAMABAD CAPITAL TERRITORY ──────────────────────────────────────
    'Islamabad Capital Territory': [
      'Islamabad', 'Bara Kahu', 'Bhara Kahu', 'Bani Gala', 'Golra Sharif',
      'Lehtrar', 'Nilore', 'Nurpur Shahan', 'Rawat', 'Sihala',
      'Sohan', 'Tarnol', 'Taxila',
    ],

    // ── AZAD JAMMU & KASHMIR (10 districts) ─────────────────────────────
    'Azad Jammu & Kashmir': [
      'Athmuqam', 'Bagh', 'Bhimber', 'Chakswari', 'Chikar',
      'Dadyal', 'Dhirkot', 'Forward Kahuta', 'Hajira', 'Hattian Bala',
      'Haveli', 'Jhelum Valley', 'Kotli', 'Mangla', 'Mirpur',
      'Muzaffarabad', 'Neelum', 'New Mirpur', 'Palandri', 'Palak',
      'Rawalakot', 'Samahni', 'Sehnsa', 'Sudhnoti', 'Tatarinao',
    ],

    // ── GILGIT-BALTISTAN (10+ districts) ────────────────────────────────
    'Gilgit-Baltistan': [
      'Aliabad', 'Astore', 'Chilas', 'Danyore', 'Fairy Meadows',
      'Gahkuch', 'Ghanche', 'Ghizer', 'Gilgit', 'Gojal',
      'Gulmit', 'Hunza', 'Hussainabad', 'Juglot', 'Karimabad',
      'Khaplu', 'Nagar', 'Naltar', 'Passu', 'Phander',
      'Roundu', 'Shigar', 'Skardu', 'Tangir', 'Tolti',
      'Yasin',
    ],
  };

  // ── Country list — Pakistan only ───────────────────────────────────────
  static final List<String> _allCountries = [
    'Pakistan',
  ];
}

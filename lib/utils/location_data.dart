/// ─────────────────────────────────────────────────────────────────────────────
/// LocationData — Country and state/province data for address dropdowns
/// ─────────────────────────────────────────────────────────────────────────────
/// Used in signup screens for manual location entry.
/// Contains a comprehensive list of countries and their states/provinces.
/// ─────────────────────────────────────────────────────────────────────────────
library;

class LocationData {
  /// Full list of countries with their states/provinces
  /// Key: country name, Value: list of states/provinces
  static const Map<String, List<String>> countryStates = {
    'Pakistan': [
      'Azad Kashmir', 'Balochistan', 'Gilgit-Baltistan',
      'Islamabad Capital Territory', 'Khyber Pakhtunkhwa',
      'Punjab', 'Sindh',
    ],
    'India': [
      'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar',
      'Chhattisgarh', 'Delhi', 'Goa', 'Gujarat', 'Haryana',
      'Himachal Pradesh', 'Jharkhand', 'Karnataka', 'Kerala',
      'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya',
      'Mizoram', 'Nagaland', 'Odisha', 'Punjab', 'Rajasthan',
      'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura',
      'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
    ],
    'Bangladesh': [
      'Barishal', 'Chattogram', 'Dhaka', 'Khulna',
      'Mymensingh', 'Rajshahi', 'Rangpur', 'Sylhet',
    ],
    'United States': [
      'Alabama', 'Alaska', 'Arizona', 'Arkansas', 'California',
      'Colorado', 'Connecticut', 'Delaware', 'Florida', 'Georgia',
      'Hawaii', 'Idaho', 'Illinois', 'Indiana', 'Iowa', 'Kansas',
      'Kentucky', 'Louisiana', 'Maine', 'Maryland', 'Massachusetts',
      'Michigan', 'Minnesota', 'Mississippi', 'Missouri', 'Montana',
      'Nebraska', 'Nevada', 'New Hampshire', 'New Jersey',
      'New Mexico', 'New York', 'North Carolina', 'North Dakota',
      'Ohio', 'Oklahoma', 'Oregon', 'Pennsylvania', 'Rhode Island',
      'South Carolina', 'South Dakota', 'Tennessee', 'Texas',
      'Utah', 'Vermont', 'Virginia', 'Washington',
      'West Virginia', 'Wisconsin', 'Wyoming',
    ],
    'United Kingdom': [
      'England', 'Northern Ireland', 'Scotland', 'Wales',
    ],
    'Canada': [
      'Alberta', 'British Columbia', 'Manitoba',
      'New Brunswick', 'Newfoundland and Labrador',
      'Nova Scotia', 'Ontario', 'Prince Edward Island',
      'Quebec', 'Saskatchewan',
    ],
    'Saudi Arabia': [
      'Al Bahah', 'Al Jawf', 'Al Madinah', 'Al Qassim',
      'Asir', 'Eastern Province', 'Ha\'il', 'Jazan',
      'Makkah', 'Najran', 'Northern Borders', 'Riyadh', 'Tabuk',
    ],
    'United Arab Emirates': [
      'Abu Dhabi', 'Ajman', 'Dubai', 'Fujairah',
      'Ras Al Khaimah', 'Sharjah', 'Umm Al Quwain',
    ],
    'Qatar': ['Ad Dawhah', 'Al Khawr', 'Al Rayyan', 'Al Wakrah', 'Umm Salal'],
    'Kuwait': ['Al Ahmadi', 'Al Asimah', 'Al Farwaniyah', 'Al Jahra', 'Hawalli', 'Mubarak Al-Kabeer'],
    'Oman': ['Ad Dakhiliyah', 'Al Batinah', 'Al Wusta', 'Ash Sharqiyah', 'Dhofar', 'Musandam', 'Muscat'],
    'Bahrain': ['Capital', 'Muharraq', 'Northern', 'Southern'],
    'Turkey': [
      'Adana', 'Ankara', 'Antalya', 'Bursa', 'Gaziantep',
      'Istanbul', 'Izmir', 'Kayseri', 'Konya', 'Mersin',
    ],
    'Malaysia': [
      'Johor', 'Kedah', 'Kelantan', 'Kuala Lumpur', 'Malacca',
      'Negeri Sembilan', 'Pahang', 'Penang', 'Perak', 'Perlis',
      'Sabah', 'Sarawak', 'Selangor', 'Terengganu',
    ],
    'Australia': [
      'Australian Capital Territory', 'New South Wales',
      'Northern Territory', 'Queensland', 'South Australia',
      'Tasmania', 'Victoria', 'Western Australia',
    ],
    'Germany': [
      'Baden-Württemberg', 'Bavaria', 'Berlin', 'Brandenburg',
      'Bremen', 'Hamburg', 'Hesse', 'Lower Saxony',
      'Mecklenburg-Vorpommern', 'North Rhine-Westphalia',
      'Rhineland-Palatinate', 'Saarland', 'Saxony',
      'Saxony-Anhalt', 'Schleswig-Holstein', 'Thuringia',
    ],
    'France': [
      'Auvergne-Rhône-Alpes', 'Bourgogne-Franche-Comté',
      'Brittany', 'Centre-Val de Loire', 'Corsica',
      'Grand Est', 'Hauts-de-France', 'Île-de-France',
      'Normandy', 'Nouvelle-Aquitaine', 'Occitanie',
      'Pays de la Loire', 'Provence-Alpes-Côte d\'Azur',
    ],
    'Iran': [
      'Alborz', 'East Azerbaijan', 'West Azerbaijan', 'Isfahan',
      'Fars', 'Gilan', 'Hormozgan', 'Kerman', 'Kermanshah',
      'Khuzestan', 'Lorestan', 'Mazandaran', 'Razavi Khorasan',
      'Tehran',
    ],
    'Afghanistan': [
      'Badakhshan', 'Balkh', 'Herat', 'Kabul', 'Kandahar',
      'Nangarhar', 'Paktia',
    ],
    'China': [
      'Beijing', 'Chongqing', 'Fujian', 'Guangdong', 'Hainan',
      'Henan', 'Hubei', 'Jiangsu', 'Shanghai', 'Sichuan',
      'Tianjin', 'Zhejiang',
    ],
    'Japan': [
      'Aichi', 'Chiba', 'Fukuoka', 'Hiroshima', 'Hokkaido',
      'Hyogo', 'Kanagawa', 'Kyoto', 'Osaka', 'Saitama',
      'Shizuoka', 'Tokyo',
    ],
    'South Korea': [
      'Busan', 'Daegu', 'Daejeon', 'Gangwon', 'Gwangju',
      'Gyeonggi', 'Incheon', 'Jeju', 'Seoul', 'Ulsan',
    ],
    'Indonesia': [
      'Bali', 'Banten', 'Central Java', 'East Java', 'Jakarta',
      'West Java', 'Yogyakarta',
    ],
    'Philippines': [
      'Cebu', 'Davao', 'Iloilo', 'Metro Manila',
      'Pampanga', 'Rizal',
    ],
    'Nigeria': [
      'Abuja', 'Anambra', 'Cross River', 'Delta', 'Edo',
      'Kaduna', 'Kano', 'Lagos', 'Ogun', 'Oyo', 'Rivers',
    ],
    'South Africa': [
      'Eastern Cape', 'Free State', 'Gauteng', 'KwaZulu-Natal',
      'Limpopo', 'Mpumalanga', 'North West', 'Northern Cape',
      'Western Cape',
    ],
    'Egypt': [
      'Alexandria', 'Aswan', 'Cairo', 'Giza', 'Luxor',
      'Port Said', 'Suez',
    ],
    'Brazil': [
      'Bahia', 'Ceará', 'Federal District', 'Goiás',
      'Minas Gerais', 'Paraná', 'Pernambuco', 'Rio de Janeiro',
      'Rio Grande do Sul', 'São Paulo', 'Santa Catarina',
    ],
    'Mexico': [
      'Chihuahua', 'Ciudad de México', 'Guadalajara', 'Jalisco',
      'Monterrey', 'Nuevo León', 'Puebla', 'Yucatán',
    ],
    'Sri Lanka': [
      'Central', 'Eastern', 'North Central', 'North Western',
      'Northern', 'Sabaragamuwa', 'Southern', 'Uva', 'Western',
    ],
    'Nepal': [
      'Bagmati', 'Gandaki', 'Karnali', 'Koshi', 'Lumbini',
      'Madhesh', 'Sudurpashchim',
    ],
  };

  /// Get sorted list of all country names
  static List<String> get countries {
    final list = countryStates.keys.toList();
    list.sort();
    return list;
  }

  /// Get states/provinces for a given country
  static List<String> getStates(String country) {
    return countryStates[country] ?? [];
  }

  /// Major cities data for common countries (used as hints/suggestions)
  static const Map<String, List<String>> majorCities = {
    'Pakistan': [
      'Karachi', 'Lahore', 'Islamabad', 'Rawalpindi', 'Faisalabad',
      'Multan', 'Peshawar', 'Quetta', 'Sialkot', 'Gujranwala',
      'Hyderabad', 'Bahawalpur', 'Sargodha', 'Sukkur', 'Abbottabad',
      'Mardan', 'Mingora', 'Rahim Yar Khan', 'Sahiwal', 'Okara',
    ],
    'India': [
      'Mumbai', 'Delhi', 'Bangalore', 'Hyderabad', 'Ahmedabad',
      'Chennai', 'Kolkata', 'Pune', 'Jaipur', 'Lucknow',
      'Surat', 'Kanpur', 'Nagpur', 'Indore', 'Thane',
    ],
    'Bangladesh': [
      'Dhaka', 'Chattogram', 'Khulna', 'Rajshahi', 'Sylhet',
      'Comilla', 'Rangpur', 'Gazipur', 'Narayanganj',
    ],
    'United States': [
      'New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix',
      'Philadelphia', 'San Antonio', 'San Diego', 'Dallas', 'San Jose',
    ],
    'United Kingdom': [
      'London', 'Birmingham', 'Manchester', 'Glasgow', 'Liverpool',
      'Bristol', 'Sheffield', 'Leeds', 'Edinburgh', 'Leicester',
    ],
    'Saudi Arabia': [
      'Riyadh', 'Jeddah', 'Mecca', 'Madinah', 'Dammam',
      'Khobar', 'Tabuk', 'Abha', 'Taif',
    ],
    'United Arab Emirates': [
      'Dubai', 'Abu Dhabi', 'Sharjah', 'Ajman', 'Al Ain',
      'Ras Al Khaimah', 'Fujairah',
    ],
  };

  /// Get suggested cities for a given country
  static List<String> getCities(String country) {
    return majorCities[country] ?? [];
  }
}

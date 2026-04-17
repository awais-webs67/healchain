class AppConstants {
  // ─── App Info ──────────────────────────────────────────
  static const String appName = 'Heal Chain';
  static const String appTagline = 'AI Powered Blood Donation System';
  static const String appVersion = '1.0.0';

  // ─── Blood Groups ─────────────────────────────────────
  static const List<String> bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'O+',
    'O-',
    'AB+',
    'AB-',
  ];

  // Compatible blood groups for receiving
  static const Map<String, List<String>> compatibleDonors = {
    'A+': ['A+', 'A-', 'O+', 'O-'],
    'A-': ['A-', 'O-'],
    'B+': ['B+', 'B-', 'O+', 'O-'],
    'B-': ['B-', 'O-'],
    'O+': ['O+', 'O-'],
    'O-': ['O-'],
    'AB+': ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'],
    'AB-': ['A-', 'B-', 'O-', 'AB-'],
  };

  // ─── Radius Options (in km) ────────────────────────────
  static const List<int> radiusOptions = [5, 10, 20, 30, 50, 100];

  // ─── Urgency Levels ────────────────────────────────────
  static const List<String> urgencyLevels = ['Critical', 'Urgent', 'Normal'];

  // ─── User Roles ────────────────────────────────────────
  static const String roleDonor = 'donor';
  static const String roleRecipient = 'recipient';
  static const String roleAdmin = 'admin';

  // ─── BMI Thresholds ────────────────────────────────────
  static const double minBmiForDonation = 18.5;
  static const double maxBmiForDonation = 40.0;

  // ─── Hemoglobin Thresholds (g/dL) ─────────────────────
  static const double minHemoglobinMale = 13.0;
  static const double minHemoglobinFemale = 12.5;

  // ─── Age Thresholds ────────────────────────────────────
  static const int minDonorAge = 17;
  static const int maxDonorAge = 65;

  // ─── Firestore Collections ────────────────────────────
  static const String usersCollection = 'users';
  static const String bloodRequestsCollection = 'blood_requests';
  static const String chatHistoryCollection = 'chat_history';
  static const String motivationalCollection = 'motivational_messages';
  static const String adminSettingsCollection = 'admin_settings';
  static const String notificationsCollection = 'notifications';

  // ─── Firestore Documents ───────────────────────────────
  static const String adminConfigDoc = 'config';
  static const String apiKeysDoc = 'api_keys';

  // ─── Notification Channels ─────────────────────────────
  static const String emergencyChannelId = 'emergency_blood_request';
  static const String emergencyChannelName = 'Emergency Blood Requests';
  static const String motivationalChannelId = 'daily_motivation';
  static const String motivationalChannelName = 'Daily Motivation';
  static const String generalChannelId = 'general';
  static const String generalChannelName = 'General Notifications';

  // ─── AI ────────────────────────────────────────────────
  static const int motivationalBatchSize = 7; // Generate 7 messages per week
  static const String geminiModel = 'gemini-2.5-flash';

  // ─── Assets Paths ──────────────────────────────────────
  static const String lottiePath = 'assets/lottie/';
  static const String imagesPath = 'assets/images/';
  static const String iconsPath = 'assets/icons/';

  // ─── Shared Preferences Keys ──────────────────────────
  static const String prefDarkMode = 'dark_mode';
  static const String prefNotifications = 'notifications_enabled';
  static const String prefOnboardingDone = 'onboarding_done';
  static const String prefUserRole = 'user_role';
}

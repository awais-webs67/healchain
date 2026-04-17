/// ─────────────────────────────────────────────────────────────────────────────
/// AppRoutes — Central routing configuration using GoRouter
/// ─────────────────────────────────────────────────────────────────────────────
/// Defines all navigation paths and manages role-based routing.
/// After login, users are redirected based on their Firestore role:
///   donor → DonorHomeScreen
///   recipient → RecipientHomeScreen
///   admin → AdminDashboardScreen
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/role_selection_screen.dart';
import '../screens/auth/donor_signup_screen.dart';
import '../screens/auth/recipient_signup_screen.dart';
import '../screens/home/home_shell.dart';
import '../screens/home/donor_home_screen.dart';
import '../screens/home/recipient_home_screen.dart';
import '../screens/chatbot/chatbot_screen.dart';
import '../screens/request/create_request_screen.dart';
import '../screens/request/request_list_screen.dart';
import '../screens/home/donor_search_screen.dart';
import '../screens/home/blood_requests_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/notifications/notification_center_screen.dart';
import '../screens/admin/admin_shell.dart';
import '../screens/request/request_detail_screen.dart';
import '../screens/donation/donation_form_screen.dart';
import '../screens/chat/donor_chat_screen.dart';
import '../screens/chat/conversation_screen.dart';
import '../screens/info/about_screen.dart';
import '../screens/info/privacy_policy_screen.dart';
import '../screens/donation/donation_history_screen.dart';
import '../services/notification_service.dart';

class AppRoutes {
  // ── Route path constants ────────────────────────────────────────────────
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String roleSelection = '/role-selection';
  static const String donorSignup = '/donor-signup';
  static const String recipientSignup = '/recipient-signup';
  static const String home = '/home';
  static const String chatbot = '/chatbot';
  static const String createRequest = '/create-request';
  static const String requestList = '/request-list';
  static const String donorSearch = '/donor-search';
  static const String bloodRequests = '/blood-requests';
  static const String requestDetail = '/request-detail';
  static const String donationForm = '/donation-form';
  static const String donorChat = '/donor-chat';
  static const String conversation = '/conversation';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String notifications = '/notifications';
  static const String adminDashboard = '/admin';
  static const String about = '/about';
  static const String privacyPolicy = '/privacy-policy';
  static const String donationHistory = '/donation-history';

  // ── Router factory (cached — MUST not recreate on every build) ─────────
  static GoRouter? _cachedRouter;

  static GoRouter router(BuildContext context) {
    if (_cachedRouter != null) return _cachedRouter!;

    final authProvider = context.read<AuthProvider>();

    _cachedRouter = GoRouter(
      navigatorKey: NotificationService.navigatorKey,
      initialLocation: splash,
      debugLogDiagnostics: false,
      routes: [
        // ── Splash screen (auto-login check) ──────────────────────
        GoRoute(
          path: splash,
          builder: (context, state) => const SplashScreen(),
        ),

        // ── Onboarding (first-time users) ─────────────────────────
        GoRoute(
          path: onboarding,
          builder: (context, state) => const OnboardingScreen(),
        ),

        // ── Login / Sign Up screen ────────────────────────────────
        GoRoute(
          path: login,
          builder: (context, state) => const LoginScreen(),
        ),

        // ── Role Selection (donor / recipient) ────────────────────
        GoRoute(
          path: roleSelection,
          builder: (context, state) => const RoleSelectionScreen(),
        ),

        // ── Donor Signup (5-step flow) ────────────────────────────
        GoRoute(
          path: donorSignup,
          builder: (context, state) => const DonorSignupScreen(),
        ),

        // ── Recipient Signup (4-step flow) ────────────────────────
        // Accepts ?type=individual|hospital|welfare_org|other
        GoRoute(
          path: recipientSignup,
          builder: (context, state) {
            // Read the recipient type from query parameter
            final type = state.uri.queryParameters['type'] ?? 'individual';
            return RecipientSignupScreen(recipientType: type);
          },
        ),

        // ── Main app shell (bottom navigation) ───────────────────
        ShellRoute(
          builder: (context, state, child) => HomeShell(child: child),
          routes: [
            // Home screen — role-based content
            GoRoute(
              path: home,
              builder: (context, state) {
                final role = authProvider.userModel?.role ?? 'recipient';
                if (role == 'donor') {
                  return const DonorHomeScreen();
                }
                return const RecipientHomeScreen();
              },
            ),
            // Donor search with filters
            GoRoute(
              path: donorSearch,
              builder: (context, state) => const DonorSearchScreen(),
            ),
            // Blood requests feed (donor tab 2)
            GoRoute(
              path: bloodRequests,
              builder: (context, state) => const BloodRequestsScreen(),
            ),
            // Donor chat list (donor tab 3)
            GoRoute(
              path: donorChat,
              builder: (context, state) => const DonorChatScreen(),
            ),
            // Notification center
            GoRoute(
              path: notifications,
              builder: (context, state) =>
                  const NotificationCenterScreen(),
            ),
            // User profile
            GoRoute(
              path: profile,
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),

        // ── Standalone screens (no bottom nav) ───────────────────
        GoRoute(
          path: chatbot,
          builder: (context, state) => const ChatbotScreen(),
        ),
        GoRoute(
          path: createRequest,
          builder: (context, state) => const CreateRequestScreen(),
        ),
        GoRoute(
          path: requestList,
          builder: (context, state) => const RequestListScreen(),
        ),
        GoRoute(
          path: settings,
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: adminDashboard,
          builder: (context, state) => const AdminShell(),
        ),
        // Request detail screen
        GoRoute(
          path: requestDetail,
          builder: (context, state) {
            final id = state.uri.queryParameters['id'] ?? '';
            return RequestDetailScreen(requestId: id);
          },
        ),
        // Donation form
        GoRoute(
          path: donationForm,
          builder: (context, state) => const DonationFormScreen(),
        ),
        // Donation history (completed donations)
        GoRoute(
          path: donationHistory,
          builder: (context, state) => const DonationHistoryScreen(),
        ),
        // Conversation screen (real-time chat)
        GoRoute(
          path: about,
          builder: (context, state) => const AboutScreen(),
        ),
        GoRoute(
          path: privacyPolicy,
          builder: (context, state) => const PrivacyPolicyScreen(),
        ),
        GoRoute(
          path: conversation,
          builder: (context, state) {
            final id = state.uri.queryParameters['id'] ?? '';
            return ConversationScreen(chatId: id);
          },
        ),
      ],
    );
    return _cachedRouter!;
  }
}

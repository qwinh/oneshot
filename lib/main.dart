import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:oneshot/services/auth_service.dart';
import 'package:oneshot/screens/auth/login_screen.dart';
import 'package:oneshot/screens/composer/edit_prime_screen.dart';
import 'package:oneshot/screens/discovery/discovery_screen.dart';
import 'package:oneshot/screens/search/search_screen.dart';
import 'package:oneshot/screens/feeds/subscribe_feed_screen.dart';
import 'package:oneshot/screens/feeds/read_later_screen.dart';
import 'package:oneshot/screens/feeds/viewed_authors_screen.dart';
import 'package:oneshot/screens/feeds/liked_authors_screen.dart';
import 'package:oneshot/screens/profile/profile_screen.dart';
import 'package:oneshot/theme/app_theme.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    webProvider: ReCaptchaV3Provider('your-recaptcha-v3-site-key'),
  );

  runApp(const OneShotApp());
}

class OneShotApp extends StatelessWidget {
  const OneShotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OneShot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: kTextPrimary,
        scaffoldBackgroundColor: kBg,
        appBarTheme: kAppBarTheme,
        colorScheme: const ColorScheme.dark(
          primary: kAccent,
          secondary: kAccent,
          surface: kSurface,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kSurface,
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: kAccent),
          ),
          labelStyle: const TextStyle(color: kTextSecondary),
          hintStyle: const TextStyle(color: kTextSecondary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kTextPrimary,
            foregroundColor: kBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: kTextPrimary,
            side: const BorderSide(color: kBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const AuthGateRouter(),
    );
  }
}

/// Dynamic Router checking user authentication and verification state transitions in real time
class AuthGateRouter extends StatelessWidget {
  const AuthGateRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        final User? user = snapshot.data;

        if (user == null) {
          return const LoginScreen();
        }

        // Email Verification Gate (REQ-FUNC-001)
        if (!user.emailVerified) {
          return const EmailVerificationGateScreen();
        }

        // Fully Authorized Core View
        return const MockAuthenticatedHomeScreen();
      },
    );
  }
}

/// The verification holding zone interface preventing content consumption or publishing (REQ-FUNC-001)
class EmailVerificationGateScreen extends StatefulWidget {
  const EmailVerificationGateScreen({super.key});

  @override
  State<EmailVerificationGateScreen> createState() =>
      _EmailVerificationGateScreenState();
}

class _EmailVerificationGateScreenState
    extends State<EmailVerificationGateScreen> {
  final AuthService _authService = AuthService();
  bool _isChecking = false;

  Future<void> _checkVerification() async {
    setState(() {
      _isChecking = true;
    });

    final User? updatedUser = await _authService.refreshUserStatus();

    setState(() {
      _isChecking = false;
    });

    if (updatedUser != null && updatedUser.emailVerified) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account successfully verified!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Email verification is still pending. Please check your inbox.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _resendVerification() async {
    try {
      await _authService.sendVerificationEmail();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email resent!'),
            backgroundColor: Colors.blueAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String userEmail = _authService.currentUser?.email ?? 'your email';

    return Scaffold(
      backgroundColor: Colors.grey[950],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.mark_email_unread_outlined,
                size: 80,
                color: Colors.orangeAccent,
              ),
              const SizedBox(height: 24),
              const Text(
                'Verify Your Account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'A verification link has been sent to:\n$userEmail\n\nPlease verify your email to unlock content publishing and discovery browsing.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 36),

              // Re-check Status button
              ElevatedButton.icon(
                onPressed: _isChecking ? null : _checkVerification,
                icon: _isChecking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.refresh, color: Colors.black),
                label: const Text('I Have Verified My Email'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Resend email
              TextButton.icon(
                onPressed: _resendVerification,
                icon: const Icon(Icons.send_outlined, color: Colors.white70),
                label: const Text(
                  'Resend Link',
                  style: TextStyle(color: Colors.white70),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 24),

              // Sign Out option to retry with a different email address
              TextButton(
                onPressed: () => _authService.logout(),
                child: Text(
                  'Sign Out / Login with another account',
                  style: TextStyle(
                    color: Colors.redAccent.withOpacity(0.85),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Primary navigation shell once a user is authenticated and verified.
/// Ties together Discovery, Search, and the four derived feeds via bottom
/// navigation, with Edit Prime and Sign Out reachable from the app bar.
/// Without this shell the individual screens (already built) are unreachable
/// from a live demo session.
class MockAuthenticatedHomeScreen extends StatefulWidget {
  const MockAuthenticatedHomeScreen({super.key});

  @override
  State<MockAuthenticatedHomeScreen> createState() =>
      _MockAuthenticatedHomeScreenState();
}

class _MockAuthenticatedHomeScreenState
    extends State<MockAuthenticatedHomeScreen> {
  int _tabIndex = 0;

  static const List<Widget> _tabs = [
    DiscoveryScreen(),
    SearchScreen(),
    SubscribeFeedScreen(),
    ReadLaterScreen(),
    ViewedAuthorsScreen(),
    LikedAuthorsScreen(),
  ];

  static const List<String> _tabLabels = [
    'Discovery',
    'Search',
    'Subscribe Feed',
    'Read Later',
    'Viewed Authors',
    'Liked Authors',
  ];

  static const List<IconData> _tabIcons = [
    Icons.style_outlined,
    Icons.search,
    Icons.rss_feed,
    Icons.bookmark_outline,
    Icons.history,
    Icons.favorite_border,
  ];

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: Text(_tabLabels[_tabIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => authService.logout(),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.grey[950],
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                child: Text(
                  'ONESHOT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              for (int i = 0; i < _tabLabels.length; i++)
                ListTile(
                  leading: Icon(_tabIcons[i], color: Colors.white70),
                  title: Text(_tabLabels[i]),
                  selected: _tabIndex == i,
                  onTap: () {
                    setState(() => _tabIndex = i);
                    Navigator.of(context).pop();
                  },
                ),
              const Divider(color: Colors.white10),
              ListTile(
                leading: const Icon(Icons.person, color: Colors.white70),
                title: const Text('Profile'),
                onTap: () {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    Navigator.of(context).pop(); // Close the drawer
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(authorId: user.uid),
                      ),
                    );
                  } else {
                    // Handle error – user not logged in (shouldn't happen here)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('You must be logged in to view profile.'),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_note, color: Colors.white70),
                title: const Text('Configure Discovery Prime'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EditPrimeScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: IndexedStack(index: _tabIndex, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: [
          for (int i = 0; i < _tabLabels.length; i++)
            NavigationDestination(
              icon: Icon(_tabIcons[i]),
              label: _tabLabels[i],
            ),
        ],
      ),
    );
  }
}

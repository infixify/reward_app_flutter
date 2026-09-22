import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

const supabaseUrl = 'https://figpskarzodfeiaulmfa.supabase.co';
const supabaseKey = 'sb_publishable_OlHhzoYHI7lz84y-LSNFOg_S0s3EH0C';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  
  await Firebase.initializeApp();
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  final String? fcmToken = await messaging.getToken();
  print('FCM Token for this device: $fcmToken');

  runApp(const RewardApp());
}

class RewardApp extends StatelessWidget {
  const RewardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Rewards',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark),
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return const GoogleLoginScreen();
    }
    return const EarnScreen();
  }
}

class GoogleLoginScreen extends StatefulWidget {
  const GoogleLoginScreen({super.key});

  @override
  State<GoogleLoginScreen> createState() => _GoogleLoginScreenState();
}

class _GoogleLoginScreenState extends State<GoogleLoginScreen> {
  bool isLoading = false;
  final _supabase = Supabase.instance.client;

  Future<String?> _getDeviceHardwareId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor;
    }
    return 'unknown_device';
  }

  Future<void> _signInWithGoogle() async {
    setState(() => isLoading = true);
    try {
      final deviceId = await _getDeviceHardwareId();

      final GoogleSignIn googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize(
        serverClientId: '881444436109-k398gv3fnl238ah3s1bbom8v5bdod55t.apps.googleusercontent.com',
      );

      final googleUser = await googleSignIn.authenticate();
      if (googleUser == null) {
        setState(() => isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw 'Google Authentication Failed: Missing ID Token.';
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      final user = response.user;
      if (user == null) throw 'Login error occurred.';

      final email = user.email ?? '';

      // --- 1. Check if this device is claimed by someone else ---
      final deviceOwner = await _supabase
          .from('users')
          .select('id, email')
          .eq('device_id', deviceId!)
          .maybeSingle();

      if (deviceOwner != null && deviceOwner['id'] != user.id) {
        throw 'YOUR DEVICE IS ALREADY REGISTERED WITH ${deviceOwner['email']}. Please login with the registered gmail.';
      }

      // --- 2. Check if this Gmail is already linked to a different device ---
      final emailOwner = await _supabase
          .from('users')
          .select('id, device_id')
          .eq('email', email)
          .maybeSingle();

      if (emailOwner != null && emailOwner['device_id'] != null && emailOwner['device_id'] != deviceId) {
        throw 'This Gmail is already linked to another device!';
      }

      // --- 3. Save the device ID to the user's profile ---
      // Because your SQL trigger already inserted the row, we just UPDATE it!
      await _supabase.from('users').update({
        'email': email,
        'device_id': deviceId,
      }).eq('id', user.id);

    } catch (e) {
      // If ANY security check fails, force sign them out immediately
      await _supabase.auth.signOut();
      await GoogleSignIn.instance.signOut();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', ''), style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.indigoAccent.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sports_esports, size: 64, color: Colors.indigoAccent),
              ),
              const SizedBox(height: 24),
              const Text(
                'TaskRewards',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in with your Google account to start earning coins safely.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 48),
              isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 3,
                        ),
                        icon: const Icon(Icons.g_mobiledata, size: 32, color: Colors.blue),
                        label: const Text('Continue with Google', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        onPressed: _signInWithGoogle,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class EarnScreen extends StatefulWidget {
  const EarnScreen({super.key});

  @override
  State<EarnScreen> createState() => _EarnScreenState();
}

class _EarnScreenState extends State<EarnScreen> {
  final _supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TaskRewards Dashboard'),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              await GoogleSignIn.instance.signOut();
              await _supabase.auth.signOut();
            },
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _supabase.from('users').stream(primaryKey: ['id']).eq('id', user!.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Card(child: Padding(padding: EdgeInsets.all(24.0), child: Center(child: CircularProgressIndicator())));
              }

              final balance = snapshot.data!.first['coin_balance'] ?? 0;

              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.indigo, Colors.deepPurple]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text('Your Wallet Balance', style: TextStyle(color: Colors.white70, fontSize: 16)),
                    const SizedBox(height: 10),
                    Text('$balance Coins', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text('${user.email}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigoAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.video_library),
            label: const Text('Watch Ad (+10 Coins)', style: TextStyle(fontSize: 16)),
            onPressed: () async {
              try {
                final currentResp = await _supabase.from('users').select('coin_balance').eq('id', user.id).single();
                int currentBalance = currentResp['coin_balance'] ?? 0;
                
                await _supabase.from('users').update({
                  'coin_balance': currentBalance + 10,
                }).eq('id', user.id);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reward Added: +10 Coins!')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
          ),
        ],
      ),
    );
  }
}

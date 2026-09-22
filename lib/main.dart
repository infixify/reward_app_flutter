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
      if (idToken == null) throw 'Google Authentication Failed: Missing ID Token.';

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      final user = response.user;
      if (user == null) throw 'Login error occurred.';

      // Save or update device ID for referral anti-farming tracking without blocking login
      final deviceId = await _getDeviceHardwareId();
      await _supabase.from('users').update({
        'device_id': deviceId,
      }).eq('id', user.id);

    } catch (e) {
      await _supabase.auth.signOut();
      await GoogleSignIn.instance.signOut();
      
      String rawError = e.toString().replaceAll('Exception: ', '');
      String cleanMessage = rawError;
      
      if (rawError.contains('GoogleSignInExceptionCode.canceled') || rawError.contains('code 16')) {
        cleanMessage = 'Google Sign-In was canceled or re-auth failed. Please try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cleanMessage, style: const TextStyle(color: Colors.white)),
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
  final TextEditingController _referralController = TextEditingController();
  bool isApplyingReferral = false;

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

  Future<void> _applyReferralCode() async {
    final code = _referralController.text.trim();
    if (code.isEmpty) return;

    setState(() => isApplyingReferral = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final deviceId = await _getDeviceHardwareId();

      // Call our secure PostgreSQL RPC function
      final response = await _supabase.rpc(
        'apply_referral_code',
        params: {
          'input_code': code,
          'current_user_id': user.id,
          'current_device_id': deviceId,
        },
      );

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message']), backgroundColor: Colors.green),
        );
        _referralController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message']), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => isApplyingReferral = false);
    }
  }

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

              final userData = snapshot.data!.first;
              final balance = userData['coin_balance'] ?? 0;
              final myCode = userData['referral_code'] ?? 'Loading...';
              final hasUsedReferral = userData['referred_by'] != null;

              return Column(
                children: [
                  // Wallet Card
                  Container(
                    width: double.infinity,
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
                  ),
                  const SizedBox(height: 24),

                  // Refer & Earn Section Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.indigoAccent.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Refer & Earn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 8),
                        const Text('Share your code with friends. Earn rewards when they join and play!', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 16),
                        
                        // Display User's Referral Code
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Your Referral Code:', style: TextStyle(color: Colors.white70)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.4), borderRadius: BorderRadius.circular(8)),
                              child: Text(myCode, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          ],
                        ),
                        const Divider(height: 32, color: Colors.white24),

                        // Enter Code Section (Only if they haven't used one yet)
                        if (!hasUsedReferral) ...[
                          const Text('Have a friend’s referral code?', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _referralController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'Enter code here',
                                    hintStyle: const TextStyle(color: Colors.grey),
                                    filled: true,
                                    fillColor: const Color(0xFF0F172A),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigoAccent,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: isApplyingReferral ? null : _applyReferralCode,
                                child: isApplyingReferral 
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ] else ...[
                          const Center(
                            child: Text('✓ You have already redeemed a referral code.', style: TextStyle(color: Colors.greenAccent, fontSize: 13)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          
          // Watch Ad Button
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
                String cleanError = e.toString().replaceAll('Exception: ', '');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Could not complete reward: $cleanError', style: const TextStyle(color: Colors.white)),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

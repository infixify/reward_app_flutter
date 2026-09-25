import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'support_screen.dart';

const supabaseUrl = 'https://figpskarzodfeiaulmfa.supabase.co';
const supabaseKey = 'sb_publishable_OlHhzoYHI7lz84y-LSNFOg_S0s3EH0C';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  String? initError;

  try {
    await Firebase.initializeApp();
    await MobileAds.instance.initialize();
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  } catch (e, stack) {
    initError = "Error: $e\n\nStack: $stack";
    debugPrint(initError);
  }

  if (initError != null) {
    runApp(ErrorScreenApp(message: initError));
  } else {
    runApp(const RewardApp());
  }
}

class ErrorScreenApp extends StatelessWidget {
  final String message;
  const ErrorScreenApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              message,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
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

// ==========================================
// GOOGLE LOGIN SCREEN
// ==========================================
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
        serverClientId: '727476527324-ckdf5sn021jqp8esq3bom5luo0kmmh8m.apps.googleusercontent.com',
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

// ==========================================
// EARN SCREEN
// ==========================================
class EarnScreen extends StatefulWidget {
  const EarnScreen({super.key});

  @override
  State<EarnScreen> createState() => _EarnScreenState();
}

class _EarnScreenState extends State<EarnScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _referralController = TextEditingController();
  bool isApplyingReferral = false;
  bool _isClaimingDaily = false;
  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadRewardedAd();
    _setupPushNotifications();
  }

  Future<void> _setupPushNotifications() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Ask user for notification permission (Android 13+/iOS)
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Get the device's FCM token and save it against this user
      final token = await messaging.getToken();
      final user = _supabase.auth.currentUser;
      if (token != null && user != null) {
        await _supabase.from('users').update({
          'fcm_token': token,
        }).eq('id', user.id);
      }

      // Keep the token updated if it ever refreshes
      messaging.onTokenRefresh.listen((newToken) async {
        final currentUser = _supabase.auth.currentUser;
        if (currentUser != null) {
          await _supabase.from('users').update({
            'fcm_token': newToken,
          }).eq('id', currentUser.id);
        }
      });

      // Show a snackbar when a notification arrives while app is open
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (mounted && message.notification != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${message.notification!.title ?? ''}: ${message.notification!.body ?? ''}',
              ),
              backgroundColor: const Color(0xFF1E293B),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      });
    } catch (e) {
      debugPrint('Push notification setup error: $e');
    }
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917', // Test Ad Unit ID
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          setState(() {
            _rewardedAd = ad;
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (error) {
          setState(() => _isAdLoaded = false);
        },
      ),
    );
  }

  void _showRewardedAd() {
    if (_isAdLoaded && _rewardedAd != null) {
      _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You earned reward from Ad!'), backgroundColor: Colors.green),
        );
        _loadRewardedAd();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad is still loading. Please try again in a moment.'), backgroundColor: Colors.orange),
      );
      _loadRewardedAd();
    }
  }

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

  Future<void> _claimDailyBonus() async {
    if (_isClaimingDaily) return;
    setState(() => _isClaimingDaily = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase.rpc('claim_reward_action', params: {
        'p_user_id': user.id,
        'p_action_type': 'daily_bonus',
        'p_reward_amount': 50,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message']), 
          backgroundColor: response['success'] == true ? Colors.green : Colors.orangeAccent,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isClaimingDaily = false);
    }
  }

  Widget _buildWithdrawalSection(BuildContext context, String userId) {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController upiController = TextEditingController();

    void showWithdrawDialog() {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Request Withdrawal', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Amount (Coins)', labelStyle: TextStyle(color: Colors.grey)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: upiController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'UPI ID / Phone Number', labelStyle: TextStyle(color: Colors.grey)),
              ),
              const SizedBox(height: 12),
              const Text(
                'Withdrawal can take from 24 - 72 hours (1-3 business working days)',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
              onPressed: () async {
                final amount = int.tryParse(amountController.text.trim()) ?? 0;
                final upi = upiController.text.trim();

                if (amount <= 0 || upi.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter valid withdrawal details.'), backgroundColor: Colors.redAccent),
                  );
                  return;
                }

                try {
                  await _supabase.from('withdrawals').insert({
                    'user_id': userId,
                    'amount': amount,
                    'method': 'UPI',
                    'payout_details': upi,
                    'status': 'pending',
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Withdrawal request submitted successfully!'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.redAccent),
                  );
                }
              },
              child: const Text('Submit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.indigoAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Withdrawal History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 12)),
                onPressed: showWithdrawDialog,
                child: const Text('Withdraw', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Withdrawal can take from 24 - 72 hours (1-3 business working days)',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _supabase
                .from('withdrawals')
                .stream(primaryKey: ['id'])
                .eq('user_id', userId)
                .order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final withdrawals = snapshot.data!;
              if (withdrawals.isEmpty) {
                return const Text('No withdrawal history found.', style: TextStyle(color: Colors.grey, fontSize: 13));
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: withdrawals.length,
                itemBuilder: (context, index) {
                  final item = withdrawals[index];
                  final amount = item['amount'];
                  final status = item['status'];
                  final upi = item['payout_details'];

                  Color statusColor = Colors.orange;
                  if (status == 'approved') statusColor = Colors.green;
                  if (status == 'rejected') statusColor = Colors.redAccent;

                  return Card(
                    color: const Color(0xFF0F172A),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      title: Text('$amount Coins ($upi)', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: Text('Status: ${status.toUpperCase()}', style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.history, color: Colors.grey),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEarningGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildActionCard(
          title: "Playtime Games",
          subtitle: "Earn per minute",
          icon: Icons.sports_esports,
          color: Colors.teal,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Playtime Integration Pending')),
            );
          },
        ),
        _buildActionCard(
          title: "Offerwall",
          subtitle: "Complete tasks",
          icon: Icons.assignment_turned_in,
          color: Colors.blueAccent,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Offerwall Integration Pending')),
            );
          },
        ),
        _buildActionCard(
          title: "Surveys",
          subtitle: "High paying tasks",
          icon: Icons.poll,
          color: Colors.pinkAccent,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Survey Partners Pending')),
            );
          },
        ),
        _buildActionCard(
          title: "Watch Ads",
          subtitle: "Earn via AdMob",
          icon: Icons.play_circle_filled,
          color: Colors.green,
          onTap: _showRewardedAd,
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              radius: 26,
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TaskRewards Dashboard'),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent, color: Colors.indigoAccent),
            tooltip: 'Support',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen()));
            },
          ),
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
                return const Card(
                  color: Color(0xFF1E293B),
                  child: Padding(padding: EdgeInsets.all(24.0), child: Center(child: CircularProgressIndicator()))
                );
              }

              final userData = snapshot.data!.first;
              final balance = userData['coin_balance'] ?? 0;
              final myCode = userData['referral_code'] ?? 'Loading...';
              final hasUsedReferral = userData['referred_by'] != null;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isClaimingDaily ? null : _claimDailyBonus,
                    child: const Text('Claim Daily Bonus (50 Coins)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),

                  const SizedBox(height: 24),
                  const Text('Earn Coins', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 12),
                  
                  _buildEarningGrid(context),
                  
                  const SizedBox(height: 32),

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
          _buildWithdrawalSection(context, user!.id),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
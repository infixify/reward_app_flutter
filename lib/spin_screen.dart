import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SpinScreen extends StatefulWidget {
  const SpinScreen({super.key});
  @override
  State<SpinScreen> createState() => _SpinScreenState();
}

class _SpinScreenState extends State<SpinScreen> {
  StreamController<int> selected = StreamController<int>();
  final List<int> rewards = [10, 5, 20, 0, 50, 15, 5, 25];
  bool isSpinning = false;
  
  // Naya variable jo error fix karne ke liye add kiya gaya hai
  int _winningIndex = 0; 
  
  final supabase = Supabase.instance.client;

  Future<void> handleSpin() async {
    if (isSpinning) return;
    setState(() => isSpinning = true);
    
    // Yahan index generate karke variable mein save kar rahe hain
    _winningIndex = Random().nextInt(rewards.length);
    selected.add(_winningIndex);
  }

  Future<void> claimReward(int amount) async {
    if (amount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Better luck next time!')));
      setState(() => isSpinning = false);
      return;
    }

    final user = supabase.auth.currentUser;
    if (user != null) {
      final response = await supabase.rpc('claim_reward_action', params: {
        'p_user_id': user.id,
        'p_action_type': 'spin',
        'p_reward_amount': amount,
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(response['message']),
        backgroundColor: response['success'] == true ? Colors.green : Colors.red,
      ));
    }
    setState(() => isSpinning = false);
  }

  @override
  void dispose() {
    selected.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(title: const Text('Spin to Win'), backgroundColor: const Color(0xFF1E293B)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Spin the wheel to earn coins!', style: TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 40),
            SizedBox(
              height: 300,
              child: FortuneWheel(
                selected: selected.stream,
                items: [
                  for (var it in rewards) FortuneItem(child: Text('$it Coins', style: const TextStyle(fontWeight: FontWeight.bold))),
                ],
                onAnimationEnd: () {
                  // Yahan seedha variable use kar rahe hain (Error fixed)
                  claimReward(rewards[_winningIndex]); 
                },
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              onPressed: isSpinning ? null : handleSpin,
              child: const Text('SPIN NOW', style: TextStyle(fontSize: 18, color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}

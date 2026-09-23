import 'dart:math';
import 'package:flutter/material.dart';
import 'package:scratcher/scratcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScratchScreen extends StatefulWidget {
  const ScratchScreen({super.key});
  @override
  State<ScratchScreen> createState() => _ScratchScreenState();
}

class _ScratchScreenState extends State<ScratchScreen> {
  final scratchKey = GlobalKey<ScratcherState>();
  int rewardAmount = Random().nextInt(25) + 5; // 5 se 30 tak random coins
  bool isClaimed = false;
  final supabase = Supabase.instance.client;

  Future<void> claimReward() async {
    if (isClaimed) return;
    setState(() => isClaimed = true);

    final user = supabase.auth.currentUser;
    if (user != null) {
      final response = await supabase.rpc('claim_reward_action', params: {
        'p_user_id': user.id,
        'p_action_type': 'scratch',
        'p_reward_amount': rewardAmount,
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(response['message']),
        backgroundColor: response['success'] == true ? Colors.green : Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(title: const Text('Scratch Cards'), backgroundColor: const Color(0xFF1E293B)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Scratch to reveal your prize!', style: TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 40),
            Scratcher(
              key: scratchKey,
              brushSize: 40,
              threshold: 50, // 50% scratch hone par claim trigger hoga
              color: Colors.amber,
              onThreshold: () => claimReward(),
              child: Container(
                height: 200,
                width: 250,
                color: Colors.white,
                child: Center(
                  child: Text(
                    '+$rewardAmount Coins',
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            if (isClaimed)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
                onPressed: () {
                  setState(() {
                    rewardAmount = Random().nextInt(25) + 5;
                    isClaimed = false;
                  });
                  scratchKey.currentState?.reset(duration: const Duration(milliseconds: 500));
                },
                child: const Text('Get Next Card', style: TextStyle(color: Colors.white)),
              )
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _linksFuture;

  @override
  void initState() {
    super.initState();
    _linksFuture = _fetchLinks();
  }

  Future<List<Map<String, dynamic>>> _fetchLinks() async {
    final data = await _supabase
        .from('support_links')
        .select()
        .eq('is_active', true)
        .order('display_order', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> _refresh() async {
    setState(() {
      _linksFuture = _fetchLinks();
    });
    await _linksFuture;
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showError('Invalid link.');
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      _showError('Could not open this link.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Support'),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _linksFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 100),
                  Center(
                    child: Text(
                      'Could not load support options.\nPull down to retry.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              );
            }

            final links = snapshot.data ?? [];

            if (links.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 100),
                  Center(
                    child: Text(
                      'No support options available right now.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: links.length,
              itemBuilder: (context, index) {
                final link = links[index];
                final title = link['title'] ?? 'Support';
                final icon = link['icon'] ?? '💬';
                final url = link['url'] ?? '';

                return Card(
                  color: const Color(0xFF1E293B),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.indigoAccent.withOpacity(0.3)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Text(icon, style: const TextStyle(fontSize: 28)),
                    title: Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                    onTap: url.isEmpty ? null : () => _openLink(url),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

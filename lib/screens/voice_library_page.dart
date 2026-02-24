// Voice Library – list global voice profiles (Studio).
import 'package:flutter/material.dart';
import '../neyvo_pulse_api.dart';

class VoiceLibraryPage extends StatefulWidget {
  const VoiceLibraryPage({super.key});

  @override
  State<VoiceLibraryPage> createState() => _VoiceLibraryPageState();
}

class _VoiceLibraryPageState extends State<VoiceLibraryPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _profiles = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await NeyvoPulseApi.listVoiceProfilesLibrary();
      if (res['ok'] == true && res['profiles'] != null) {
        setState(() { _profiles = List<dynamic>.from(res['profiles'] as List); _loading = false; });
      } else {
        setState(() { _error = res['error'] as String? ?? 'Failed'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voice Library')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _profiles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.record_voice_over_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text('No voice profiles in library'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _profiles.length,
                      itemBuilder: (context, i) {
                        final p = _profiles[i] as Map<String, dynamic>;
                        final name = p['display_name'] as String? ?? p['internal_name'] as String? ?? p['id'] as String? ?? '';
                        final desc = p['description'] as String? ?? '';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(name),
                            subtitle: desc.isNotEmpty ? Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis) : null,
                          ),
                        );
                      },
                    ),
    );
  }
}

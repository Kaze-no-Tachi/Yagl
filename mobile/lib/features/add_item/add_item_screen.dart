import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models.dart';
import '../../state/providers.dart';
import '../../widgets/cover_image.dart';
import 'item_form_screen.dart';
import 'scanner_screen.dart';

/// Entry point for adding an item: scan, type a barcode, or search by name.
/// Selecting a candidate opens the confirm form; "Add manually" skips straight to it.
class AddItemScreen extends ConsumerStatefulWidget {
  const AddItemScreen({super.key});

  @override
  ConsumerState<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends ConsumerState<AddItemScreen> {
  final _input = TextEditingController();
  List<GameCandidate> _candidates = [];
  bool _busy = false;
  String? _message;
  String? _lastBarcode;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final q = _input.text.trim();
    if (q.isEmpty) return;
    _lastBarcode = null;
    await _load(() => ref.read(scanRepoProvider).search(q),
        emptyMsg: 'No matches. You can still add it manually.');
  }

  Future<void> _runBarcode(String code) async {
    _lastBarcode = code;
    await _load(() => ref.read(scanRepoProvider).scan(code),
        emptyMsg: 'No match for that barcode. Add manually or search by name.');
  }

  Future<void> _load(Future<List<GameCandidate>> Function() fn,
      {required String emptyMsg}) async {
    setState(() {
      _busy = true;
      _message = null;
      _candidates = [];
    });
    try {
      final results = await fn();
      setState(() {
        _candidates = results;
        if (results.isEmpty) _message = emptyMsg;
      });
    } catch (e) {
      setState(() => _message = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openScanner() async {
    final code = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const ScannerScreen()));
    if (code != null && code.isNotEmpty) {
      _input.text = code;
      await _runBarcode(code);
    }
  }

  Future<void> _confirm(GameCandidate? candidate) async {
    final added = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => ItemFormScreen(
        prefill: candidate,
        barcode: _lastBarcode,
        source: _lastBarcode != null ? 'scan' : 'manual',
      ),
    ));
    if (added == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add item')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _input,
                      decoration: InputDecoration(
                        labelText: 'Search by name, or enter a barcode',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _runSearch,
                        ),
                      ),
                      onSubmitted: (_) => _runSearch(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Camera scan is mobile-only; web uses manual entry.
                        if (!kIsWeb)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _openScanner,
                              icon: const Icon(Icons.qr_code_scanner),
                              label: const Text('Scan barcode'),
                            ),
                          ),
                        if (!kIsWeb) const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final code = _input.text.trim();
                              if (code.isNotEmpty) _runBarcode(code);
                            },
                            icon: const Icon(Icons.numbers),
                            label: const Text('Look up barcode'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_busy) const LinearProgressIndicator(),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(_message!),
                ),
              Expanded(
                child: ListView.separated(
                  itemCount: _candidates.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final c = _candidates[i];
                    return ListTile(
                      leading: SizedBox(
                        width: 44,
                        height: 60,
                        child: CoverImage(url: c.coverUrl),
                      ),
                      title: Text(c.title),
                      subtitle: Text([
                        if (c.platformName != null) c.platformName!,
                        if (c.releaseDate != null) c.releaseDate!.split('-').first,
                        'via ${c.source}',
                      ].join(' · ')),
                      onTap: () => _confirm(c),
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextButton.icon(
                    onPressed: () => _confirm(null),
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Add manually instead'),
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

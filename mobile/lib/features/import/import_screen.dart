import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models.dart';
import '../../state/providers.dart';

class ImportScreen extends ConsumerWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Import digital library'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Steam', icon: Icon(Icons.sports_esports)),
            Tab(text: 'CSV', icon: Icon(Icons.table_chart_outlined)),
          ]),
        ),
        body: const TabBarView(children: [_SteamTab(), _CsvTab()]),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final ImportResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Imported from ${result.provider}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Found: ${result.fetched}   •   Added: ${result.created}'
                '   •   Skipped (already in library): ${result.skippedDuplicates}'),
            if (result.unmatched.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('No metadata match for ${result.unmatched.length} '
                  '(added without cover art):',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(result.unmatched.take(20).join(', ')),
            ],
          ],
        ),
      ),
    );
  }
}

class _SteamTab extends ConsumerStatefulWidget {
  const _SteamTab();
  @override
  ConsumerState<_SteamTab> createState() => _SteamTabState();
}

class _SteamTabState extends ConsumerState<_SteamTab> {
  final _steamId = TextEditingController();
  bool _busy = false;
  String? _error;
  ImportResult? _result;

  @override
  void dispose() {
    _steamId.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    if (_steamId.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final res = await ref.read(importsRepoProvider).steam(_steamId.text.trim());
      setState(() => _result = res);
      ref.invalidate(libraryProvider);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Imports the games you own on Steam. Your Steam profile and game '
          'details must be set to public. Enter your SteamID64 or your custom '
          'profile name.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _steamId,
          decoration: const InputDecoration(
            labelText: 'SteamID64 or vanity name',
            hintText: 'e.g. 76561197960434622 or gabelogannewell',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _import,
          icon: _busy
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.download),
          label: const Text('Import from Steam'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        if (_result != null) ...[
          const SizedBox(height: 16),
          _ResultCard(result: _result!),
        ],
      ],
    );
  }
}

class _CsvTab extends ConsumerStatefulWidget {
  const _CsvTab();
  @override
  ConsumerState<_CsvTab> createState() => _CsvTabState();
}

class _CsvTabState extends ConsumerState<_CsvTab> {
  final _csv = TextEditingController();
  final _titleCol = TextEditingController(text: 'title');
  final _platformCol = TextEditingController();
  final _appIdCol = TextEditingController();
  String _source = 'csv';
  bool _busy = false;
  String? _error;
  ImportResult? _result;

  @override
  void dispose() {
    _csv.dispose();
    _titleCol.dispose();
    _platformCol.dispose();
    _appIdCol.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    if (_csv.text.trim().isEmpty || _titleCol.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final res = await ref.read(importsRepoProvider).csv(
            csvText: _csv.text,
            titleColumn: _titleCol.text.trim(),
            platformColumn: _platformCol.text.trim(),
            appIdColumn: _appIdCol.text.trim(),
            source: _source,
          );
      setState(() => _result = res);
      ref.invalidate(libraryProvider);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Paste a CSV export from any store (e.g. the Epic Games Library '
          'Exporter extension, a GOG export, or your own spreadsheet). Tell us '
          'which column holds the game title; the rest is optional.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _csv,
          minLines: 5,
          maxLines: 12,
          decoration: const InputDecoration(
            labelText: 'CSV content',
            hintText: 'Game,Store\nThe Witcher 3,GOG\nHades,Epic',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _titleCol,
          decoration: const InputDecoration(
            labelText: 'Title column name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _platformCol,
          decoration: const InputDecoration(
            labelText: 'Platform column (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _appIdCol,
          decoration: const InputDecoration(
            labelText: 'Store app-id column (optional, for dedup)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _source,
          decoration: const InputDecoration(
            labelText: 'Label these as',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'csv', child: Text('Generic (csv)')),
            DropdownMenuItem(value: 'epic', child: Text('Epic')),
            DropdownMenuItem(value: 'gog', child: Text('GOG')),
          ],
          onChanged: (v) => setState(() => _source = v ?? 'csv'),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _import,
          icon: _busy
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.upload_file),
          label: const Text('Import CSV'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        if (_result != null) ...[
          const SizedBox(height: 16),
          _ResultCard(result: _result!),
        ],
      ],
    );
  }
}

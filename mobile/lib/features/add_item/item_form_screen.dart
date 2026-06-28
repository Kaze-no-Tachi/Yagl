import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models.dart';
import '../../state/providers.dart';

const kConditions = ['sealed', 'cib', 'loose', 'digital', 'damaged'];
const kKinds = ['game', 'hardware', 'accessory'];
const kFormats = ['physical', 'digital', 'retro'];

/// Create or edit an Item. Pass [existing] to edit, or [prefill] (from a scan
/// or search candidate) plus [barcode] to create.
class ItemFormScreen extends ConsumerStatefulWidget {
  const ItemFormScreen({super.key, this.existing, this.prefill, this.barcode, this.source});

  final Item? existing;
  final GameCandidate? prefill;
  final String? barcode;
  final String? source;

  @override
  ConsumerState<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends ConsumerState<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late final TextEditingController _location;
  late final TextEditingController _price;
  late String _kind;
  late String _format;
  String? _condition;
  int? _platformId;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final p = widget.prefill;
    _title = TextEditingController(text: e?.title ?? p?.title ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _location = TextEditingController(text: e?.storageLocation ?? '');
    _price = TextEditingController(text: e?.pricePaid ?? '');
    _kind = e?.kind ?? 'game';
    _format = e?.format ?? 'physical';
    _condition = e?.condition;
    _platformId = e?.platformId ?? p?.platformId;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _location.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(itemsRepoProvider);
    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'kind': _kind,
      'format': _format,
      'condition': _condition,
      'platform_id': _platformId,
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      'storage_location': _location.text.trim().isEmpty ? null : _location.text.trim(),
      'price_paid': _price.text.trim().isEmpty ? null : _price.text.trim(),
    };
    try {
      if (widget.existing != null) {
        await repo.update(widget.existing!.id, body);
      } else {
        body.addAll({
          'source': widget.source ?? 'manual',
          'barcode': widget.barcode,
          'igdb_id': widget.prefill?.igdbId,
          'cover_url': widget.prefill?.coverUrl,
          'summary': widget.prefill?.summary,
          'release_date': widget.prefill?.releaseDate,
          'genres': widget.prefill?.genres,
        });
        await repo.create(body);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final platforms = ref.watch(platformsProvider);
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit item' : 'Add item')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.prefill?.coverUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: SizedBox(
                      height: 160,
                      child: Image.network(widget.prefill!.coverUrl!, fit: BoxFit.contain),
                    ),
                  ),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                _dropdown('Type', _kind, kKinds, (v) => setState(() => _kind = v!)),
                const SizedBox(height: 12),
                _dropdown('Format', _format, kFormats, (v) => setState(() => _format = v!)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: _condition,
                  decoration: const InputDecoration(labelText: 'Condition'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('—')),
                    ...kConditions.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                  ],
                  onChanged: (v) => setState(() => _condition = v),
                ),
                const SizedBox(height: 12),
                platforms.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (list) => DropdownButtonFormField<int?>(
                    value: _platformId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Platform'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('—')),
                      ...list.map((p) =>
                          DropdownMenuItem(value: p.id, child: Text(p.name))),
                    ],
                    onChanged: (v) => setState(() => _platformId = v),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Price paid', prefixText: '\$ '),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _location,
                  decoration: const InputDecoration(
                      labelText: 'Storage location', hintText: 'Shelf, box, room…'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: _busy
                      ? const SizedBox(
                          height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(editing ? 'Save changes' : 'Add to library'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> options,
          ValueChanged<String?> onChanged) =>
      DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(labelText: label),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
        onChanged: onChanged,
      );
}

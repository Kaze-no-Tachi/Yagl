import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../api/models.dart';
import '../../state/providers.dart';
import '../../widgets/cover_image.dart';
import '../add_item/item_form_screen.dart';

class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({super.key, required this.itemId});
  final int itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(itemProvider(itemId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
        actions: [
          itemAsync.maybeWhen(
            data: (item) => Row(children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
                      builder: (_) => ItemFormScreen(existing: item)));
                  if (saved == true) ref.invalidate(itemProvider(itemId));
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(context, ref, item),
              ),
            ]),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: itemAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (item) => _Body(item: item),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Item item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('“${item.title}” will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(itemsRepoProvider).delete(item.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cover = item.photos.isNotEmpty ? item.photos.first.url : item.coverUrl;
    return ListView(
      children: [
        Container(
          height: 220,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(
            child: AspectRatio(aspectRatio: 3 / 4, child: CoverImage(url: cover, kind: item.kind)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _tag(context, item.kind),
                _tag(context, item.format),
                if (item.condition != null) _tag(context, item.condition!),
                if (item.platform != null) _tag(context, item.platform!.name),
                _tag(context, 'source: ${item.source}'),
              ]),
              if (item.summary != null) ...[
                const SizedBox(height: 16),
                Text(item.summary!, style: Theme.of(context).textTheme.bodyMedium),
              ],
              const SizedBox(height: 16),
              if (item.releaseDate != null) _row('Released', item.releaseDate!),
              if (item.genres != null && item.genres!.isNotEmpty)
                _row('Genres', item.genres!.join(', ')),
              if (item.pricePaid != null) _row('Price paid', '\$${item.pricePaid}'),
              if (item.storageLocation != null) _row('Location', item.storageLocation!),
              if (item.acquiredDate != null) _row('Acquired', item.acquiredDate!),
              if (item.notes != null && item.notes!.isNotEmpty) _row('Notes', item.notes!),
              const Divider(height: 32),
              _PhotosSection(item: item),
              const Divider(height: 32),
              _LendingSection(item: item),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tag(BuildContext context, String label) => Chip(
        label: Text(label),
        visualDensity: VisualDensity.compact,
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ]),
      );
}

class _PhotosSection extends ConsumerStatefulWidget {
  const _PhotosSection({required this.item});
  final Item item;

  @override
  ConsumerState<_PhotosSection> createState() => _PhotosSectionState();
}

class _PhotosSectionState extends ConsumerState<_PhotosSection> {
  bool _busy = false;

  Future<void> _addPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 2000, imageQuality: 85);
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await picked.readAsBytes();
      final name = picked.name.isNotEmpty ? picked.name : 'photo.jpg';
      final contentType = _guessContentType(name, picked.mimeType);
      await ref.read(itemsRepoProvider).uploadPhoto(widget.item.id, bytes, name, contentType);
      ref.invalidate(itemProvider(widget.item.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _guessContentType(String name, String? mime) {
    if (mime != null && mime.isNotEmpty) return mime;
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.item.photos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Photos', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          if (_busy) const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          IconButton(
              icon: const Icon(Icons.photo_camera_outlined),
              onPressed: _busy ? null : () => _addPhoto(ImageSource.camera)),
          IconButton(
              icon: const Icon(Icons.photo_library_outlined),
              onPressed: _busy ? null : () => _addPhoto(ImageSource.gallery)),
        ]),
        if (photos.isEmpty)
          const Text('No photos yet.')
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: GestureDetector(
                  onLongPress: () async {
                    await ref.read(itemsRepoProvider).deletePhoto(widget.item.id, photos[i].id);
                    ref.invalidate(itemProvider(widget.item.id));
                  },
                  child: Image.network(photos[i].url, width: 90, height: 120, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
        if (photos.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Long-press a photo to delete', style: TextStyle(fontSize: 11)),
          ),
      ],
    );
  }
}

class _LendingSection extends ConsumerWidget {
  const _LendingSection({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = item.openLoan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Lending', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (open != null)
          Card(
            color: Colors.orange.withOpacity(0.15),
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text('Lent to ${open.borrowerName}'),
              subtitle: Text('Since ${open.loanedOn}'
                  '${open.dueOn != null ? ' · due ${open.dueOn}' : ''}'),
              trailing: FilledButton(
                onPressed: () async {
                  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                  await ref.read(itemsRepoProvider).returnLoan(open.id, today);
                  ref.invalidate(itemProvider(item.id));
                },
                child: const Text('Return'),
              ),
            ),
          )
        else
          OutlinedButton.icon(
            icon: const Icon(Icons.outbox),
            label: const Text('Lend this item'),
            onPressed: () => _lendDialog(context, ref),
          ),
        if (item.loans.where((l) => !l.isOpen).isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('History', style: Theme.of(context).textTheme.labelLarge),
          ...item.loans.where((l) => !l.isOpen).map((l) => ListTile(
                dense: true,
                leading: const Icon(Icons.history),
                title: Text(l.borrowerName),
                subtitle: Text('${l.loanedOn} → ${l.returnedOn}'),
              )),
        ],
      ],
    );
  }

  Future<void> _lendDialog(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Lend item'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Borrower name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Lend')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      try {
        await ref.read(itemsRepoProvider).lend(
            item.id, {'borrower_name': name.text.trim(), 'loaned_on': today});
        ref.invalidate(itemProvider(item.id));
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }
  }
}

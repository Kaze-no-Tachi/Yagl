import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models.dart';
import '../../api/repositories.dart';
import '../../state/providers.dart';
import '../../widgets/cover_image.dart';
import '../add_item/add_item_screen.dart';
import '../import/import_screen.dart';
import '../item_detail/item_detail_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final filters = ref.watch(filtersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            tooltip: 'Import digital library',
            icon: const Icon(Icons.download_outlined),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ImportScreen())),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: _FilterBar(filters: filters),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => const AddItemScreen()));
          if (added == true) ref.invalidate(libraryProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(libraryProvider),
        child: library.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorView(message: '$e', onRetry: () => ref.invalidate(libraryProvider)),
          data: (items) => items.isEmpty
              ? _EmptyView()
              : _ItemGrid(items: items, onTapItem: (it) => _open(context, ref, it)),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref, Item item) async {
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ItemDetailScreen(itemId: item.id)));
    ref.invalidate(libraryProvider);
  }
}

class _ItemGrid extends StatelessWidget {
  const _ItemGrid({required this.items, required this.onTapItem});
  final List<Item> items;
  final void Function(Item) onTapItem;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Responsive: more columns on wider (web/tablet) layouts.
      final cols = (constraints.maxWidth / 180).floor().clamp(2, 8);
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          childAspectRatio: 0.62,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _ItemCard(item: items[i], onTap: () => onTapItem(items[i])),
      );
    });
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.onTap});
  final Item item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cover = item.photos.isNotEmpty ? item.photos.first.url : item.coverUrl;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CoverImage(url: cover, kind: item.kind),
                  if (item.isOnLoan)
                    Positioned(
                      top: 6, left: 6,
                      child: _Chip(label: 'On loan', color: Colors.orange),
                    ),
                  Positioned(
                    bottom: 6, right: 6,
                    child: _Chip(label: item.format, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium),
                  Text(item.platform?.name ?? item.kind,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
        child: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.filters});
  final ItemFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void setFilters(ItemFilters f) =>
        ref.read(filtersProvider.notifier).state = f;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search title…',
              prefixIcon: Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setFilters(ItemFilters(
                q: v,
                kind: filters.kind,
                format: filters.format,
                platformId: filters.platformId,
                onLoan: filters.onLoan)),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _kindChip(ref, filters, null, 'All'),
                _kindChip(ref, filters, 'game', 'Games'),
                _kindChip(ref, filters, 'hardware', 'Hardware'),
                _kindChip(ref, filters, 'accessory', 'Accessories'),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('On loan'),
                  selected: filters.onLoan == true,
                  onSelected: (s) => setFilters(ItemFilters(
                      q: filters.q,
                      kind: filters.kind,
                      onLoan: s ? true : null)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kindChip(WidgetRef ref, ItemFilters f, String? kind, String label) {
    final selected = f.kind == kind;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => ref.read(filtersProvider.notifier).state =
            ItemFilters(q: f.q, kind: kind, onLoan: f.onLoan),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(Icons.inventory_2_outlined,
            size: 72, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(height: 16),
        Center(
          child: Text('Your library is empty',
              style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 4),
        const Center(child: Text('Tap “Add” to scan or search for a game.')),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        const Center(child: Icon(Icons.error_outline, size: 56)),
        const SizedBox(height: 12),
        Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(message))),
        Center(child: OutlinedButton(onPressed: onRetry, child: const Text('Retry'))),
      ],
    );
  }
}

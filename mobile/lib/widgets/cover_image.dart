import 'package:flutter/material.dart';

/// Shows a game cover (IGDB or user photo) with a graceful placeholder.
class CoverImage extends StatelessWidget {
  const CoverImage({super.key, this.url, this.kind = 'game', this.fit = BoxFit.cover});

  final String? url;
  final String kind;
  final BoxFit fit;

  IconData get _placeholderIcon => switch (kind) {
        'hardware' => Icons.videogame_asset_outlined,
        'accessory' => Icons.cable_outlined,
        _ => Icons.sports_esports_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(_placeholderIcon,
          size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
    if (url == null || url!.isEmpty) return placeholder;
    return Image.network(
      url!,
      fit: fit,
      errorBuilder: (_, __, ___) => placeholder,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : placeholder,
    );
  }
}

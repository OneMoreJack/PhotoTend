import 'package:flutter/material.dart';
import 'package:rephoto/domain/models/media_item.dart';

typedef MediaThumbnailBuilder =
    Widget Function(BuildContext context, MediaItem item, bool selected);

class MediaThumbnailStrip extends StatelessWidget {
  const MediaThumbnailStrip({
    super.key,
    required this.items,
    required this.currentMediaId,
    required this.onTap,
    required this.thumbnailBuilder,
  });

  final List<MediaItem> items;
  final String? currentMediaId;
  final ValueChanged<String> onTap;
  final MediaThumbnailBuilder thumbnailBuilder;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      key: const Key('media-thumbnail-strip'),
      height: 68,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 6, 36, 6),
        itemExtent: 52,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final selected = item.id == currentMediaId;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              key: Key('media-thumbnail-${item.id}'),
              onTap: () => onTap(item.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? Colors.black87 : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: thumbnailBuilder(context, item, selected),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

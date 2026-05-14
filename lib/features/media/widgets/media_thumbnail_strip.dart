import 'package:flutter/material.dart';
import 'package:rephoto/domain/models/media_item.dart';

typedef MediaThumbnailBuilder =
    Widget Function(BuildContext context, MediaItem item, bool selected);

class MediaThumbnailStrip extends StatefulWidget {
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
  State<MediaThumbnailStrip> createState() => _MediaThumbnailStripState();
}

class _MediaThumbnailStripState extends State<MediaThumbnailStrip> {
  static const double _itemExtent = 78;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollSelectedThumbnail(animate: false);
    });
  }

  @override
  void didUpdateWidget(MediaThumbnailStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentMediaId != widget.currentMediaId ||
        oldWidget.items != widget.items) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollSelectedThumbnail();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      key: const Key('media-thumbnail-strip'),
      height: 104,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 13, 44, 13),
        itemExtent: _itemExtent,
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          final item = widget.items[index];
          final selected = item.id == widget.currentMediaId;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              key: Key('media-thumbnail-${item.id}'),
              onTap: () => widget.onTap(item.id),
              child: KeyedSubtree(
                key: selected
                    ? Key('media-thumbnail-selected-${item.id}')
                    : null,
                child: AnimatedScale(
                  scale: selected ? 1.08 : 1,
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF0066D6)
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFF0066D6,
                                ).withValues(alpha: 0.28),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: selected ? Colors.white : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5.5),
                        child: widget.thumbnailBuilder(context, item, selected),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _scrollSelectedThumbnail({bool animate = true}) {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }
    final currentId = widget.currentMediaId;
    if (currentId == null) {
      return;
    }
    final index = widget.items.indexWhere((item) => item.id == currentId);
    if (index < 0) {
      return;
    }

    final position = _scrollController.position;
    final target =
        (index * _itemExtent) -
        ((position.viewportDimension - _itemExtent) / 2);
    final clampedTarget = target
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((position.pixels - clampedTarget).abs() < 0.5) {
      return;
    }
    if (!animate) {
      _scrollController.jumpTo(clampedTarget);
      return;
    }
    _scrollController.animateTo(
      clampedTarget,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }
}

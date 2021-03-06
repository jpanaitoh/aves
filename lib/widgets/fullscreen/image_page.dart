import 'package:aves/model/image_entry.dart';
import 'package:aves/model/source/collection_lens.dart';
import 'package:aves/widgets/fullscreen/image_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ijkplayer/flutter_ijkplayer.dart';
import 'package:photo_view/photo_view.dart';
import 'package:tuple/tuple.dart';

class MultiImagePage extends StatefulWidget {
  final CollectionLens collection;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onTap;
  final List<Tuple2<String, IjkMediaController>> videoControllers;
  final void Function(String uri) onViewDisposed;

  const MultiImagePage({
    this.collection,
    this.pageController,
    this.onPageChanged,
    this.onTap,
    this.videoControllers,
    this.onViewDisposed,
  });

  @override
  State<StatefulWidget> createState() => MultiImagePageState();
}

class MultiImagePageState extends State<MultiImagePage> with AutomaticKeepAliveClientMixin {
  List<ImageEntry> get entries => widget.collection.sortedEntries;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return PhotoViewGestureDetectorScope(
      axis: [Axis.horizontal, Axis.vertical],
      child: PageView.builder(
        key: Key('horizontal-pageview'),
        scrollDirection: Axis.horizontal,
        controller: widget.pageController,
        physics: PhotoViewPageViewScrollPhysics(parent: BouncingScrollPhysics()),
        onPageChanged: widget.onPageChanged,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return ClipRect(
            child: ImageView(
              key: Key('imageview'),
              entry: entry,
              heroTag: widget.collection.heroTag(entry),
              onTap: widget.onTap,
              videoControllers: widget.videoControllers,
              onDisposed: () => widget.onViewDisposed?.call(entry.uri),
            ),
          );
        },
        itemCount: entries.length,
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class SingleImagePage extends StatefulWidget {
  final ImageEntry entry;
  final VoidCallback onTap;
  final List<Tuple2<String, IjkMediaController>> videoControllers;

  const SingleImagePage({
    this.entry,
    this.onTap,
    this.videoControllers,
  });

  @override
  State<StatefulWidget> createState() => SingleImagePageState();
}

class SingleImagePageState extends State<SingleImagePage> with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);

    return PhotoViewGestureDetectorScope(
      axis: [Axis.vertical],
      child: ImageView(
        entry: widget.entry,
        onTap: widget.onTap,
        videoControllers: widget.videoControllers,
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

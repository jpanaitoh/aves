import 'dart:async';
import 'dart:collection';

import 'package:aves/model/image_entry.dart';
import 'package:aves/services/metadata_service.dart';
import 'package:aves/utils/constants.dart';
import 'package:aves/widgets/common/aves_expansion_tile.dart';
import 'package:aves/widgets/common/icons.dart';
import 'package:aves/widgets/fullscreen/info/info_page.dart';
import 'package:aves/widgets/fullscreen/info/metadata_thumbnail.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

class MetadataSectionSliver extends StatefulWidget {
  final ImageEntry entry;
  final ValueNotifier<bool> visibleNotifier;

  const MetadataSectionSliver({
    @required this.entry,
    @required this.visibleNotifier,
  });

  @override
  State<StatefulWidget> createState() => _MetadataSectionSliverState();
}

class _MetadataSectionSliverState extends State<MetadataSectionSliver> with AutomaticKeepAliveClientMixin {
  List<_MetadataDirectory> _metadata = [];
  String _loadedMetadataUri;
  final ValueNotifier<String> _expandedDirectoryNotifier = ValueNotifier(null);

  ImageEntry get entry => widget.entry;

  bool get isVisible => widget.visibleNotifier.value;

  // directory names from metadata-extractor
  static const exifThumbnailDirectory = 'Exif Thumbnail'; // from metadata-extractor
  static const xmpDirectory = 'XMP'; // from metadata-extractor
  static const videoDirectory = 'Video'; // additional generic video directory

  @override
  void initState() {
    super.initState();
    _registerWidget(widget);
    _getMetadata();
  }

  @override
  void didUpdateWidget(MetadataSectionSliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unregisterWidget(oldWidget);
    _registerWidget(widget);
    _getMetadata();
  }

  @override
  void dispose() {
    _unregisterWidget(widget);
    super.dispose();
  }

  void _registerWidget(MetadataSectionSliver widget) {
    widget.visibleNotifier.addListener(_getMetadata);
  }

  void _unregisterWidget(MetadataSectionSliver widget) {
    widget.visibleNotifier.removeListener(_getMetadata);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_metadata.isEmpty) return SliverToBoxAdapter(child: SizedBox.shrink());

    final directoriesWithoutTitle = _metadata.where((dir) => dir.name.isEmpty).toList();
    final directoriesWithTitle = _metadata.where((dir) => dir.name.isNotEmpty).toList();
    final untitledDirectoryCount = directoriesWithoutTitle.length;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) {
            return SectionRow(AIcons.info);
          }
          if (index < untitledDirectoryCount + 1) {
            final dir = directoriesWithoutTitle[index - 1];
            return InfoRowGroup(dir.tags, maxValueLength: Constants.infoGroupMaxValueLength);
          }
          final dir = directoriesWithTitle[index - 1 - untitledDirectoryCount];
          return AvesExpansionTile(
            title: dir.name,
            expandedNotifier: _expandedDirectoryNotifier,
            children: [
              if (dir.name == exifThumbnailDirectory) MetadataThumbnails(source: MetadataThumbnailSource.exif, entry: entry),
              if (dir.name == xmpDirectory) MetadataThumbnails(source: MetadataThumbnailSource.xmp, entry: entry),
              if (dir.name == videoDirectory) MetadataThumbnails(source: MetadataThumbnailSource.embedded, entry: entry),
              Container(
                alignment: Alignment.topLeft,
                padding: EdgeInsets.only(left: 8, right: 8, bottom: 8),
                child: InfoRowGroup(dir.tags, maxValueLength: Constants.infoGroupMaxValueLength),
              ),
            ],
          );
        },
        childCount: 1 + _metadata.length,
      ),
    );
  }

  Future<void> _getMetadata() async {
    if (_loadedMetadataUri == entry.uri) return;
    if (isVisible) {
      final rawMetadata = await MetadataService.getAllMetadata(entry) ?? {};
      _metadata = rawMetadata.entries.map((dirKV) {
        final directoryName = dirKV.key as String ?? '';
        final rawTags = dirKV.value as Map ?? {};
        final tags = SplayTreeMap.of(Map.fromEntries(rawTags.entries.map((tagKV) {
          final value = tagKV.value as String ?? '';
          if (value.isEmpty) return null;
          final tagName = tagKV.key as String ?? '';
          return MapEntry(tagName, value);
        }).where((kv) => kv != null)));
        return _MetadataDirectory(directoryName, tags);
      }).toList()
        ..sort((a, b) => compareAsciiUpperCase(a.name, b.name));
      _loadedMetadataUri = entry.uri;
    } else {
      _metadata = [];
      _loadedMetadataUri = null;
    }
    _expandedDirectoryNotifier.value = null;
    if (mounted) setState(() {});
  }

  @override
  bool get wantKeepAlive => true;
}

class _MetadataDirectory {
  final String name;
  final SplayTreeMap<String, String> tags;

  const _MetadataDirectory(this.name, this.tags);
}

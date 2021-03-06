import 'dart:typed_data';

import 'package:aves/model/image_entry.dart';
import 'package:aves/model/image_metadata.dart';
import 'package:aves/services/service_policy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MetadataService {
  static const platform = MethodChannel('deckers.thibault/aves/metadata');

  // return Map<Map<Key, Value>> (map of directories, each directory being a map of metadata label and value description)
  static Future<Map> getAllMetadata(ImageEntry entry) async {
    if (entry.isSvg) return null;

    try {
      final result = await platform.invokeMethod('getAllMetadata', <String, dynamic>{
        'mimeType': entry.mimeType,
        'uri': entry.uri,
        'sizeBytes': entry.sizeBytes,
      });
      return result as Map;
    } on PlatformException catch (e) {
      debugPrint('getAllMetadata failed with code=${e.code}, exception=${e.message}, details=${e.details}');
    }
    return {};
  }

  static Future<CatalogMetadata> getCatalogMetadata(ImageEntry entry, {bool background = false}) async {
    if (entry.isSvg) return null;

    Future<CatalogMetadata> call() async {
      try {
        // return map with:
        // 'mimeType': MIME type as reported by metadata extractors, not Media Store (string)
        // 'dateMillis': date taken in milliseconds since Epoch (long)
        // 'isAnimated': animated gif/webp (bool)
        // 'isFlipped': flipped according to EXIF orientation (bool)
        // 'rotationDegrees': rotation degrees according to EXIF orientation or other metadata (int)
        // 'latitude': latitude (double)
        // 'longitude': longitude (double)
        // 'xmpSubjects': ';' separated XMP subjects (string)
        // 'xmpTitleDescription': XMP title or XMP description (string)
        final result = await platform.invokeMethod('getCatalogMetadata', <String, dynamic>{
          'mimeType': entry.mimeType,
          'uri': entry.uri,
          'path': entry.path,
          'sizeBytes': entry.sizeBytes,
        }) as Map;
        result['contentId'] = entry.contentId;
        return CatalogMetadata.fromMap(result);
      } on PlatformException catch (e) {
        debugPrint('getCatalogMetadata failed with code=${e.code}, exception=${e.message}, details=${e.details}');
      }
      return null;
    }

    return background
        ? servicePolicy.call(
            call,
            priority: ServiceCallPriority.getMetadata,
          )
        : call();
  }

  static Future<OverlayMetadata> getOverlayMetadata(ImageEntry entry) async {
    if (entry.isSvg) return null;

    try {
      // return map with values for: 'aperture' (double), 'exposureTime' (description), 'focalLength' (double), 'iso' (int)
      final result = await platform.invokeMethod('getOverlayMetadata', <String, dynamic>{
        'mimeType': entry.mimeType,
        'uri': entry.uri,
        'sizeBytes': entry.sizeBytes,
      }) as Map;
      return OverlayMetadata.fromMap(result);
    } on PlatformException catch (e) {
      debugPrint('getOverlayMetadata failed with code=${e.code}, exception=${e.message}, details=${e.details}');
    }
    return null;
  }

  static Future<Map> getBitmapFactoryInfo(ImageEntry entry) async {
    try {
      // return map with all data available when decoding image bounds with `BitmapFactory`
      final result = await platform.invokeMethod('getBitmapFactoryInfo', <String, dynamic>{
        'uri': entry.uri,
      }) as Map;
      return result;
    } on PlatformException catch (e) {
      debugPrint('getBitmapFactoryInfo failed with code=${e.code}, exception=${e.message}, details=${e.details}');
    }
    return {};
  }

  static Future<Map> getContentResolverMetadata(ImageEntry entry) async {
    try {
      // return map with all data available from the content resolver
      final result = await platform.invokeMethod('getContentResolverMetadata', <String, dynamic>{
        'mimeType': entry.mimeType,
        'uri': entry.uri,
      }) as Map;
      return result;
    } on PlatformException catch (e) {
      debugPrint('getContentResolverMetadata failed with code=${e.code}, exception=${e.message}, details=${e.details}');
    }
    return {};
  }

  static Future<Map> getExifInterfaceMetadata(ImageEntry entry) async {
    try {
      // return map with all data available from the `ExifInterface` library
      final result = await platform.invokeMethod('getExifInterfaceMetadata', <String, dynamic>{
        'mimeType': entry.mimeType,
        'uri': entry.uri,
        'sizeBytes': entry.sizeBytes,
      }) as Map;
      return result;
    } on PlatformException catch (e) {
      debugPrint('getExifInterfaceMetadata failed with code=${e.code}, exception=${e.message}, details=${e.details}');
    }
    return {};
  }

  static Future<Map> getMediaMetadataRetrieverMetadata(ImageEntry entry) async {
    try {
      // return map with all data available from `MediaMetadataRetriever`
      final result = await platform.invokeMethod('getMediaMetadataRetrieverMetadata', <String, dynamic>{
        'uri': entry.uri,
      }) as Map;
      return result;
    } on PlatformException catch (e) {
      debugPrint('getMediaMetadataRetrieverMetadata failed with code=${e.code}, exception=${e.message}, details=${e.details}');
    }
    return {};
  }

  static Future<Map> getMetadataExtractorSummary(ImageEntry entry) async {
    try {
      // return map with the mime type and tag count for each directory found by `metadata-extractor`
      final result = await platform.invokeMethod('getMetadataExtractorSummary', <String, dynamic>{
        'mimeType': entry.mimeType,
        'uri': entry.uri,
        'sizeBytes': entry.sizeBytes,
      }) as Map;
      return result;
    } on PlatformException catch (e) {
      debugPrint('getMetadataExtractorSummary failed with code=${e.code}, exception=${e.message}, details=${e.details}');
    }
    return {};
  }

  static Future<List<Uint8List>> getEmbeddedPictures(String uri) async {
    try {
      final result = await platform.invokeMethod('getEmbeddedPictures', <String, dynamic>{
        'uri': uri,
      });
      return (result as List).cast<Uint8List>();
    } on PlatformException catch (e) {
      debugPrint('getEmbeddedPictures failed with code=${e.code}, exception=${e.message}, details=${e.details}');
    }
    return [];
  }

  static Future<List<Uint8List>> getExifThumbnails(ImageEntry entry) async {
    try {
      final result = await platform.invokeMethod('getExifThumbnails', <String, dynamic>{
        'mimeType': entry.mimeType,
        'uri': entry.uri,
        'sizeBytes': entry.sizeBytes,
      });
      return (result as List).cast<Uint8List>();
    } on PlatformException catch (e) {
      debugPrint('getExifThumbnail failed with code=${e.code}, exception=${e.message}, details=${e.details}');
    }
    return [];
  }

  static Future<List<Uint8List>> getXmpThumbnails(ImageEntry entry) async {
    try {
      final result = await platform.invokeMethod('getXmpThumbnails', <String, dynamic>{
        'mimeType': entry.mimeType,
        'uri': entry.uri,
        'sizeBytes': entry.sizeBytes,
      });
      return (result as List).cast<Uint8List>();
    } on PlatformException catch (e) {
      debugPrint('getXmpThumbnail failed with code=${e.code}, exception=${e.message}, details=${e.details}');
    }
    return [];
  }
}

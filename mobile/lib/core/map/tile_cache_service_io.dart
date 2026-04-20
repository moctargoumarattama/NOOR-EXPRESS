import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

const _tileCacheStoreName = 'noor_osm';

Future<void> initialiseTileCache() async {
  try {
    await FMTCObjectBoxBackend().initialise();
    const store = FMTCStore(_tileCacheStoreName);
    if (!await store.manage.ready) {
      await store.manage.create();
    }
  } catch (error) {
    debugPrint('[MapCache] cache init skipped: $error');
  }
}

TileProvider createNoorTileProvider() {
  try {
    return const FMTCStore(_tileCacheStoreName).getTileProvider(
      settings: FMTCTileProviderSettings(
        behavior: CacheBehavior.cacheFirst,
        cachedValidDuration: const Duration(days: 7),
      ),
    );
  } catch (error) {
    debugPrint('[MapCache] network fallback: $error');
    return NetworkTileProvider();
  }
}

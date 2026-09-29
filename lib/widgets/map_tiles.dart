import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../services/geo_config.dart';

/// The one tile layer every map in the app uses — provider set in
/// geo_config.dart. Keeps attribution (required by OpenStreetMap/CARTO
/// terms) and the user agent in one place.
List<Widget> appMapBase() => [
      TileLayer(
        urlTemplate: kTileUrl,
        subdomains: kTileSubdomains,
        userAgentPackageName: 'com.raktabandhan.app',
      ),
    ];

Widget appMapAttribution() => const SimpleAttributionWidget(source: Text(kTileAttribution));

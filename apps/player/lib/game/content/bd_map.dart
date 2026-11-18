import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

/// Administrative levels that can become jigsaw pieces.
enum MapLevel { division, district, upazila }

extension MapLevelInfo on MapLevel {
  String get label => switch (this) {
    MapLevel.division => 'Divisions',
    MapLevel.district => 'Districts',
    MapLevel.upazila => 'Upazilas',
  };
  String get singular => switch (this) {
    MapLevel.division => 'division',
    MapLevel.district => 'district',
    MapLevel.upazila => 'upazila',
  };
}

/// One region of the map: a division, district or upazila.
///
/// Coordinates are *projected* degrees: x = longitude * cos(23.7 deg) and
/// y = -latitude, so north is up and one unit is about 111 km.
class MapUnit {
  MapUnit({
    required this.id,
    required this.level,
    required this.en,
    required this.bn,
    required this.parent,
    required this.rings,
    required this.label,
  }) : bounds = _boundsOf(rings),
       area = rings.fold(0.0, (a, r) => a + _ringArea(r));

  final String id, en, bn, parent;
  final MapLevel level;

  /// Outer rings (islands are separate rings).
  final List<List<Offset>> rings;

  /// A point well inside the unit, for labels and hints.
  final Offset label;
  final Rect bounds;
  final double area;

  /// Bengali name when there is one, else English.
  String nameBn() => bn.isEmpty ? en : bn;

  static Rect _boundsOf(List<List<Offset>> rings) {
    var r = Rect.fromPoints(rings.first.first, rings.first.first);
    for (final ring in rings) {
      for (final p in ring) {
        r = Rect.fromLTRB(
          min(r.left, p.dx),
          min(r.top, p.dy),
          max(r.right, p.dx),
          max(r.bottom, p.dy),
        );
      }
    }
    return r;
  }

  static double _ringArea(List<Offset> r) {
    var s = 0.0;
    for (var i = 0; i < r.length; i++) {
      final a = r[i], b = r[(i + 1) % r.length];
      s += a.dx * b.dy - b.dx * a.dy;
    }
    return s.abs() / 2;
  }
}

/// What part of the country a puzzle covers and which units are the pieces.
class MapSelection {
  const MapSelection({this.scopeId, this.level = MapLevel.division});

  /// null = the whole country; otherwise a division (d..) or district (z..).
  final String? scopeId;
  final MapLevel level;

  static const country = MapSelection();

  bool get wholeCountry => scopeId == null;

  /// Stored form, e.g. `all/district` or `d3/upazila`.
  String get key => '${scopeId ?? 'all'}/${level.name}';

  static MapSelection? parse(String? s) {
    if (s == null) return null;
    final parts = s.split('/');
    if (parts.length != 2) return null;
    final level = MapLevel.values.where((l) => l.name == parts[1]);
    if (level.isEmpty) return null;
    return MapSelection(
      scopeId: parts[0] == 'all' ? null : parts[0],
      level: level.first,
    );
  }

  @override
  bool operator ==(Object other) => other is MapSelection && other.key == key;
  @override
  int get hashCode => key.hashCode;
}

/// Bangladesh's divisions, districts and upazilas.
///
/// Boundaries: Bangladesh Bureau of Statistics / OCHA ROAP via geoBoundaries
/// (CC BY 3.0 IGO). Bengali names and centre points: nuhil/bangladesh-geocode
/// (MIT). Built by scripts/build_bd_map.py.
class BdMap {
  BdMap({
    required this.divisions,
    required this.districts,
    required this.upazilas,
  }) {
    for (final u in [...divisions, ...districts, ...upazilas]) {
      _byId[u.id] = u;
    }
  }

  static const attribution =
      'Boundaries: Bangladesh Bureau of Statistics / OCHA ROAP via '
      'geoBoundaries (CC BY 3.0 IGO). Bengali names: '
      'nuhil/bangladesh-geocode (MIT).';

  final List<MapUnit> divisions, districts, upazilas;
  final Map<String, MapUnit> _byId = {};

  MapUnit? byId(String? id) => id == null ? null : _byId[id];

  List<MapUnit> unitsOf(MapLevel level) => switch (level) {
    MapLevel.division => divisions,
    MapLevel.district => districts,
    MapLevel.upazila => upazilas,
  };

  /// The division a unit belongs to (itself for a division).
  MapUnit divisionOf(MapUnit u) {
    var cur = u;
    while (cur.level != MapLevel.division) {
      cur = _byId[cur.parent]!;
    }
    return cur;
  }

  int divisionIndex(MapUnit u) => divisions.indexOf(divisionOf(u));

  /// Whether [u] lies inside the scope [scopeId] (null = whole country).
  bool inScope(MapUnit u, String? scopeId) {
    if (scopeId == null) return true;
    var cur = u;
    while (true) {
      if (cur.id == scopeId) return true;
      if (cur.level == MapLevel.division) return false;
      cur = _byId[cur.parent]!;
    }
  }

  /// The pieces of a puzzle.
  List<MapUnit> piecesFor(MapSelection s) => [
    for (final u in unitsOf(s.level))
      if (inScope(u, s.scopeId)) u,
  ];

  /// Levels that make sense inside a scope (always smaller than the scope).
  List<MapLevel> levelsFor(String? scopeId) {
    final scope = byId(scopeId);
    if (scope == null) return MapLevel.values;
    return MapLevel.values.where((l) => l.index > scope.level.index).toList();
  }

  /// A human title such as "Bangladesh · Districts" or "Dhaka · Upazilas".
  String titleFor(MapSelection s) {
    final scope = byId(s.scopeId);
    return '${scope?.en ?? 'Bangladesh'} · ${s.level.label}';
  }

  /// Parses the three bundled asset files.
  static BdMap fromJson({
    required String divisions,
    required String districts,
    required String upazilas,
  }) => BdMap(
    divisions: _parse(divisions, MapLevel.division),
    districts: _parse(districts, MapLevel.district),
    upazilas: _parse(upazilas, MapLevel.upazila),
  );

  static final double _cos = cos(23.7 * pi / 180);

  /// Longitude / latitude in degrees to projected coordinates.
  static Offset project(double lon, double lat) => Offset(lon * _cos, -lat);

  static List<MapUnit> _parse(String json, MapLevel level) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    return [
      for (final raw in data['units'] as List)
        () {
          final u = raw as Map<String, dynamic>;
          final rings = <List<Offset>>[];
          for (final flat in u['r'] as List) {
            final list = (flat as List).cast<int>();
            final ring = <Offset>[];
            var x = 0, y = 0;
            for (var i = 0; i < list.length; i += 2) {
              x += list[i];
              y += list[i + 1];
              ring.add(project(x / 1000, y / 1000));
            }
            rings.add(ring);
          }
          final l = (u['l'] as List).cast<int>();
          return MapUnit(
            id: u['i'] as String,
            level: level,
            en: u['n'] as String,
            bn: u['b'] as String,
            parent: u['p'] as String,
            rings: rings,
            label: project(l[0] / 1000, l[1] / 1000),
          );
        }(),
    ];
  }

  static Future<BdMap>? _cached;
  static BdMap? _instance;

  /// The map once it has been loaded (null before), so a screen can start
  /// straight away on later visits.
  static BdMap? get loadedOrNull => _instance;

  /// Loads (once) from the app's bundled assets.
  static Future<BdMap> load([AssetBundle? bundle]) =>
      _cached ??= _loadFrom(bundle ?? rootBundle);

  static Future<BdMap> _loadFrom(AssetBundle b) async {
    final r = await Future.wait([
      b.loadString('assets/maps/bd/divisions.json'),
      b.loadString('assets/maps/bd/districts.json'),
      b.loadString('assets/maps/bd/upazilas.json'),
    ]);
    return _instance = fromJson(
      divisions: r[0],
      districts: r[1],
      upazilas: r[2],
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../services/map_keys.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../widgets/ride_widgets.dart';
import '../state/ride_hailing_provider.dart';

class RideHailingScreen extends StatelessWidget {
  const RideHailingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RideHailingProvider(),
      child: const _RideHailingView(),
    );
  }
}

class _RideHailingView extends StatefulWidget {
  const _RideHailingView();

  @override
  State<_RideHailingView> createState() => _RideHailingViewState();
}

class _RideHailingViewState extends State<_RideHailingView> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointManager;
  PolylineAnnotationManager? _lineManager;
  PointAnnotation? _pickupAnnotation;
  PointAnnotation? _destAnnotation;
  PolylineAnnotation? _routeLine;

  GeoPoint? _mapCenter;

  final _searchController = TextEditingController();
  Timer? _debounce;
  List<_PlacePrediction> _predictions = [];
  bool _searching = false;
  bool _routeLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initPickup());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initPickup() async {
    final provider = context.read<RideHailingProvider>();
    final permission = await geo.Geolocator.requestPermission();
    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      return;
    }
    final position = await geo.Geolocator.getCurrentPosition(
      desiredAccuracy: geo.LocationAccuracy.high,
    );
    final pickup = GeoPoint(position.latitude, position.longitude);
    provider.setPickup(pickup);
    _flyTo(pickup, zoom: 14);
    await _updatePickupSymbol(pickup);
  }

  Future<void> _updatePickupSymbol(GeoPoint point) async {
    if (_pointManager == null) return;
    final geometry = Point(
      coordinates: Position(point.longitude, point.latitude),
    );
    if (_pickupAnnotation != null) {
      _pickupAnnotation!.geometry = geometry;
      await _pointManager!.update(_pickupAnnotation!);
      return;
    }
    _pickupAnnotation = await _pointManager!.create(
      PointAnnotationOptions(
        geometry: geometry,
        iconImage: 'marker-15',
        iconSize: 1.6,
      ),
    );
  }

  Future<void> _updateDestinationSymbol(GeoPoint point) async {
    if (_pointManager == null) return;
    final geometry = Point(
      coordinates: Position(point.longitude, point.latitude),
    );
    if (_destAnnotation != null) {
      _destAnnotation!.geometry = geometry;
      await _pointManager!.update(_destAnnotation!);
      return;
    }
    _destAnnotation = await _pointManager!.create(
      PointAnnotationOptions(
        geometry: geometry,
        iconImage: 'marker-15',
        iconSize: 1.8,
      ),
    );
  }

  Future<void> _setDestination(GeoPoint point, {String? label}) async {
    final provider = context.read<RideHailingProvider>();
    provider.setDestination(point, label: label);
    await _updateDestinationSymbol(point);
    await _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    if (_routeLoading) return;
    final provider = context.read<RideHailingProvider>();
    if (provider.pickup == null || provider.destination == null) return;
    setState(() => _routeLoading = true);

    final from = provider.pickup!;
    final to = provider.destination!;
    final url = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/driving/'
      '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
      '?geometries=geojson&overview=full&access_token=${MapKeys.mapboxAccessToken}',
    );

    try {
      final res = await http.get(url);
      if (res.statusCode >= 400) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>;
      if (routes.isEmpty) return;
      final route = routes.first as Map<String, dynamic>;
      final distance = (route['distance'] as num).toDouble();
      final duration = (route['duration'] as num).toDouble();
      provider.setRoute(distance: distance, duration: duration);

      final geometry = route['geometry'] as Map<String, dynamic>;
      final coords = geometry['coordinates'] as List<dynamic>;
      final points = coords
          .map((c) => GeoPoint(
                (c[1] as num).toDouble(),
                (c[0] as num).toDouble(),
              ))
          .toList();
      await _drawRoute(points);
    } finally {
      if (mounted) setState(() => _routeLoading = false);
    }
  }

  Future<void> _drawRoute(List<GeoPoint> points) async {
    if (_lineManager == null) return;
    if (_routeLine != null) {
      await _lineManager!.delete(_routeLine!);
    }
    final geometry = LineString(
      coordinates: points
          .map((p) => Position(p.longitude, p.latitude))
          .toList(),
    );
    _routeLine = await _lineManager!.create(
      PolylineAnnotationOptions(
        geometry: geometry,
        lineColor: 0xFF2EE59D,
        lineWidth: 5,
      ),
    );
  }

  void _flyTo(GeoPoint point, {double zoom = 13}) {
    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(point.longitude, point.latitude)),
        zoom: zoom,
      ),
      MapAnimationOptions(duration: 1000),
    );
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _predictions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      await _searchPlaces(value.trim());
    });
  }

  Future<void> _searchPlaces(String query) async {
    setState(() => _searching = true);
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
      '?input=${Uri.encodeComponent(query)}'
      '&key=${MapKeys.googlePlacesApiKey}',
    );
    try {
      final res = await http.get(url);
      if (res.statusCode >= 400) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final preds = (data['predictions'] as List<dynamic>)
          .map((p) => _PlacePrediction(
                description: p['description'] as String,
                placeId: p['place_id'] as String,
              ))
          .toList();
      setState(() => _predictions = preds);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _selectPrediction(_PlacePrediction prediction) async {
    FocusScope.of(context).unfocus();
    setState(() => _predictions = []);
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=${prediction.placeId}'
      '&fields=geometry,name,formatted_address'
      '&key=${MapKeys.googlePlacesApiKey}',
    );
    final res = await http.get(url);
    if (res.statusCode >= 400) return;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final result = data['result'] as Map<String, dynamic>?;
    if (result == null) return;
    final location = result['geometry']['location'];
    final lat = (location['lat'] as num).toDouble();
    final lng = (location['lng'] as num).toDouble();
    final label = (result['formatted_address'] as String?) ??
        (result['name'] as String?) ??
        prediction.description;

    await _setDestination(GeoPoint(lat, lng), label: label);
    _flyTo(GeoPoint(lat, lng), zoom: 14);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RideHailingProvider>();
    final canConfirm =
        provider.destination != null && provider.selectedIndex >= 0;
    final price = provider.selectedPrice();

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MapWidget(
              cameraOptions: CameraOptions(
                center: Point(coordinates: Position(10.1815, 36.8065)),
                zoom: 12,
              ),
              onMapCreated: (mapboxMap) async {
                _mapboxMap = mapboxMap;
                _pointManager =
                    await mapboxMap.annotations.createPointAnnotationManager();
                _lineManager =
                    await mapboxMap.annotations.createPolylineAnnotationManager();
                mapboxMap.location.updateSettings(
                  LocationComponentSettings(enabled: true, pulsingEnabled: true),
                );
                await _initPickup();
              },
              onCameraChangeListener: (event) {
                final center = event.cameraState.center;
                _mapCenter = GeoPoint(
                  center.coordinates.lat.toDouble(),
                  center.coordinates.lng.toDouble(),
                );
              },
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Icon(
                  Icons.place,
                  size: 40,
                  color: AppColors.accent,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 54,
            left: 16,
            right: 16,
            child: Column(
              children: [
                _SearchBar(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  searching: _searching,
                ),
                if (_predictions.isNotEmpty)
                  _SearchResults(
                    predictions: _predictions,
                    onSelect: _selectPrediction,
                  ),
              ],
            ),
          ),
          Positioned(
            top: 124,
            right: 16,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _mapCenter == null ? 0 : 1,
              child: FloatingActionButton.extended(
                heroTag: 'set-destination',
                onPressed: _mapCenter == null
                    ? null
                    : () => _setDestination(
                          _mapCenter!,
                          label: 'Dropped pin',
                        ),
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                label: const Text('Set destination'),
                icon: const Icon(Icons.my_location),
              ),
            ),
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _TripSheet(routeLoading: _routeLoading),
            ),
          ),
          Positioned(
            bottom: 14,
            left: 16,
            right: 16,
            child: SafeArea(
              top: false,
              child: ElevatedButton(
                onPressed: canConfirm ? () {} : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: AppColors.stroke,
                  disabledForegroundColor: AppColors.textMuted,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    canConfirm
                        ? 'Confirm Ride – TND ${price!.toStringAsFixed(2)}'
                        : 'Select destination & ride',
                    key: ValueKey(canConfirm ? 'on' : 'off'),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.searching,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    return FrostedPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: const InputDecoration(
                hintText: 'Search destination',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (searching)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.predictions, required this.onSelect});

  final List<_PlacePrediction> predictions;
  final ValueChanged<_PlacePrediction> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        children: predictions
            .map(
              (p) => ListTile(
                title: Text(
                  p.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                onTap: () => onSelect(p),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TripSheet extends StatelessWidget {
  const _TripSheet({required this.routeLoading});

  final bool routeLoading;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RideHailingProvider>();
    return DraggableScrollableSheet(
      initialChildSize: 0.28,
      minChildSize: 0.22,
      maxChildSize: 0.62,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.stroke,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.my_location, color: AppColors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pickup: Current location',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (routeLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.flag, color: AppColors.accentSoft),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      provider.destinationLabel ?? 'Destination not set',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatChip(label: 'Distance', value: provider.distanceLabel()),
                  const SizedBox(width: 8),
                  _StatChip(label: 'ETA', value: provider.durationLabel()),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Choose your ride',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              ...List.generate(provider.options.length, (index) {
                final option = provider.options[index];
                final selected = provider.selectedIndex == index;
                final price = provider.priceFor(option);
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        selected ? AppColors.surfaceElevated : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? AppColors.accent
                          : AppColors.stroke.withOpacity(0.8),
                      width: selected ? 1.4 : 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => provider.selectOption(index),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(option.icon, color: AppColors.accent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${option.subtitle} · ${option.seats} seats · ${option.etaMinutes} min',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'TND ${price.toStringAsFixed(2)}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _PlacePrediction {
  _PlacePrediction({required this.description, required this.placeId});

  final String description;
  final String placeId;
}

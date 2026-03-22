import 'package:flutter/material.dart';

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

class RideOption {
  RideOption({
    required this.name,
    required this.subtitle,
    required this.seats,
    required this.etaMinutes,
    required this.baseFare,
    required this.perKm,
    required this.perMin,
    required this.icon,
  });

  final String name;
  final String subtitle;
  final int seats;
  final int etaMinutes;
  final double baseFare;
  final double perKm;
  final double perMin;
  final IconData icon;
}

class RideHailingProvider extends ChangeNotifier {
  GeoPoint? pickup;
  GeoPoint? destination;
  String? destinationLabel;
  double? distanceMeters;
  double? durationSeconds;
  int selectedIndex = -1;

  final List<RideOption> options = [
    RideOption(
      name: 'RideWave Go',
      subtitle: 'Quick pickup',
      seats: 4,
      etaMinutes: 3,
      baseFare: 2.5,
      perKm: 0.9,
      perMin: 0.18,
      icon: Icons.directions_car_filled,
    ),
    RideOption(
      name: 'RideWave Comfort',
      subtitle: 'Extra legroom',
      seats: 4,
      etaMinutes: 5,
      baseFare: 3.4,
      perKm: 1.2,
      perMin: 0.22,
      icon: Icons.airline_seat_recline_extra,
    ),
    RideOption(
      name: 'RideWave XL',
      subtitle: 'Bigger ride',
      seats: 6,
      etaMinutes: 7,
      baseFare: 4.8,
      perKm: 1.45,
      perMin: 0.28,
      icon: Icons.airport_shuttle,
    ),
  ];

  void setPickup(GeoPoint value) {
    pickup = value;
    notifyListeners();
  }

  void setDestination(GeoPoint value, {String? label}) {
    destination = value;
    destinationLabel = label ?? 'Dropped pin';
    notifyListeners();
  }

  void clearDestination() {
    destination = null;
    destinationLabel = null;
    distanceMeters = null;
    durationSeconds = null;
    selectedIndex = -1;
    notifyListeners();
  }

  void setRoute({required double distance, required double duration}) {
    distanceMeters = distance;
    durationSeconds = duration;
    notifyListeners();
  }

  void selectOption(int index) {
    selectedIndex = index;
    notifyListeners();
  }

  double priceFor(RideOption option) {
    final km = (distanceMeters ?? 0) / 1000;
    final minutes = (durationSeconds ?? 0) / 60;
    return option.baseFare + (option.perKm * km) + (option.perMin * minutes);
  }

  double? selectedPrice() {
    if (selectedIndex < 0 || selectedIndex >= options.length) return null;
    return priceFor(options[selectedIndex]);
  }

  String distanceLabel() {
    if (distanceMeters == null) return '--';
    final km = distanceMeters! / 1000;
    return '${km.toStringAsFixed(1)} km';
  }

  String durationLabel() {
    if (durationSeconds == null) return '--';
    final minutes = (durationSeconds! / 60).round();
    return '$minutes min';
  }
}

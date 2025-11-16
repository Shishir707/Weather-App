import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  ///---------- Network Call ---------------
  final _searchCtr = TextEditingController(text: "Dhaka");
  bool _loading = false;
  String? _error;
  String? _resolvedCity;

  double? _tempc;
  double? _wKmph;
  int? _wCode;
  String? _wText;

  double? _hi, _lo;

  List<_Hourly> _hourlies = [];
  List<_Daily> _dailies = [];

  Future<({String city, double lat, double lon})> geoLocation(
    String city,
  ) async {
    try {
      final url = Uri.parse(
        "https://geocoding-api.open-meteo.com/v1/search?name=$city&count=1&format=json",
      );

      final response = await get(url);
      print('Response: ${response.body}');
      if (response.statusCode != 200) {
        throw Exception("Geo Coding Fail. Status Code: ${response.statusCode}");
      }
      final deData = jsonDecode(response.body) as Map<String, dynamic>;
      final result = (deData['results'] as List?) ?? [];
      if (result.isEmpty) throw Exception("City Not Found");

      final m = result.first as Map<String, dynamic>;
      final lat = (m['latitude'] as num).toDouble();
      final lon = (m['longitude'] as num).toDouble();
      final name = ("${m['name']}, ${m['country']}");

      print('Lat: $lat , Lon: $lon , Name: $name');
      return (city: name, lat: lat, lon: lon);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> _fetch(String city) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final getGeoData = await geoLocation(city);

      final url = Uri.parse(
        "https://api.open-meteo.com/v1/forecast"
        "?latitude=${getGeoData.lat}&longitude=${getGeoData.lon}&"
        "daily=temperature_2m_max,temperature_2m_min,sunset,sunrise&hourly="
        "temperature_2m,weather_code,wind_speed_10m&current=temperature_2m,"
        "weather_code,wind_speed_10m&timezone=auto",
      );
      final response = await get(url);
      print("Weather Data: ${response.body}");
      if (response.statusCode != 200) {
        throw Exception("Weather Failed. Status Code: ${response.statusCode}");
      }
      final deData = jsonDecode(response.body) as Map<String, dynamic>;
      final current = deData['current'] as Map<String, dynamic>;

      /// ------- Current Data ----------
      final tempC = (current['temperature_2m'] as num).toDouble();
      final windKph = (current['wind_speed_10m'] as num).toDouble();
      final wCode = (current['weather_code'] as num).toDouble();

      ///-------Hourly Data---------
      final hourly = deData['hourly'] as Map<String, dynamic>;
      final hTimes = List<String>.from(hourly['time'] as List);
      final hTemp = List<num>.from(hourly['temperature_2m'] as List);
      final hCode = List<num>.from(hourly['weather_code'] as List);

      final outHourly = <_Hourly>[];
      for (var i = 0; i < hourly.length; i++) {
        outHourly.add(
          _Hourly(
            DateTime.parse(hTimes[i]),
            hTemp[i].toDouble(),
            (hCode[i].toInt()),
          ),
        );
      }
    } catch (e) {
      throw Exception(e.toString());
    } finally {
      setState(() {});
    }
  }

  String _codeToText(int? c) {
    if (c == null) {
      return "__";
    } else if (c == 0) {
      return "Clear Sky";
    } else if ([1, 2, 3].contains(c)) {
      return "Mostly Clear";
    } else if ([45, 48].contains(c)) {
      return "Fog";
    } else if ([51, 53, 55, 56, 57].contains(c)) {
      return "Drizzle";
    } else if ([61, 63, 65, 66, 67].contains(c)) {
      return "Rain";
    } else if ([71, 73, 75, 77].contains(c)) {
      return "Snow";
    } else if ([80, 81, 82].contains(c)) {
      return "Rain Showers";
    } else if ([85, 86].contains(c)) {
      return "Snow Showers";
    } else if (c == 95) {
      return "Thunderstorm";
    } else if (c == 96) {
      return "Hail";
    } else {
      return "Cloud";
    }
  }

  IconData _codeToIcon(int? c) {
    if (c == 0) {
      return Icons.sunny;
    } else if ([1, 2, 3].contains(c)) {
      return Icons.cloud_outlined;
    } else if ([45, 48].contains(c)) {
      return Icons.foggy;
    } else if ([51, 53, 55, 56, 57].contains(c)) {
      return Icons.grain_sharp;
    } else if ([61, 63, 65, 66, 67].contains(c)) {
      return Icons.water_drop;
    } else if ([71, 73, 75, 77].contains(c)) {
      return Icons.ac_unit;
    } else if ([80, 81, 82].contains(c)) {
      return Icons.deblur_rounded;
    } else if ([85, 86].contains(c)) {
      return Icons.snowing;
    } else if (c == 95) {
      return Icons.thunderstorm;
    } else if (c == 96) {
      return Icons.thunderstorm;
    } else {
      return Icons.cloud;
    }
  }

  @override
  void initState() {
    _fetch("Dhaka");
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 28),
            SizedBox(width: 8),
            Text(
              'Weather App',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade200,
        centerTitle: true,
      ),
    );
  }
}

class _Hourly {
  final DateTime t;
  final double temp;
  final int code;

  _Hourly(this.t, this.temp, this.code);
}

class _Daily {
  final DateTime date;
  final double tMin, tMax;

  _Daily(this.date, this.tMin, this.tMax);
}

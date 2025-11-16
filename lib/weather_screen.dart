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

  Future<void> geoLocation(String city) async {
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

    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  void initState() {
    geoLocation("Dhaka");
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Weather App',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade200,
        centerTitle: true,
      ),
    );
  }
}

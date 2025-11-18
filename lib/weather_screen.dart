import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';

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
      final wCode = (current['weather_code'] as num).toInt();

      ///-------Hourly Data---------
      final hourly = deData['hourly'] as Map<String, dynamic>;
      final hTimes = List<String>.from(hourly['time'] as List);
      final hTemp = List<num>.from(hourly['temperature_2m'] as List);
      final hCode = List<num>.from(hourly['weather_code'] as List);

      final outHourly = <_Hourly>[];
      for (var i = 0; i < hTimes.length; i++) {
        outHourly.add(
          _Hourly(
            DateTime.parse(hTimes[i]),
            hTemp[i].toDouble(),
            (hCode[i].toInt()),
          ),
        );
      }

      ///--------Daily Data ---------------
      final daily = deData['daily'] as Map<String, dynamic>;
      final dateTime = List<String>.from(daily['time'] as List);
      final hi = List<num>.from(daily['temperature_2m_max'] as List);
      final lo = List<num>.from(daily['temperature_2m_min'] as List);

      final outDaily = <_Daily>[];
      for (var i = 0; i < dateTime.length; i++) {
        outDaily.add(
          _Daily(
            DateTime.parse(dateTime[i]),
            hi[i].toDouble(),
            lo[i].toDouble(),
          ),
        );
      }

      print('Daily Data: ${outDaily.length}');
      print(outDaily.map((d) => "${d.date} | ${d.tMax}/${d.tMin}").toList());

      setState(() {
        _resolvedCity = getGeoData.city;
        _tempc = tempC;
        _wCode = wCode;
        _wText = _codeToText(wCode);
        _wKmph = windKph;
        _hourlies = outHourly;
        _dailies = outDaily;
      });
    } catch (e) {
      throw Exception(e.toString());
    } finally {
      setState(() {
        _loading = false;
      });
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
        backgroundColor: Colors.blue[300],
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetch(_searchCtr.text),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue, Colors.blueAccent.shade100, Colors.white],
            ),
          ),
          child: ListView(
            children: [
              SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      controller: _searchCtr,
                      onSubmitted: (v) => _fetch(v),
                      decoration: InputDecoration(
                        labelText: 'Enter City (e.g..Dhaka)',
                        labelStyle: TextStyle(color: Colors.white),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: _loading ? null : () => _fetch(_searchCtr.text),
                    child: Icon(Icons.search, color: Colors.black, size: 22),
                  ),
                ],
              ),
              SizedBox(height: 10),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null)
                Text(_error!, style: TextStyle(color: Colors.red)),
              SizedBox(height: 10),
              Column(
                children: [
                  Text(
                    'MY LOCATION',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    (_resolvedCity ?? 'Bangladesh'),
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              if (_tempc != null) ...[
                Center(
                  child: Text(
                    "${_tempc?.toStringAsFixed(0)} °C",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 96,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              if (_wKmph != null)
                Card(
                  elevation: 0,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "$_wText conditions expected today, with wind speeds reaching ${_wKmph} km/h.",
                    ),
                  ),
                ),
              SizedBox(height: 10),
              if (_hourlies.isNotEmpty)
                Row(
                  children: [
                    SizedBox(width: 10),
                    Icon(
                      Icons.access_time,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    Text(
                      'HOURLY FORECAST',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              if (_hourlies.isNotEmpty)
                Card(
                  color: Colors.white,
                  child: SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _hourlies.length,
                      itemBuilder: (context, index) => SizedBox(width: 12),
                      separatorBuilder: (context, index) {
                        final h = _hourlies[index];
                        final label = index == 0 ? "Now" : h.t.hour.toString();
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(label),
                            Icon(_codeToIcon(h.code)),
                            Text("${h.temp.toStringAsFixed(0)} °C"),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              SizedBox(height: 20),
              if (_dailies.isNotEmpty)
                Row(
                  children: [
                    SizedBox(width: 10),
                    Icon(
                      Icons.calendar_month,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    Text(
                      '07-DAY FORECAST',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              if (_dailies.isNotEmpty)
                Card(
                  color: Colors.lightBlue.withOpacity(0.6),
                  child: SizedBox(
                    height: 250,
                    child: ListView.separated(
                      itemCount: _dailies.length,
                      itemBuilder: (context, index) => SizedBox(height: 15),
                      separatorBuilder: (context, index) {
                        final d = _dailies[index];
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: 10,
                          children: [
                            SizedBox(width: 5),
                            Text(
                              DateFormat('EEE').format(d.date),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 5),
                            Icon(Icons.sunny, color: Colors.yellow),
                            SizedBox(width: 5),
                            Text(
                              "${d.tMax}°",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white.withOpacity(0.7),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text('=================='),
                            SizedBox(width: 5),
                            Text(
                              "${d.tMin}°",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
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

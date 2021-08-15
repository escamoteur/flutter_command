import 'package:flutter/material.dart';
import 'package:flutter_weather_demo/weather_manager.dart';

import 'homepage.dart';

void main() => runApp(MyApp());

/// In a real app you would use some locator like get_it or provider
/// to access your business objects. To keep the focus on the commands we use here
/// a global variable.
WeatherManager weatherManager = WeatherManager();

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Flutter Demo', home: HomePage());
  }
}

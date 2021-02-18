import 'package:flutter/material.dart';

import 'homepage.dart';
import 'weather_viewmodel.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  MyAppState createState() {
    return MyAppState();
  }
}

class MyAppState extends State<MyApp> {
  late WeatherViewModel viewModel;

  @override
  void initState() {
    viewModel = WeatherViewModel();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return TheViewModel(
      theModel: viewModel,
      child: MaterialApp(title: 'Flutter Demo', home: HomePage()),
    );
  }
}

// InheritedWidgets allow you to propagate values down the widgettree.
// it can then be accessed by just writing  TheViewModel.of(context)
class TheViewModel extends InheritedWidget {
  final WeatherViewModel theModel;

  const TheViewModel({Key? key, required this.theModel, required Widget child})
        :super(key: key, child: child);

  static WeatherViewModel? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TheViewModel>()?.theModel;

  @override
  bool updateShouldNotify(TheViewModel oldWidget) => theModel != oldWidget.theModel;
}

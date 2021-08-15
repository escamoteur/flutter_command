import 'package:flutter/material.dart';
import 'package:flutter_command/flutter_command.dart';
import 'package:flutter_weather_demo/main.dart';
import 'package:flutter_weather_demo/weather_manager.dart';

import 'listview.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("WeatherDemo")),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(5.0),
            child: TextField(
              autocorrect: false,
              decoration: InputDecoration(
                hintText: "Filter cities",
                hintStyle: TextStyle(color: Color.fromARGB(150, 0, 0, 0)),
              ),
              style: TextStyle(
                fontSize: 20.0,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
              onChanged: weatherManager.textChangedCommand,
            ),
          ),
          Expanded(
            // Handle events to show / hide spinner
            child: ValueListenableBuilder<
                    CommandResult<String?, List<WeatherEntry>>>(
                valueListenable: weatherManager.updateWeatherCommand.results,
                builder: (BuildContext context, result, _) {
                  return result.toWidget(
                    whileExecuting: (lastValue, _) => Center(
                      child: SizedBox(
                        width: 50.0,
                        height: 50.0,
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    onData: (data, _) => WeatherListView(data),
                    onError: (error, lastValue, paramData) => Column(
                      children: [
                        Text('An Error has occurred!'),
                        Text(result.error.toString()),
                        if (result.error != null)
                          Text('For search term: ${result.paramData}')
                      ],
                    ),
                  );
                }),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            // We use a ValueListenableBuilder to toggle the enabled state of the button
            child: Row(
              children: <Widget>[
                Expanded(
                  child: ValueListenableBuilder<bool>(
                    valueListenable:
                        weatherManager.updateWeatherCommand.canExecute,
                    builder: (BuildContext context, bool canExecute, _) {
                      // Depending on the value of canEcecute we set or clear the Handler
                      final handler = canExecute
                          ? weatherManager.updateWeatherCommand
                          : null;
                      return ElevatedButton(
                        child: Text("Update"),
                        style: ElevatedButton.styleFrom(
                            primary: Color.fromARGB(255, 33, 150, 243),
                            onPrimary: Color.fromARGB(255, 255, 255, 255)),

                        /// because of a current limitation of Dart
                        /// we have to use `?.execute` if the command is
                        /// stored in a nullable variable like in this case
                        onPressed: handler?.execute,
                      );
                    },
                  ),
                ),
                ValueListenableBuilder<bool>(
                    valueListenable: weatherManager.setExecutionStateCommand,
                    builder: (context, value, _) {
                      return Switch(
                        value: value,
                        onChanged: weatherManager.setExecutionStateCommand,
                      );
                    })
              ],
            ),
          ),
        ],
      ),
    );
  }
}

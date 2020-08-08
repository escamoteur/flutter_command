import 'package:flutter/material.dart';

import 'listview.dart';
import 'main.dart';

class HomePage extends StatelessWidget {
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
              onChanged: TheViewModel.of(context).textChangedCommand,
            ),
          ),
          Expanded(
            // Handle events to show / hide spinner
            child: ValueListenableBuilder<bool>(
              valueListenable:
                  TheViewModel.of(context).updateWeatherCommand.isExecuting,
              builder: (BuildContext context, bool isRunning, _) {
                // if true we show a buys Spinner otherwise the ListView
                if (isRunning == true) {
                  return Center(
                    child: Container(
                      width: 50.0,
                      height: 50.0,
                      child: CircularProgressIndicator(),
                    ),
                  );
                } else {
                  return WeatherListView();
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            // We use a stream builder to toggle the enabled state of the button
            child: Row(
              children: <Widget>[
                Expanded(
                  child: ValueListenableBuilder<bool>(
                    // Streambuilder rebuilds its subtree on every item the stream issues
                    valueListenable: TheViewModel.of(context)
                        .updateWeatherCommand
                        .canExecute, //We access our ViewModel through the inherited Widget
                    builder: (BuildContext context, bool canExecute, _) {
                      VoidCallback handler;
                      // Depending on teh Value we get from the stream we set or clear the Handler
                      handler = canExecute
                          ? TheViewModel.of(context).updateWeatherCommand
                          : null;
                      return RaisedButton(
                        child: Text("Update"),
                        color: Color.fromARGB(255, 33, 150, 243),
                        textColor: Color.fromARGB(255, 255, 255, 255),
                        onPressed: handler,
                      );
                    },
                  ),
                ),
                StateFullSwitch(
                  state: true,
                  onChanged: TheViewModel.of(context).setExecutionStateCommand,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// As the normal switch does not even remeber and display its current state
///  we us this one
class StateFullSwitch extends StatefulWidget {
  final bool state;
  final ValueChanged<bool> onChanged;

  StateFullSwitch({this.state, this.onChanged});

  @override
  StateFullSwitchState createState() {
    return StateFullSwitchState(state, onChanged);
  }
}

class StateFullSwitchState extends State<StateFullSwitch> {
  bool state;
  ValueChanged<bool> handler;

  StateFullSwitchState(this.state, this.handler);

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: state,
      onChanged: (b) {
        setState(() => state = b);
        handler(b);
      },
    );
  }
}

---
id: command_full_power
title: Command in Full Power Mode
sidebar_label: Command Full Power mode
---

So far the command did not do more than what you could do with BLoC, besides that you could call it like a function and didn't need a Stream. But `Command` can do more than that. It allows us to:

* Update the UI based on if the `Command` is executing 
* React on Exceptions in the wrapped functions
* Control when a `Command` can be executed

Let's explore this features by examining the included `example` app which queries an open weather service and displays a list of cities with the current weather. 

![](https://github.com/escamoteur/flutter_command/blob/master/misc/screen_shot_example.png)

The app uses a `WeatherViewModel` which contains the `Command` to update the `ListView` by making a REST call:

```dart
Command<String, List<WeatherEntry>> updateWeatherCommand;
```

The `updateWeatherCommand` expects a search term and will return a list of `WeatherEntry`.
The `Command` gets initialized in the constructor of the `WeatherViewModel`:

```dart
updateWeatherCommand = Command.createAsync<String, List<WeatherEntry>>(
    update, // Wrapped function
    [],     // Initial value
    restriction: setExecutionStateCommand, //please ignore for the moment
)   
```

`update` is the asynchronous function that queries the weather service, therefore we create an async version of `Command` using the `createAsync` constructor.

### Updating the ListView

In `listview.dart`:

```dart
class WeatherListView extends StatelessWidget {
  WeatherListView();
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<WeatherEntry>>(
      valueListenable: TheViewModel.of(context).updateWeatherCommand,
      builder: (BuildContext context, List<WeatherEntry> data, _) {
        // only if we get data
        return ListView.builder(
          itemCount: data.length,
    ....
```

### Reacting on changes of the function execution state

`Command` has a property 

```dart
ValueListenable<bool> isExecuting;
```

that has the value of `false` while the wrapped function isn't executed and `true` when it is.
So we use this in the UI in `homepage.dart` to display a progress indicator while the app waits for the result of the REST call:

```dart
child: ValueListenableBuilder<bool>(
    valueListenable:
        TheViewModel.of(context).updateWeatherCommand.isExecuting,
    builder: (BuildContext context, bool isRunning, _) {
    // if true we show a buys Spinner otherwise the ListView
    if (isRunning == true) {
        return Center(
        child: SizedBox(
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
```

> :triangular_flag_on_post: As it's not possible to update the UI while a synchronous function is being executed `Commands` that wrap a synchronous function don't support `isExecuting` and will throw an assertion if you try to access it.

### Update the UI on change of the search field

As we don't want to send a new HTTP request on every keypress in the search field we don't directly wire the `onChanged` event to the `updateWeatherCommand`. Instead we use a second `Command` to convert the `onChanged` event to a `ValueListenable` so that we can use the `debounce` and `listen` function of my extension function package `functional_listener`:

For this a synchronous `Command` is sufficient:

```dart
// in weather_viewmodel.dart:
Command<String, String> textChangedCommand;
// and in the constructor:

// Will be called on every change of the searchfield
textChangedCommand = Command.createSync((s) => s, '');

// 
// make sure we start processing only if the user make a short pause typing
textChangedCommand.debounce(Duration(milliseconds: 500)).listen(
    (filterText, _) {
    // I could omit the execute because Command is a callable
    // class  but here it makes the intention clearer
    updateWeatherCommand.execute(filterText);
    },
);
```

In the `homepage.dart`:

```dart
child: TextField(
    /// I omitted some properties from the example here
    onChanged: TheViewModel.of(context).textChangedCommand,
),
```

### Restricting command execution

Sometimes it is desirable to make the execution of a `Command` depending on some other state. For this you can pass a `ValueListenable<bool>` as `restriction` parameter, when you create a command. If you do so the command will only be executed if the value of the passed listenable is `true`.
In the example app we can restrict the execution by changing the state of a `Switch`. To handle changes of the `Switch` we use..., you guessed it, another command in the `WeatherViewModel`:

```dart
WeatherViewModel() {
    // Command expects a bool value when executed and sets it as its own value
    setExecutionStateCommand = Command.createSync<bool, bool>((b) => b, true);

    // We pass the result of switchChangedCommand as restriction to the updateWeatherCommand
    updateWeatherCommand = Command.createAsync<String, List<WeatherEntry>>(
    update, // Wrapped function
    [], // Initial value
    restriction: setExecutionStateCommand,
  );
...
```

To update the `Switch` we use again a `ValueListenableBuilder`:

```dart
ValueListenableBuilder<bool>(
    valueListenable:
        TheViewModel.of(context).setExecutionStateCommand,
    builder: (context, value, _) {
        return Switch(
        value: value,
        onChanged:
            TheViewModel.of(context).setExecutionStateCommand,
        );
    })
```

### Disabling the update button while another update is in progress

The update button should not be active while an update is running or when the
`Switch` deactivates it. We could achieve this, again by using the `isExecuting` property of `Command` but we would have to somehow combine it with the value of `setExecutionStateCommand` which is cumbersome. Luckily `Command` has another property `canExecute` which reflects a combined value of `!isExecuting && restriction`.

So we can easily solve this requirement with another....wait for it...`ValueListenableBuilder`

```dart
child: ValueListenableBuilder<bool>(
  valueListenable: TheViewModel.of(context)
      .updateWeatherCommand
      .canExecute,
  builder: (BuildContext context, bool canExecute, _) {
    // Depending on the value of canExecute we set or clear the handler
    final handler = canExecute
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
```

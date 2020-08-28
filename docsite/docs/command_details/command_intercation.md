---
id: command_interaction
title: Interact with a Command
---

## Getting all data at once

`isExecuting` and `thrownExceptions` are great properties but what if you don't want to use separate `ValueListenableBuilders` for each of them plus one for the data?
`Command` got you covered with the `results` property that is an `ValueListenable<CommandResult>` which combines all needed data and is updated several times during a `Command` execution.

```dart
/// Combined execution state of an `Command`
/// Will be updated for any state change of any of the fields
/// 1. If the command was just newly created `results.value` has the value:
///    `param data,null, null, false` (paramData,data, error, isExecuting)
/// 2. When calling execute: `param data, null, null, true`
/// 3. When execution finishes: `param data, the result, null, false`
/// If an error occurs: `param data, null, error, false`
/// `param data` is the data that you pass as parameter when calling the command
class CommandResult<TParam, TResult> {
  final TParam paramData;
  final TResult data;
  final Object error;
  final bool isExecuting;

  bool get hasData => data != null;
  bool get hasError => error != null;

  /// This is a stripped down version of the class. Please see the source
}
```

You can find a Version of the Weather app that uses this approach in `example_command_results`. There the `homepage.dart` looks like:

```dart
child: ValueListenableBuilder<
    CommandResult<String, List<WeatherEntry>>>(
  valueListenable:
      TheViewModel.of(context).updateWeatherCommand.results,
  builder: (BuildContext context, result, _) {
    if (result.isExecuting) {
      return Center(
        child: SizedBox(
          width: 50.0,
          height: 50.0,
          child: CircularProgressIndicator(),
        ),
      );
    } else if (result.hasData) {
      return WeatherListView(result.data);
    } else {
      assert(result.hasError);
      return Column(
        children: [
          Text('An Error has occurred!'),
          Text(result.error.toString()),
          if (result.error != null)
            Text('For search term: ${result.paramData}')
        ],
      );
    }
  },
),
```

Even if you use `results` the other properties are updated as before, so you can mix both approaches as you need it. For instance use `results` as above but additionally listening to `thrownExceptions` for logging.

If you want to be able to always display data (while loading or in case of an error) you can pass `includeLastResultInCommandResults=true`, the last successful result will be included as `data` unless a new result is available.

## Reacting on Functions with no results

  Even if your wrapped function doesn't return a value, you can react on the end of the function execution by registering a listener to the `Command`. The command Value will be void but your handler is ensured to be called.

## Logging

If you are not sure what's going on in your App you can register an handler function to 

```Dart
static void Function(String commandName, CommandResult result) loggingHandler;
```

It will get executed on every `Command` execution in your App. `commandName` is the optional `debugName` that you can pass when creating a command.
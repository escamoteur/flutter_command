---
id: command_builder
title: CommandBuilder Widget
sidebar_label: CommandBuilder Widget
---

A `Command` exposes a compound state of its execution timeline via the `Command.results` attribute. This attribute is useful if you decide to display different widgets for different states of the command. Using a `ValueListenableBuilder` it can be addressed in the following way.

Lets us assume your command connects to a rest api and is expected to return a list of values in an asynchronous manner.

```dart

/// Asynchronous method to fetch results
Future<List<String>> fetchResults(String query) => Future<void>.delayed(
    Duration(seconds: 2),
    () => [
          'Result1',
          'Result2',
          'Result3',
        ]);

/// Asynchronous command wrapping [fetchResults].
Command<String, List<String>> fetchCommand =
    Command.createAsync<String, List<String>>((String name) async {
  final results = await fetchResults('query');
  return results;
}, ['initial result']);
```

You can listen to this `fetchCommand` in a `ValueListenableBuilder` and build the respective widgets as shown below.
```dart
class ResultList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CommandResult<String, List<String>>>(
        valueListenable: fetchCommand.results,
        builder: (context, cmdResult, child) {
          if (cmdResult.hasError) {
            return Text('Some thing went wrong while fetching');
          }
          if (cmdResult.hasData) {
            ListView(
              children:
                  cmdResult.data.map((e) => ListTile(title: Text(e))).toList(),
            );
          }
          return Center(
            child: CircularProgressIndicator(),
          );
        });
  }
}
```

`flutter_command` includes a `CommandBuilder` widget which simplifies the process of reacting to various states of the `results` exposed in a Command. For more details on `results` check this [section](/command_details/command_attributes.md#extract-information-from-commands) of command attributes.

`CommandBuilder` widget provides properties which can connect a callback to different states of the command's execution timeline. It internally listens to the `results` attribute which is a `ValueListenable` and depending on its properties calls the provided call-backs.

* `results.isExecuting` via `whileExecuting`
* `results.hasData` via `onData`
* `results.hasError` via `onError`

The example shown above can be re-written using CommandBuilder as shown below. Comparatively a readable version.
```dart
class ResultList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CommandBuilder<String, List<String>>(
      command: fetchCommand,
      onData: (context, data, param) => ListView(
        children: data.map((e) => ListTile(title: Text(e))).toList(),
      ),
      onError: (context, error, param) => Text('Some thing went wrong while fetching'),
      whileExecuting: (context, param) => Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
```
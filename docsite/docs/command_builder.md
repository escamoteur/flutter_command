---
id: command_builder
title: CommandBuilder Widget
sidebar_label: CommandBuilder Widget
---

`flutter_command` includes a `CommandBuilder` widget which simplifies the process of reacting to various states of the `results` exposed in a Command. For more details on `results` check this [section](/command_details/command_attributes.md#extract-information-from-commands) of command attributes.

`CommandBuilder` widget provides properties which can connect a callback to different states of the command's execution timeline. It internally listens to the `results` attribute which is a `ValueListenable` and depending on its properties calls the provided call-backs.

* `results.isExecuting` via `whileExecuting`
* `results.hasData` via `onData`
* `results.hasError` via `onError`

```dart
child: CommandBuilder<String, List<WeatherEntry>>(
  command: TheViewModel.of(context).updateWeatherCommand,
  whileExecuting: (context, _) => Center(
    child: SizedBox(
      width: 50.0,
      height: 50.0,
      child: CircularProgressIndicator(),
    ),
  ),
  onData: (context, data, _) => WeatherListView(data),
  onError: (context, error, param) => Column(
    children: [
      Text('An Error has occurred!'),
      Text(error.toString()),
      if (error != null) Text('For search term: $param')
    ],
  ),
),
```
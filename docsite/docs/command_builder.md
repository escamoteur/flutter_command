---
id: command_builder
title: CommandBuilder Widget
sidebar_label: CommandBuilder Widget
---

`flutter_command` includes a `CommandBuilder` widget which makes the code above a bit nicer:

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
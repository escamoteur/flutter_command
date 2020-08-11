# flutter_command

flutter_command is a way to manage your state based on `ValueListenable` and the `Command` design pattern. Sounds scary uh? Ok lets try it a different way. A `Command` is an object that wraps a function that can be executed by calling the command, therefore decoupling your UI from the wrapped function.

It's not that easy to define what exactly state management is (see https://medium.com/super-declarative/understanding-state-management-and-why-you-never-will-dd84b624d0e). For me it's how the UI triggers processes in the model/business layer of your app and how to get back the results of these processes to display them. For both aspects `flutter_command` offers solution plus some nice extras. So in a way it offers the same that BLoC does but in a more logical way.

## Why Commands
When I started Flutter the most often recommended way to manage your state was `BLoC`. What never appealed to me was that in order to execute a process in your model layer you had to push an object into a `StreamController` which just didn't feel right. For me triggering a process should feel like calling a function.
Coming from the .Net world I was used to use Commands for this, which had an additional nice feature that the Button that triggered the command would automatically disable for the duration, the command was running and by this, preventing a double execution at the same time. I also learned to love a special breed of .Net commands called `ReactiveCommands` which emitted the result of the called function on their own Stream interface (the ReactiveUI community might oversee that I don't talk of Observables here.) As I wanted to have something similar I ported `ReactiveCommands` to Dart with my [rx_command](https://pub.dev/packages/rx_command). But somehow they did not get much attention because 1. I didn't call them state management and 2. they had to do with `Streams` and even had that scary `rx` in the name and probably the readme wasn't as good to start as I thought.

Remi Rousselet talked to me about that `ValueNotifier` and how much easier they are than using Streams. So what you have here is my second attempt to warm the hearts of the Flutter community for the `Command` metaphor absolutely free of `Streams`

## A first careful encounter

Let's start with the (in)famous counter example but by using a `Command`. As said before a `Command` wraps a function and can publish the result in a way that can be consumed by the UI. It does this by implementing the `ValueListenable` interface which means a command behaves like `ValueNotifier`. A command has the type:

```Dart
Command<TParam,TResult>
```
at which `TParam` is the type of the parameter which the wrapped function expects as argument and `TResult` is the type of the result of it, which means the `Command` behaves like a `ValueNotifier<TResult>`. In the included project `counter_example` the command is defined as:

```Dart
class _MyHomePageState extends State<MyHomePage> {
  int counter = 0;
  /// This command does not expect any parameters when called therefore TParam 
  /// is void and publishes its results as String
  Command<void, String> _incrementCounterCommand;

  _MyHomePageState() {
    _incrementCounterCommand = Command.createSyncNoParam(() {
      counter++;
      return counter.toString();
    }, '0');
  }
```

To create a `Command` the `Command` class offers different static functions depending on the signature of the wrapped function. In this case we want to use a synchronous function without any parameters.

Our widget tree now looks like this:

```Dart

  body: Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          'You have pushed the button this many times:',
        ),
        ValueListenableBuilder<String>(
            valueListenable: _incrementCounterCommand,
            builder: (context, val, _) {
              return Text(
                val,
                style: Theme.of(context).textTheme.headline4,
              );
            }),
      ],
    ),
  ),
  floatingActionButton: FloatingActionButton(
    onPressed: _incrementCounterCommand,
    tooltip: 'Increment',
    child: Icon(Icons.add),
  ), // This trailing comma makes auto-formatting nicer for build methods.
);
```

As `Command` is a [callable class](https://dart.dev/guides/language/language-tour#callable-classes), so we can pass it directly to the `onPressed` handler of the `FloatingActionButton` and it will execute the wrapped function. The result of the function will get assigned to the `Command.value` so that the `ValueListenableBuilder` updates automatically.

## Commands in full power mode
So far the command did not do more than what you could do with BLoC, besides that you could call it like a function and didn't need a Stream. But `Command` can do more than that. It allows us to:

* Update the UI based on if the `Command` is executing 
* React on Exceptions in the wrapped functions
* Control when a `Command` can be executed

Let's explore this features by examining the included `example` app which queries an open weather service and displays a list of cities with the current weather. 

<img src="https://github.com/escamoteur/flutter_command/blob/master/screen_shot_example.png" alt="Screenshot" width="200" >

The app uses a `WeatherViewModel` which contains the `Command` to update the `ListView` by making a REST call:

```Dart
Command<String, List<WeatherEntry>> updateWeatherCommand;
```
The `updateWeatherCommand` expects a search term and will return a list of `WeatherEntry`.
The `Command` gets initialized in the constructor of the `WeatherViewModel`:


```Dart
updateWeatherCommand = Command.createAsync<String, List<WeatherEntry>>(
    update, // Wrapped function
    [],     // Initial value
    canExecute: setExecutionStateCommand, //please ignore for the moment
)   
```

`update` is the asynchronous function that queries the weather service, therefore we create an async version of `Command` using the `createAsync` constructor.

### Updating the ListView
In `listview.dart`:

```Dart
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

### Reacting on changes of the function execution
`Command` has a property 

```Dart
ValueListenable<bool> isExecuting;
```
that has the value of `false` while the wrapped function isn't executed and `true` when it is.
So we use this in the UI in `homepage.dart` to display a progress indicator while the app waits for the result of the REST call:

```Dart
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
```

### Update the UI on change of the search field
As we don't want to send a new HTTP request on every keypress in the search field we don't directly wire the `onChanged` event to the `updateWeatherCommand`. Instead we use a second `Command` to convert the `onChanged` event to a `ValueListenable` so that we can use the `debounce` and `listen` function of my extension function package `functional_listener`:

For this a synchronous `Command` is sufficient:

```Dart
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
```Dart
child: TextField(
    /// I omitted some properties from the example here
    onChanged: TheViewModel.of(context).textChangedCommand,
),
```

### Restricting command execution
Sometimes it is desirable to make the execution of a `Command` depending on some other state. For this you can pass a `ValueListenable<bool>` as `canExecute` parameter, when you create a command. If you do so the command will only be executed if the value of the passed listenable is `true`.
In the example app we can restrict the execution by changing the state of a `Switch`. To handle changes of the `Switch` we use..., you guessed it, another command in the `WeatherViewModel`:

```Dart
WeatherViewModel() {
    // Command expects a bool value when executed and sets it as its own value
    setExecutionStateCommand = Command.createSync<bool, bool>((b) => b, true);

    // We pass the result of switchChangedCommand as canExecute to the updateWeatherCommand
    updateWeatherCommand = Command.createAsync<String, List<WeatherEntry>>(
    update, // Wrapped function
    [], // Initial value
    canExecute: setExecutionStateCommand,
  );
...
```
To update the `Switch` we use again a `ValueListenableBuilder`:
```Dart
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
`Switch` deactivates it. We could achieve this, again by using the `isExecuting` property of `Command` but we would have to somehow combine it with the value of `setExecutionStateCommand` which is cumbersome. Luckily `Command` has another property `canExecute` which reflects a combined value of `!isExecuting && theInputCanExecute`.

So we can easily solve this requirement with another....wait for it...`ValueListenableBuilder`

```Dart
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
### Error Handling
If the wrapped function inside a `Command` throws an `Exception` the `Command` catches it so your App won't crash.
Instead it will wrap the caught error together with the value that was passed when the command was executed in an `CommandError` object and assign it to the `Command's` `thrownExeceptions` property which is a `ValueListenable<CommandError>`.
So to react on occurring error you can register your handler with `addListener` or use my `listen` extension function from `functional_listener` as it is done in the example:

```Dart
/// in HomePage.dart
@override
void didChangeDependencies() {
  errorSubscription ??= TheViewModel.of(context)
      .updateWeatherCommand
      .thrownExceptions
      .where((x) => x != null) // filter out the error value reset
      .listen((error, _) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('An error has occured!'),
              content: Text(error.toString()),
            ));
  });
  super.didChangeDependencies();
}
```
Unfortunately its not possible to reset the value of a `ValueNotifier` without triggering its listeners. So if you have registered a listener you will get it called at every start of a `Command` execution with a value of `null` clear previous errors. If you use `functional_listener` you can do it easily by using the `where` extension.

### Error handling the fine print
You can tweak the behaviour of the error handling by passing a `catchAlway` parameter to the factory functions. If you pass `false` Exceptions will only be caught if there is a listener on `thrownExceptions` or on `results` (see next chapter). You can also change the default behaviour by changing the value of the `catchAlwaysDefault` property. During development its a good idea to set it to `false` to find any non handled exception. In production, setting it to `true` might be the better decision to prevent hard crashes.

`Command` also offers a static global Exception handler:

```Dart
static void Function(CommandError<Object>) globalExeptionHandler;
```
If you assign a handler function to it, it will be called for all Exceptions thrown by any `Command` in your app independent of the value of `catchAlways` if the `Command` has no listeners on `thrownExceptions` or on `results`. 

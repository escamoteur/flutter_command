---
id: error_handling
title: Error Handling
---
If the wrapped function inside a `Command` throws an `Exception` the `Command` catches it so your App won't crash.
Instead it will wrap the caught error together with the value that was passed when the command was executed in a `CommandError` object and assign it to the `Command's` `thrownExeceptions` property which is a `ValueListenable<CommandError>`.
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

Unfortunately its not possible to reset the value of a `ValueNotifier` without triggering its listeners. So if you have registered a listener you will get it called at every start of a `Command` execution with a value of `null` and clear all previous errors. If you use `functional_listener` you can do it easily by using the `where` extension.

### Error handling the fine print

You can tweak the behaviour of the error handling by passing a `catchAlways` parameter to the factory functions. If you pass `false` Exceptions will only be caught if there is a listener on `thrownExceptions` or on `results` (see next chapter). You can also change the default behaviour of all `Command` in your app by changing the value of the `catchAlwaysDefault` property. During development its a good idea to set it to `false` to find any non handled exception. In production, setting it to `true` might be the better decision to prevent hard crashes. Note that `catchAlwaysDefault` property will be implicitly ignored if the `catchAlways` parameter for a command is set.

`Command` also offers a static global Exception handler:

```Dart
static void Function(String commandName, CommandError<Object> error) globalExceptionHandler;
```

If you assign a handler function to it, it will be called for all Exceptions thrown by any `Command` in your app independent of the value of `catchAlways` if the `Command` has no listeners on `thrownExceptions` or on `results`.

The overall work flow of exception handling in flutter_command is depicted in the following diagram.

<!-- just to keep the image scale correctly in small screens -->

![](https://github.com/escamoteur/flutter_command/blob/master/misc/exception_handling.png)

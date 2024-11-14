[7.0.0] 14.11.2024
* add stricter static type checks. this is a breaking change because the `globalExceptionHandler` correctly has to accept `CommandError<dynamic>` instead of `CommandError<Object>`
[6.0.1] 29.09.2024
* Update to latest version of functional_listener to fix a potential bug when removing the last listener from `canExecute`
[6.0.0] 
* official new release
[6.0.0+pre2] 
* fixing asssert in CommandBuilder
[6.0.0+pre1] 
* breaking changes: Command.debugName -> Command.name, ErrorReaction.defaultHandler -> ErrorReaction.defaulErrorFilter
* unless an error filter returns none or throwException all errors will be published on the `resultsProperty` including
the result of the error filter. This alloes you  if you use the `results` property to reject on any error with a generic action like popping a page while doing
the specific handlign of the error in the local or global handler.
* if an error handler itself throws an exception, that is now also reported to the `globalExceptionHandler` 
[5.0.0+20] - 18.07.2024
* undoing the last one as it makes merging of `errors` of multiple commands impossible
[5.0.0+19] - 18.07.2024
* added TParam in the defintion of the `errors` property
[5.0.0+18] - 18.07.2024
* adding precaution to make disposing of a command from one of its own handlers more robust
[5.0.0+17] - 08.11.2023
* https://github.com/escamoteur/flutter_command/issues/20 
[5.0.0+16] - 18.9.2023
* added experimental global setting `useChainCapture` which can lead to better stacktraces in async commands functions 
[5.0.0+15] - 30.08.2023 
* improved assertion error messages
[5.0.0+14] - 15.8.2023
* made commands more robust against disposing while still running which should be totally valid 
because the user could close a page where a command is running
[5.0.0+12] - 14.8.2023
* added check in dispose if the command hasn't finished yet
[5.0.0+11] - 13.8.2023
* fixed bub in UndoableCommand and disabled the Chain.capture for now
[5.0.0+10] - 11.8.2023
* general refactoring to reduce code duplication
* improving stack traces 
* adding new `reportAllExceptions` global override
[5.0.0+9] - 02.08.2023
* `clearErrors()` will now notify its listeners with a `null` value.
[5.0.0+8] - 31.07.2023
* made sure that while undo is running `isExecuting` is true and will block any parallel call of the command
[5.0.0+7] - 29.07.2023
* added `clearErrors` method to the `Command` class which resets the `errors` property to null without notifying listeners
* fix for Exception `Bad state: Future already completed` 
[5.0.0+6] - 20.06.2023
* added two more ErrorFilter types
[5.0.0+5] - 18.06.2023
* release candidate but missing docs
[5.0.0+4] - 18.05.2023
* bug fix of a too arrow assertion
[5.0.0+2] - 21.04.2023

* bug fix in the factory functions of UndoableCommand

[5.0.0+1] - 28.03.2023

* beta version of the new UndoableCommand

[5.0.0] - 24.03.2023

* Another breaking change but one that hopefully will be appreciated by most of you. When this package was originally written you could pass a `ValueListenable<bool> canExecute` when you created a Command that could decide if a Command could be executed at runtime. As the naming was am reminiscent of the .Net version of RxUIs Command but confusing because Commands have a property named `canExecute` too I renamed it to `restriction` but didn't change the meaning of its bool values. Which meant that `restriction==false` meant that the Command couldn't be executed which absolutely isn't intuitive.
After falling myself for this illogic use of bool values I know inverted the meaning so that `restriction==true` means 
that you cannot execute the Command.

* To add to the declarative power of defining behaviour with Command, they now got an optional handler that will be called 
if a Command is restricted but one tries to execute it anyway (from the source docs):

```dart
  /// [ifRestrictedExecuteInstead] if  [restriction] is set for the command and its value is `true`
  /// this function will be called instead of the wrapped function.
  /// This is useful if you want to execute a different function when the command
  /// is restricted. For example you could show a dialog to let the user logg in
  /// if the restriction is because the user is not logged in.
  /// If you don't set this function, the command will just do nothing when it's
  /// restricted.
```

[4.0.0] - 01.03.2023

* Two breaking changes in two days :-) I know that is a lot but I encountered a problem in one of my projects, that you might encounter too if you are using flutter_command. If your UI would change depending on the state of `isExecuting` and that change was triggered from within the build function, you could get an exception telling you, that `setState` was called while a rebuild was already running. In this new version async Commands now wait a frame before notifying any listeners. I don't expect, that you will see any difference in your existing apps. If this latest change has any negative side effects, please open an issue immediately. As the philosophy of Commands is that your UI should always only react on state changes and not expect synchronous data, this shouldn't make any trouble.

[3.0.0] - 24.02.2023

* Breaking change: In the past the Command only triggered listeners when the resulting value of a Command execution changed. However in many case you
want to always update your UI even if the result hasn't changed. Therefore Commands now always notify the listeners even if the result hasn't changed.
you can change that behaviour by setting [notifyOnlyWhenValueChanges] to true when creating your Commands.

## [2.0.1] - 07.03.2021

* Fixed small nullability bug in the signature of 

```Dart
  static Command<TParam, TResult> createAsync<TParam, TResult>(
      Future<TResult> Function(TParam? x) func, TResult initialValue
```

the type of `func` has to be correctly `Future<TResult> Function(TParam x)` so now it looks like
```dart
  static Command<TParam, TResult> createAsync<TParam, TResult>(
      Future<TResult> Function(TParam x) func, TResult initialValue,
```
You could probably call this a breaking change but as it won't change the behaviour, just that you probably will have to remove some '!' from your code I won't do a major version here.

## [2.0.0] - 03.03.2021

* finished null safety migration
* thrownExceptions only notifies its listeners now when a error happens and not also when it is reset to null at the beginning of a command

## [1.0.0-nullsafety.1] - 15.02.2021

* Added `toWidget()` extension method on `CommandResult`

## [0.9.2] - 25.10.2020

* Added `executeWithFuture` to use with `RefreshIndicator`
* Added `toWidget()` method

## [0.9.1] - 24.08.2020

* Shortened package description in pubspec

## [0.9.0] - 24.08.2020

* Initial official release

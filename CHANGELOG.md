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

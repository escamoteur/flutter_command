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

---
id: value_notifier
title: ValueNotifier
sidebar_label: ValueNotifier
---
:::note
If you know what a **ValueNotifier** is and how you can listen to them, feel free to skip this section.
:::

## What is a ValueNotifier?
A `ValueNotifier` is a simple object that holds a single property named `value`. This `value` can be of any type as long as its comparable using `==`'s operator. Whenever ever this value is replaced with something that fails equality `==` condition, this class notifies all it listeners. If you are wondering it sounds similar to `ChangeNotifier` you are not wrong because `ValueNotifier` is in fact a `ChangeNotifier` check [here](https://github.com/flutter/flutter/blob/bbfbf1770cca2da7c82e887e4e4af910034800b6/packages/flutter/lib/src/foundation/change_notifier.dart#L260). Under the hood it does the `notifyListeners()` call for you.

## Listen to ValueNotifier

Just like `ChangeNotifier` we can add listeners to `ValueNotifier` using `addListener` method and remove them using `removeListener`. Following is example of defining a `ValueNotifier` and adding a listener to it.

```dart
// Define a notifier
ValueNotifier<bool> userLoggedInNotifier = ValueNotifier<bool>(false);
```

```dart
// attach a listener to it.
userLoggedInNotifier.addListener((){
  print("user is logged in: ${userLoggedInNotifier.value}");
});
```

```dart
// Somewhere in the UI / Model layer change the [userLoggedInNotifier.value]
signInUser(){
  //logic to sign in the user
  ...  
  ...
  // change the notifier value and it should print the above statement in  the listener.
  userLoggedInNotifier.value = true;
}
```

## How is ValueNotifier connected to ValueListenable

A `ValueListenable` is an interface that enforces exposing a single `value` of any type to as many listeners registered. A `ValueNotifier` implements this interface and hence exposes a single value and since `ValueNotifier` also extends the `ChangeNotifier` it brings with it the power of managing the listeners and notifying them for changes in the `value`.


## Usage in Flutter

The most likely case of using a `ValueNotifier` in fluter would be build the widget on every change of it `value`. A `ValueNotifier` can be utilized in flutter by calling the `setState()` method as long the listener in registered inside a `StatefulWidget`. Also flutter provides a widget for the very purpose of it called `ValueListenableBuilder` which calls its `builder` for every change in a `ValueListenable` ([more info](https://api.flutter.dev/flutter/widgets/ValueListenableBuilder-class.html)). Here is an example for the same using our `userLoggedInNotifier` introduced earlier.

```dart
ValueListenableBuilder<bool>(
  valueListenable: userLoggedInNotifier
  builder: (context, value, child){
    if(value){
      return  Text('User is logged in');
    }
    return Text('Dear User please LogIn');
  }
)
```

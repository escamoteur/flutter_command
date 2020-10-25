---
id: getting_started
title: Flutter Command
sidebar_label: Flutter Command
---

flutter_command is a way to manage your state based on `ValueListenable` and the `Command` design pattern. Sounds scary uh? Ok lets try it a different way. A `Command` is an object that wraps a function that can be executed by calling the command, therefore decoupling your UI from the wrapped function.

It's not that easy to define what exactly state management is (see [here](https://medium.com/super-declarative/understanding-state-management-and-why-you-never-will-dd84b624d0e)). For me it's how the UI triggers processes in the model/business layer of your app and how to get back the results of these processes to display them. For both aspects `flutter_command` offers solution plus some nice extras. So in a way it offers the same that BLoC does but in a more logical way.


## Why Commands
When I started Flutter the most often recommended way to manage your state was `BLoC`. What never appealed to me was that in order to execute a process in your model layer you had to push an object into a `StreamController` which just didn't feel right. For me triggering a process should feel like calling a function.
Coming from the .Net world I was used to use Commands for this, which had an additional nice feature that the Button that triggered the command would automatically disable for the duration, the command was running and by this, preventing a double execution at the same time. I also learned to love a special breed of .Net commands called `ReactiveCommands` which emitted the result of the called function on their own Stream interface (the ReactiveUI community might oversee that I don't talk of Observables here.) As I wanted to have something similar I ported `ReactiveCommands` to Dart with my [rx_command](https://pub.dev/packages/rx_command). But somehow they did not get much attention because 1. I didn't call them state management and 2. they had to do with `Streams` and even had that scary `rx` in the name and probably the readme wasn't as good to start as I thought.

Remi Rousselet talked to me about that `ValueNotifier` and how much easier they are than using Streams. So what you have here is my second attempt to warm the hearts of the Flutter community for the `Command` metaphor absolutely free of `Streams`

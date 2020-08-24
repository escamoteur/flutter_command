---
id: command
title: Command - Under the hood
sidebar_label: Command - Under the hood
---

:::tip ValueNotifier
If you are not aware of ValueNotifier or ValueListenable please consider checking this [brief introduction](value_notifier).
:::

A `Command` is a `ValueNotifier` which wraps a given ***function*** and exposes the result of this ***function*** in its `value` property like a normal `ValueNotifier`. Just like any other `ValueNotifier` you can listen to the changes taking place to its `value` during the execution of this command.

By wrapping a ***function*** like this inside a `Command` makes it listenable to widgets that depend on the result of this ***function***. A `Command` can encapsulate any functionality that you would want your UI to react to or invoke. For example a login action. 

On the other hand If you connect your widget directly to a ***function*** that talks to the authentication server and manipulate the state variables of your widget in this ***function*** it creates a tight coupling of logic to the widget. A draw back of tight coupling is if you want other parts of your UI to react based on the results of this ***function*** then it makes it necessary to pass this result across widgets. Several approaches exits to solve this.  

- Pass this state representation across the widget tree using Inherited widgets.

- Make a global representation of this state using Redux store like concepts

- Encode this state representation in the form of Events and pass them as objects or streams.

While the above mentioned approaches has proven to be useful, a state management designed around `Command` pattern aims to remove the complexity from representing the state as a whole and/or encoded ones. It simply encourages widget to react to different functional units encapsulated into `Commands`  and also choose to deal with only those `Command` that are relevant to the widget itself.
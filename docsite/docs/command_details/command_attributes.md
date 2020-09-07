---
id: command_attributes
title: Command Attributes
sidebar_label: Command Attributes
---

In order to work with commands it is essential to understand how one can **create**, **control** and **extract** infromation from a `Command`. While the wording could seem overwhelming in the beginning, the joy of writing `Command` stems from the fact that its one time learning. The idea is uniform and applies same to all types of commands and few that don't apply will feel natural.

The fun fact is even if these attributes were not exposed it would have to designed for manually configured functions using different variables in each widget. So its worth the effort to initially understand at a high level what each attribute does and gain further understanding and intuitions from the examples.

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

## Create Commands

Different `Command` can be created depending on the signature of the ***function*** being wrapped.

#### Synchronous
<Tabs
  defaultValue="createSyncNoParamNoResult"
  values={[    
    {label: 'createSyncNoParamNoResult', value: 'createSyncNoParamNoResult'},
    {label: 'createSyncNoParam', value: 'createSyncNoParam'},
    {label: 'createSyncNoResult', value: 'createSyncNoResult'},
    {label: 'createSync', value: 'createSync'},
  ]}>
  <TabItem value="createSyncNoParamNoResult">

  ```dart
  /// A synchronous Command with no parameter and no result
  final command = createSyncNoParamNoResult((){
    print("A simple command");
  });
  ```

  </TabItem>
  <TabItem value="createSyncNoParam">

  ```dart
  /// A synchronous command with no parameter and but a result
  final command = createSyncNoParam<String>((){
    print("A simple command");
    return "My Result";
  });
  ```

  </TabItem>
  <TabItem value="createSyncNoResult">

  ```dart
  /// A synchronous Command with one parameter and no result
  final command = createSyncNoResult<String>((String param){
    print("I can use this parameter: $param");    
  });
  ```

  </TabItem>  
  <TabItem value="createSync">

  ```dart
  /// A synchronous Command with one parameter and result
  final command = createSync<int, String>((int param) {
    return "I take an integer $param and return this String";    
  });
  ```

  </TabItem>
</Tabs>

#### Asynchronous
<Tabs
  defaultValue="createAsyncNoParamNoResult"
  values={[    
    {label: 'createAsyncNoParamNoResult', value: 'createAsyncNoParamNoResult'},
    {label: 'createAsyncNoParam', value: 'createAsyncNoParam'},
    {label: 'createAsyncNoResult', value: 'createAsyncNoResult'},
    {label: 'createAsync', value: 'createAsync'},
  ]}>
  <TabItem value="createAsyncNoParamNoResult">

  ```dart
  /// A asynchronous Command with no parameter and no result
  final command = createAsyncNoParamNoResult(() async {
    // Some asynchronous consuming task
    Future.delayed(Duration(seconds: 2));
    print("A simple command");
  });
  ```

  </TabItem>
  <TabItem value="createSyncNoParam">

  ```dart
  /// A asynchronous command with no parameter and but a result
  final command = createAsyncNoParam<String>(() async {
    // Some asynchronous consuming task
    Future.delayed(Duration(seconds: 2));
    print("A simple command");
    return "My Result";
  });
  ```

  </TabItem>
  <TabItem value="createSyncNoResult">

  ```dart
  /// A asynchronous Command with one parameter and no result
  final command = createAsyncNoResult<String>((String param) async {
    // Some asynchronous consuming task
    Future.delayed(Duration(seconds: 2));
    print("I can use this parameter: $param");    
  });
  ```

  </TabItem>  
  <TabItem value="createSync">

  ```dart
  /// A asynchronous Command with one parameter and result
  final command = createSync<int, String>((int param) async {
    // Some asynchronous consuming task
    Future.delayed(Duration(seconds: 2));
    return "I take an integer $param and return this String";    
  });
  ```

  </TabItem>
</Tabs>

## Control a Command
A `Command` allows it to be controlled through certain attributes. These are breifly described below. A full and up-to-date description is always available in the API docs.

| **Attribute**      | **Type**                                                        | **Purpose**                                                                                                                                                                                                                                                                          |
| ------------------ | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `restriction`       | `ValueListenable<bool>`                                         | Indicates whether a `Command` should be executed or not at a given moment. This `ValueListenable` can be controlled from outside the `Command`. It affects the `canExecute` property defined in the next section.|
| `catchAlways`      | `bool`                                         | Suppress the exceptions from the wrapped ***function***  if `true` and `rethrow` if `false`. If a `globalExceptionHandler` is assigned or listeners registered to `result` or `thrownExceptions` then a rethrow doesn't occur. Defaults to `catchAlwaysDefault`. Check the Error Handling section for details.|
| `debugName`            | `String` | A debug name that will be passed down to the `globalExceptionHandler` and `loggingHandler`|
| `includeLastResultInCommandResults` | `bool`                                 | Include the last result in the `CommandResult`.|
| `initialValue`          | This should match the type of result expected from the `Command`                              | Initial value that will set to the `value` property of the `Command`.|

## Extract Information from Commands

It might be logical to think that when a ***function*** is encapsulated it is necessary to obtain information about the current status of execution, what happens when an exception occurs, how to connect one Command with another Command. This has been thought through and a `Command` exposes set of attributes which again are `ValueListenable` that gives access to the status of execution of a `Command` as listed below.

| **Attribute**      | **Type**                                                        | **Purpose**                                                                                                                                                                                                                                                                          |
| ------------------ | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `canExecute`       | `ValueListenable<bool>`                                         | Indicates whether a `Command`  can be executed or not at a given moment. Its a internal representation combining `isExecuting` and `restriction`. <br/><br/>Here `restriction` is a `ValueListenable` which can be controlled externally to block or allow the `Command` to execute. |
| `isExecuting`      | `ValueListenable<bool>`                                         | Indicates whether a `Command` is executing at a given moment. This is exposed on for Asynchronous Commands.                                                                                                                                                                          |
| `value`            | This matches the type of the result expected from the `Command` | This is the result returned by the ***function*** being encapsulated by the `Command`                                                                                                                                                                                                |
| `thrownExceptions` | `ValueListenable<CommandError>`                                 | All exceptions happening in a `Command`  will wrapped in `CommandError` object and exposed in the `thrownExceptions`<br/><br/>A detailed flow of error handling is available [here]()                                                                                                |
| `results`          | `ValueListenable<CommandResult>`                                | This is a combined status representation of a `Command` at any given moment. It combines the parameter passed `TParam`, the resultant `value` of type `TResult`, error/exception object and `isExecuting` attribute and exposes them all at once throughout the execution timeline of a `Command`.                                                             |

## Global Attributes
There are certain `static` attributes that control the behavior of all the `Command` in your app. Following is list of them with brief description.

|**Attribute**|**Type**|**Purpose**|
|--|--|--|
|`catchAlwaysDefault`|`bool`| Controls whether to supress or rethrow exception from a `Command`. The local `cathcAlways` overides this.|
|`gloabalExceptionHandler`|`Function(String commandName, CommandError<Object> error)`|A callback that will be called for every exception occurring in all `Command` across the app.|
|`loggingHandler`|`Function(String commandName, CommandResult result)`|A callback which be passed with all the `CommandResult` across the app.|
library flutter_command;

import 'package:flutter/foundation.dart';
import 'package:flutter_command/src/command_implementations.dart';
import 'package:functional_listener/functional_listener.dart';
import 'package:quiver_hashcode/quive_hashcode.dart';

typedef Action = void Function();
typedef Action1<TParam> = void Function(TParam param);

typedef Func<TResult> = TResult Function();
typedef Func1<TParam, TResult> = TResult Function(TParam param);

typedef AsyncAction = Future Function();
typedef AsyncAction1<TParam> = Future Function(TParam param);

typedef AsyncFunc<TResult> = Future<TResult> Function();
typedef AsyncFunc1<TParam, TResult> = Future<TResult> Function(TParam param);

typedef StreamProvider<TParam, TResult> = Stream<TResult> Function(
    TParam param);

/// Combined execution state of an `RxCommand`
/// Will be issued for any state change of any of the fields
/// During normal command execution you will get this items listening at the command's [.results] observable.
/// 1. If the command was just newly created you will get `null, null, false` (data, error, isExecuting)
/// 2. When calling execute: `null, null, true`
/// 3. When execution finishes: `the result, null, false`

class CommandResult<TParam, TResult> {
  final TParam paramData;
  final TResult data;
  final dynamic error;
  final bool isExecuting;

  // ignore: avoid_positional_boolean_parameters
  const CommandResult(this.paramData, this.data, this.error, this.isExecuting);

  const CommandResult.data(TParam param, TResult data)
      : this(param, data, null, false);

  const CommandResult.error(TParam param, dynamic error)
      : this(param, null, error, false);

  const CommandResult.isLoading([TParam param]) : this(param, null, null, true);

  const CommandResult.blank() : this(null, null, null, false);

  bool get hasData => data != null;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      other is CommandResult<TParam, TResult> &&
      other.paramData == paramData &&
      other.data == data &&
      other.error == error &&
      other.isExecuting == isExecuting;

  @override
  int get hashCode =>
      hash3(data.hashCode, error.hashCode, isExecuting.hashCode);

  @override
  String toString() {
    return 'Data: $data - HasError: $hasError - IsExecuting: $isExecuting';
  }
}

class CommandError<TParam> {
  final Object error;
  final TParam paramData;

  CommandError(
    this.paramData,
    this.error,
  );
}

/// [Command] capsules a given handler function that can then be executed by its [execute] method.
/// The result of this method is then published through its Observable (Observable wrap Dart Streams)
/// Additionally it offers Observables for it's current execution state, if the command can be executed and for
/// all possibly thrown exceptions during command execution.
///
/// [Command] implements the `Observable` interface so you can listen directly to the [Command] which emits the
/// results of the wrapped function. If this function has a [void] return type
/// it will still output one `void` item so that you can listen for the end of the execution.
///
/// The [results] Observable emits [CommandResult<TRESULT>] which is often easier in combination with Flutter `StreamBuilder`
/// because you have all state information at one place.
///
/// An [Command] is a generic class of type [RxCommand<TParam, TRESULT>]
/// where [TParam] is the type of data that is passed when calling [execute] and
/// [TResult] denotes the return type of the handler function. To signal that
/// a handler doesn't take a parameter or returns no value use the type `void`
abstract class Command<TParam, TResult> extends ValueNotifier<TResult> {
  final _isRunning = ValueNotifier<bool>(false);
  final _canExecute = ValueNotifier<bool>(true);
  bool _executionLocked = false;
  bool _includeLastResultInCommandResults;

  Command(
      // todo
      // Stream<bool> canExecuteRestriction,
      this._includeLastResultInCommandResults,
      this.initialValue)
      : super(initialValue) {
    _commandResult.listen(
        (x, _) => _thrownExceptions.value = CommandError(x.paramData, x.error));

    _commandResult.listen((x, _) => _isExecuting.value = x.isExecuting);

    // final _canExecuteParam = canExecuteRestriction == null
    //     ? Stream<bool>.value(true)
    //     : canExecuteRestriction.handleError((error) {
    //         if (error is Exception) {
    //           _thrownExceptions.value=error);
    //         }
    //       }).distinct();

    // _canExecuteParam.listen((canExecute) {
    //   _canExecute = canExecute && (!_isRunning);
    //   _executionLocked = !canExecute;
    //   _canExecuteSubject.value=_canExecute);
    // });
  }

  /// Creates  a RxCommand for a synchronous handler function with no parameter and no return type
  /// [action]: handler function
  /// [canExecute] : observable that can be used to enable/disable the command based on some other state change
  /// if omitted the command can be executed always except it's already executing
  /// [isExecuting] will issue a `bool` value on each state change. Even if you
  /// subscribe to a newly created command it will issue `false`
  /// For the `Observable<CommandResult>` that [Command] publishes in [results] this normally doesn't make sense
  /// if you want to get an initial Result with `data==null, error==null, isExecuting==false` pass
  /// [emitInitialCommandResult=true].
  /// By default the [results] Observable and the [Command] itself behave like a PublishSubject. If you want that it acts like
  /// a BehaviourSubject, meaning every listener gets the last received value, you can set [emitsLastValueToNewSubscriptions = true].
  static Command<void, void> createSyncNoParamNoResult(Action action,
      {Stream<bool> canExecute,
      bool emitInitialCommandResult = false,
      bool emitsLastValueToNewSubscriptions = false}) {
    return CommandSync<void, void>((_) {
      action();
      return null;
    }, canExecute, emitInitialCommandResult, false,
        emitsLastValueToNewSubscriptions, null);
  }

  /// Creates  a RxCommand for a synchronous handler function with one parameter and no return type
  /// `action`: handler function
  /// `canExecute` : observable that can be used to enable/disable the command based on some other state change
  /// if omitted the command can be executed always except it's already executing
  /// [isExecuting] will issue a `bool` value on each state change. Even if you
  /// subscribe to a newly created command it will issue `false`
  /// For the `Observable<CommandResult>` that [Command] publishes in [results]  this normally doesn't make sense
  /// if you want to get an initial Result with `data==null, error==null, isExecuting==false` pass
  /// [emitInitialCommandResult=true].
  /// By default the [results] Observable and the [Command] itself behave like a PublishSubject. If you want that it acts like
  /// a BehaviourSubject, meaning every listener gets the last received value, you can set [emitsLastValueToNewSubscriptions = true].
  static Command<TParam, void> createSyncNoResult<TParam>(
      Action1<TParam> action,
      {Stream<bool> canExecute,
      bool emitInitialCommandResult = false,
      bool emitsLastValueToNewSubscriptions = false}) {
    return CommandSync<TParam, void>((x) {
      action(x);
      return null;
    }, canExecute, emitInitialCommandResult, false,
        emitsLastValueToNewSubscriptions, null);
  }

  /// Creates  a RxCommand for a synchronous handler function with no parameter that returns a value
  /// `func`: handler function
  /// `canExecute` : observable that can be used to enable/disable the command based on some other state change
  /// if omitted the command can be executed always except it's already executing
  /// [isExecuting] will issue a `bool` value on each state change. Even if you
  /// subscribe to a newly created command it will issue `false`
  /// [emitLastResult] will include the value of the last successful execution in all [CommandResult] events unless there is no result.
  /// For the `Observable<CommandResult>` that [Command] publishes in [results]  this normally doesn't make sense
  /// if you want to get an initial Result with `data==null, error==null, isExecuting==false` pass
  /// [emitInitialCommandResult=true].
  /// By default the [results] Observable and the [Command] itself behave like a PublishSubject. If you want that it acts like
  /// a BehaviourSubject, meaning every listener gets the last received value, you can set [emitsLastValueToNewSubscriptions = true].
  /// [initialLastResult] sets the value of the [initialValue] property before the first item was received. This is helpful if you use
  /// [initialValue] as `initialData` of a `StreamBuilder`
  static Command<void, TResult> createSyncNoParam<TResult>(Func<TResult> func,
      {Stream<bool> canExecute,
      bool emitInitialCommandResult = false,
      bool emitLastResult = false,
      bool emitsLastValueToNewSubscriptions = false,
      TResult initialLastResult}) {
    return CommandSync<void, TResult>(
        (_) => func(),
        canExecute,
        emitInitialCommandResult,
        emitLastResult,
        emitsLastValueToNewSubscriptions,
        initialLastResult);
  }

  /// Creates  a RxCommand for a synchronous handler function with parameter that returns a value
  /// `func`: handler function
  /// `canExecute` : observable that can be used to enable/disable the command based on some other state change
  /// if omitted the command can be executed always except it's already executing
  /// [isExecuting] will issue a `bool` value on each state change. Even if you
  /// subscribe to a newly created command it will issue `false`
  /// For the `Observable<CommandResult>` that [Command] implement this normally doesn't make sense
  /// if you want to get an initial Result with `data==null, error==null, isExecuting==false` pass
  /// [emitInitialCommandResult=true].
  /// [emitLastResult] will include the value of the last successful execution in all [CommandResult] events unless there is no result.
  /// By default the [results] Observable and the [Command] itself behave like a PublishSubject. If you want that it acts like
  /// a BehaviourSubject, meaning every listener gets the last received value, you can set [emitsLastValueToNewSubscriptions = true].
  /// [initialLastResult] sets the value of the [initialValue] property before the first item was received. This is helpful if you use
  /// [initialValue] as `initialData` of a `StreamBuilder`
  static Command<TParam, TResult> createSync<TParam, TResult>(
      Func1<TParam, TResult> func,
      {Stream<bool> canExecute,
      bool emitInitialCommandResult = false,
      bool emitLastResult = false,
      bool emitsLastValueToNewSubscriptions = false,
      TResult initialLastResult}) {
    return CommandSync<TParam, TResult>(
        (x) => func(x),
        canExecute,
        emitInitialCommandResult,
        emitLastResult,
        emitsLastValueToNewSubscriptions,
        initialLastResult);
  }

  // Asynchronous

  /// Creates  a RxCommand for an asynchronous handler function with no parameter and no return type
  /// `action`: handler function
  /// `canExecute` : observable that can be used to enable/disable the command based on some other state change
  /// if omitted the command can be executed always except it's already executing
  /// [isExecuting] will issue a `bool` value on each state change. Even if you
  /// subscribe to a newly created command it will issue `false`
  /// For the `Observable<CommandResult>` that [Command] implement this normally doesn't make sense
  /// if you want to get an initial Result with `data==null, error==null, isExecuting==false` pass
  /// [emitInitialCommandResult=true].
  /// By default the [results] Observable and the [Command] itself behave like a PublishSubject. If you want that it acts like
  /// a BehaviourSubject, meaning every listener gets the last received value, you can set [emitsLastValueToNewSubscriptions = true].
  static Command<void, void> createAsyncNoParamNoResult(AsyncAction action,
      {Stream<bool> canExecute,
      bool emitInitialCommandResult = false,
      bool emitsLastValueToNewSubscriptions = false}) {
    return CommandAsync<void, void>((_) async {
      await action();
      return null;
    }, canExecute, emitInitialCommandResult, false,
        emitsLastValueToNewSubscriptions, null);
  }

  /// Creates  a RxCommand for an asynchronous handler function with one parameter and no return type
  /// `action`: handler function
  /// `canExecute` : observable that can be used to enable/disable the command based on some other state change
  /// if omitted the command can be executed always except it's already executing
  /// [isExecuting] will issue a `bool` value on each state change. Even if you
  /// subscribe to a newly created command it will issue `false`
  /// For the `Observable<CommandResult>` that [Command] implement this normally doesn't make sense
  /// if you want to get an initial Result with `data==null, error==null, isExecuting==false` pass
  /// [emitInitialCommandResult=true].
  /// By default the [results] Observable and the [Command] itself behave like a PublishSubject. If you want that it acts like
  /// a BehaviourSubject, meaning every listener gets the last received value, you can set [emitsLastValueToNewSubscriptions = true].
  static Command<TParam, void> createAsyncNoResult<TParam>(
      AsyncAction1<TParam> action,
      {Stream<bool> canExecute,
      bool emitInitialCommandResult = false,
      bool emitsLastValueToNewSubscriptions = false}) {
    return CommandAsync<TParam, void>((x) async {
      await action(x);
      return null;
    }, canExecute, emitInitialCommandResult, false,
        emitsLastValueToNewSubscriptions, null);
  }

  /// Creates  a RxCommand for an asynchronous handler function with no parameter that returns a value
  /// `func`: handler function
  /// `canExecute` : observable that can be used to enable/disable the command based on some other state change
  /// if omitted the command can be executed always except it's already executing
  /// [isExecuting] will issue a `bool` value on each state change. Even if you
  /// subscribe to a newly created command it will issue `false`
  /// for the `Observable<CommandResult>` that [Command] publishes in [results] this normally doesn't make sense
  /// if you want to get an initial Result with `data==null, error==null, isExecuting==false` pass
  /// [emitInitialCommandResult=true].
  /// [emitLastResult] will include the value of the last successful execution in all [CommandResult] events unless there is no result.
  /// By default the [results] Observable and the [Command] itself behave like a PublishSubject. If you want that it acts like
  /// a BehaviourSubject, meaning every listener gets the last received value, you can set [emitsLastValueToNewSubscriptions = true].
  /// [initialLastResult] sets the value of the [initialValue] property before the first item was received. This is helpful if you use
  /// [initialValue] as `initialData` of a `StreamBuilder`
  static Command<void, TResult> createAsyncNoParam<TResult>(
      AsyncFunc<TResult> func,
      {Stream<bool> canExecute,
      bool emitInitialCommandResult = false,
      bool emitLastResult = false,
      bool emitsLastValueToNewSubscriptions = false,
      TResult initialLastResult}) {
    return CommandAsync<void, TResult>(
        (_) async => func(),
        canExecute,
        emitInitialCommandResult,
        emitLastResult,
        emitsLastValueToNewSubscriptions,
        initialLastResult);
  }

  /// Creates  a RxCommand for an asynchronous handler function with parameter that returns a value
  /// `func`: handler function
  /// `canExecute` : observable that can be used to enable/disable the command based on some other state change
  /// if omitted the command can be executed always except it's already executing
  /// [isExecuting] will issue a `bool` value on each state change. Even if you
  /// subscribe to a newly created command it will issue `false`
  /// For the `Observable<CommandResult>` that [Command] publishes in [results] this normally doesn't make sense
  /// if you want to get an initial Result with `data==null, error==null, isExecuting==false` pass
  /// [emitInitialCommandResult=true].
  /// [emitLastResult] will include the value of the last successful execution in all [CommandResult] events unless there is no result.
  /// By default the [results] Observable and the [Command] itself behave like a PublishSubject. If you want that it acts like
  /// a BehaviourSubject, meaning every listener gets the last received value, you can set [emitsLastValueToNewSubscriptions = true].
  /// [initialLastResult] sets the value of the [initialValue] property before the first item was received. This is helpful if you use
  /// [initialValue] as `initialData` of a `StreamBuilder`
  static Command<TParam, TResult> createAsync<TParam, TResult>(
      AsyncFunc1<TParam, TResult> func,
      {Stream<bool> canExecute,
      bool emitInitialCommandResult = false,
      bool emitLastResult = false,
      bool emitsLastValueToNewSubscriptions = false,
      TResult initialLastResult}) {
    return CommandAsync<TParam, TResult>(
        (x) async => func(x),
        canExecute,
        emitInitialCommandResult,
        emitLastResult,
        emitsLastValueToNewSubscriptions,
        initialLastResult);
  }

  /// Creates  a RxCommand from an "one time" observable. This is handy if used together with a streame generator function.
  /// [provider]: provider function that returns a Observable that will be subscribed on the call of [execute]
  /// [canExecute] : observable that can be used to enable/disable the command based on some other state change
  /// if omitted the command can be executed always except it's already executing
  /// [isExecuting] will issue a `bool` value on each state change. Even if you
  /// subscribe to a newly created command it will issue `false`
  /// For the `Observable<CommandResult>` that [Command] publishes in [results] this normally doesn't make sense
  /// if you want to get an initial Result with `data==null, error==null, isExecuting==false` pass
  /// [emitInitialCommandResult=true].
  /// [emitLastResult] will include the value of the last successful execution in all [CommandResult] events unless there is no result.
  /// By default the [results] Observable and the [Command] itself behave like a PublishSubject. If you want that it acts like
  /// a BehaviourSubject, meaning every listener gets the last received value, you can set [emitsLastValueToNewSubscriptions = true].
  /// [initialLastResult] sets the value of the [initialValue] property before the first item was received. This is helpful if you use
  /// [initialValue] as `initialData` of a `StreamBuilder`
  static Command<TParam, TResult> createFromStream<TParam, TResult>(
      StreamProvider<TParam, TResult> provider,
      {Stream<bool> canExecute,
      bool emitInitialCommandResult = false,
      bool emitLastResult = false,
      bool emitsLastValueToNewSubscriptions = false,
      TResult initialLastResult}) {
    return RxCommandStream<TParam, TResult>(
        provider,
        canExecute,
        emitInitialCommandResult,
        emitLastResult,
        emitsLastValueToNewSubscriptions,
        initialLastResult);
  }

  /// Calls the wrapped handler function with an option input parameter
  void execute([TParam param]);

  /// This makes RxCommand a callable class, so instead of `myCommand.execute()` you can write `myCommand()`
  void call([TParam param]) => execute(param);

  /// The result of the last successful call to execute. This is especially handy to use as `initialData` of Flutter `StreamBuilder`
  TResult initialValue;

  /// emits [CommandResult<TRESULT>] the combined state of the command, which is often easier in combination with Flutter `StreamBuilder`
  /// because you have all state information at one place.
  ValueListenable<CommandResult<TParam, TResult>> get results => _commandResult;

  /// Observable stream that issues a bool on any execution state change of the command
  ValueListenable<bool> get isExecuting => _isExecuting;

  /// Observable stream that issues a bool on any change of the current executable state of the command.
  /// Meaning if the command cann be executed or not. This will issue `false` while the command executes
  /// but also if the command receives a false from the canExecute Observable that you can pass when creating the Command
  ValueListenable<bool> get canExecute => _canExecuteSubject;

  /// When subribing to `thrownExceptions`you will every excetpion that was thrown in your handler function as an event on this Observable.
  /// If no subscription exists the Exception will be rethrown
  ValueListenable<dynamic> get thrownExceptions => _thrownExceptions;

  // /// This property is a utility which allows us to chain RxCommands together.
  // Future<TResult> get next =>
  //     Rx.merge([this, this.thrownExceptions.cast<TResult>()]).take(1).last;

  ValueNotifier<CommandResult<TParam, TResult>> _commandResult;
  final ValueNotifier<bool> _isExecuting = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _canExecuteSubject = ValueNotifier<bool>(true);
  final ValueNotifier<CommandError<TParam>> _thrownExceptions =
      ValueNotifier<CommandError<TParam>>(null);

  /// If you don't need a command any longer it is a good practise to
  /// dispose it to make sure all stream subscriptions are cancelled to prevent memory leaks
  void dispose() {
    _commandResult.dispose();
    _isExecuting.dispose();
    _canExecuteSubject.dispose();
    _thrownExceptions.dispose();
    super.dispose();
  }
}

class CommandSync<TParam, TResult> extends Command<TParam, TResult> {
  Func1<TParam, TResult> _func;

  CommandSync(Func1<TParam, TResult> func, Stream<bool> canExecute,
      bool emitLastResult, bool emitInitialCommandResult, TResult initialValue)
      : _func = func,
        super(
          // canExecute,
          emitLastResult,
          initialValue,
        );

  @override
  void execute([TParam param]) {
    //todo   if (!_canExecute) {
    //   return;
    // }

    if (_isRunning.value) {
      return;
    } else {
      _isRunning.value = true;
//todo      _canExecuteSubject.value = false;
    }

    _commandResult.value = CommandResult<TParam, TResult>(
        param, _includeLastResultInCommandResults ? value : null, null, true);

    try {
      final result = _func(param);
      _commandResult.value =
          CommandResult<TParam, TResult>(param, result, null, false);
      value = result;
    } catch (error) {
      _commandResult.value = CommandResult<TParam, TResult>(param,
          _includeLastResultInCommandResults ? value : null, error, false);
    } finally {
      _isRunning.value = false;
      _canExecute.value = !_executionLocked;
      _canExecuteSubject.value = !_executionLocked;
    }
  }
}

class CommandAsync<TParam, TResult> extends Command<TParam, TResult> {
  AsyncFunc1<TParam, TResult> _func;

  CommandAsync(AsyncFunc1<TParam, TResult> func, Stream<bool> canExecute,
      bool includeLastResultInCommandResults, TResult initialValue)
      : _func = func,
        super(
          // canExecute,
          includeLastResultInCommandResults,
          initialValue,
        );

  @override
  void execute([TParam param]) async {
    //todo   if (!_canExecute) {
    //   return;
    // }

    if (_isRunning.value) {
      return;
    } else {
      _isRunning.value = true;
//todo      _canExecuteSubject.value = false;
    }

    _commandResult.value = CommandResult<TParam, TResult>(
        param, _includeLastResultInCommandResults ? value : null, null, true);

    try {
      final result = await _func(param);
      _commandResult.value =
          CommandResult<TParam, TResult>(param, result, null, false);
      value = result;
    } catch (error) {
      _commandResult.value = CommandResult<TParam, TResult>(param,
          _includeLastResultInCommandResults ? value : null, error, false);
    } finally {
      _isRunning.value = false;
      _canExecute.value = !_executionLocked;
      _canExecuteSubject.value = !_executionLocked;
    }
  }
}

/// `MockCommand` allows you to easily mock an Command for your Unit and UI tests
/// Mocking a command with `mockito` https://pub.dartlang.org/packages/mockito has its limitations.
class MockCommand<TParam, TResult> extends Command<TParam, TResult> {
  List<CommandResult<TParam, TResult>> returnValuesForNextExecute;

  /// the last value that was passed when execute or the command directly was called
  TParam lastPassedValueToExecute;

  /// Number of times execute or the command directly was called
  int executionCount = 0;

  /// constructor that can take an optional observable to control if the command can be executet

  MockCommand._(
      // Stream<bool> canExecute,
      bool emitLastResult,
      bool emitInitialCommandResult,
      TResult initialValue)
      : super(
          emitLastResult,
          initialValue,
        ) {
    _commandResult
        .where((result) => result.hasData)
        .listen((result, _) => value = result.data);
  }

  /// to be able to simulate any output of the command when it is called you can here queue the output data for the next exeution call
  queueResultsForNextExecuteCall(List<CommandResult<TParam, TResult>> values) {
    returnValuesForNextExecute = values;
  }

  /// Can either be called directly or by calling the object itself because Commands are callable classes
  /// Will increase [executionCount] and assign [lastPassedValueToExecute] the value of [param]
  /// If you have queued a result with [queueResultsForNextExecuteCall] it will be copies tho the output stream.
  /// [isExecuting], [canExecute] and [results] will work as with a real command.
  @override
  execute([TParam param]) {
    _canExecute.value = false;
    executionCount++;
    lastPassedValueToExecute = param;
    print("Called Execute");
    if (returnValuesForNextExecute != null) {
      returnValuesForNextExecute.map(
        (entry) {
          if ((entry.isExecuting || entry.hasError) &&
              _includeLastResultInCommandResults) {
            return CommandResult<TParam, TResult>(
                param, value, entry.error, entry.isExecuting);
          }
          return entry;
        },
      ).forEach((x) => _commandResult.value = x);
    } else {
      print("No values for execution queued");
    }
    _canExecute.value = true;
  }

  /// For a more fine grained control to simulate the different states of an [Command]
  /// there are these functions
  /// `startExecution` will issue a [CommandResult] with
  /// data: null
  /// error: null
  /// isExecuting : true
  void startExecution([TParam param]) {
    lastPassedValueToExecute = param;
    _commandResult.value = CommandResult<TParam, TResult>(
        param, _includeLastResultInCommandResults ? value : null, null, true);
    _canExecuteSubject.value = false;
  }

  /// `endExecutionWithData` will issue a [CommandResult] with
  /// data: [data]
  /// error: null
  /// isExecuting : false
  void endExecutionWithData(TResult data) {
    value = data;
    _commandResult.value = CommandResult<TParam, TResult>(
        lastPassedValueToExecute, data, null, false);
    _canExecuteSubject.value = true;
  }

  /// `endExecutionWithData` will issue a [CommandResult] with
  /// data: null
  /// error: Exeption([message])
  /// isExecuting : false
  void endExecutionWithError(String message) {
    _commandResult.value = CommandResult<TParam, TResult>(
        lastPassedValueToExecute,
        _includeLastResultInCommandResults ? value : null,
        Exception(message),
        false);
    _canExecuteSubject.value = true;
  }

  /// `endExecutionNoData` will issue a [CommandResult] with
  /// data: null
  /// error: null
  /// isExecuting : false
  void endExecutionNoData() {
    _commandResult.value = CommandResult<TParam, TResult>(
        lastPassedValueToExecute,
        _includeLastResultInCommandResults ? value : null,
        null,
        false);
    _canExecuteSubject.value = true;
  }
}

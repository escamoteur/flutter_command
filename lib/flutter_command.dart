library flutter_command;

import 'package:flutter/foundation.dart';
import 'package:functional_listener/functional_listener.dart';
import 'package:quiver_hashcode/hashcode.dart';

export 'package:flutter_command/command_builder.dart';

typedef Action = void Function();
typedef Action1<TParam> = void Function(TParam param);

typedef Func<TResult> = TResult Function();
typedef Func1<TParam, TResult> = TResult Function(TParam param);

typedef AsyncAction = Future Function();
typedef AsyncAction1<TParam> = Future Function(TParam param);

typedef AsyncFunc<TResult> = Future<TResult> Function();
typedef AsyncFunc1<TParam, TResult> = Future<TResult> Function(TParam param);

/// Combined execution state of an `Command`
/// Will be issued for any state change of any of the fields
/// During normal command execution you will get this items listening at the command's [.results] ValueListenable.
/// 1. If the command was just newly created you will get `param data,null, null, false` (data, error, isExecuting)
/// 2. When calling execute: `param data, null, null, true`
/// 3. When execution finishes: `param data, the result, null, false`
/// `param data` is the data that you pass as parameter when calling the command
class CommandResult<TParam, TResult> {
  final TParam paramData;
  final TResult data;
  final Object error;
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

/// [CommandError] wrapps an occuring error together with the argument that was
/// passed when the command was called.
/// This sort of objects are emitted on the `.thrownExceptions` ValueListenable
/// of the Command
class CommandError<TParam> {
  final Object error;
  final TParam paramData;

  CommandError(
    this.paramData,
    this.error,
  );

  @override
  String toString() {
    return '$error - for param: $paramData';
  }
}

/// [Command] capsules a given handler function that can then be executed by its [execute] method.
/// The result of this method is then published through its `ValueListenable` interface
/// Additionally it offers other `ValueListenables` for it's current execution state,
/// if the command can be executed and for all possibly thrown exceptions during command execution.
///
/// [Command] implements the `ValueListenable` interface so you can register notification handlers
///  directly to the [Command] which emits the results of the wrapped function.
/// If this function has a [void] return type registered handler will still be called
///  so that you can listen for the end of the execution.
///
/// The [results] `ValueListenable` emits [CommandResult<TRESULT>] which is often easier in combination
/// with Flutter `ValueListenableBuilder`  because you have all state information at one place.
///
/// An [Command] is a generic class of type [Command<TParam, TRESULT>]
/// where [TParam] is the type of data that is passed when calling [execute] and
/// [TResult] denotes the return type of the handler function. To signal that
/// a handler doesn't take a parameter or returns no value use the type `void`
abstract class Command<TParam, TResult> extends ValueNotifier<TResult> {
  ///
  /// Creates  a Command for a synchronous handler function with no parameter and no return type
  /// [action]: handler function
  /// [restriction] : `ValueListenable<bool>` that can be used to enable/disable
  /// the command based on some other state change. If omitted the command can
  /// be executed always except it's already executing
  /// As synchronous function doesn't give any the UI any chance to react on on a change of
  /// `.isExecuting`,isExecuting isn't supported for synchronous commands ans will throw an
  /// assert if you try to use it.
  /// Can't be used with an `ValueListenableBuilder` because it doesn't have a value, but you can
  /// register a handler to wait for the completion of the wrapped function.
  /// [catchAlways] : overrides the default set by [catchAlwaysDefault].
  /// If `false`, Exceptions thrown by the wraped function won't be caught but rethrown
  /// unless there is a listener on [thrownExceptions] or [results].
  static Command<void, void> createSyncNoParamNoResult(
    Action action, {
    ValueListenable<bool> restriction,
    bool catchAlways,
  }) {
    return CommandSync<void, void>((_) {
      action();
      return null;
    }, null, restriction, false, true, catchAlways);
  }

  /// Creates  a Command for a synchronous handler function with one parameter and no return type
  /// [action]: handler function
  /// [restriction] : `ValueListenable<bool>` that can be used to enable/disable
  /// the command based on some other state change. If omitted the command can
  /// be executed always except it's already executing
  /// As synchronous function doesn't give the UI any chance to react on on a change of
  /// `.isExecuting`,isExecuting isn't supported for synchronous commands and will throw an
  /// assert if you try to use it.
  /// Can't be used with an `ValueListenableBuilder` because it doesn't have a value, but you can
  /// register a handler to wait for the completion of the wrapped function.
  /// [catchAlways] : overrides the default set by [catchAlwaysDefault].
  /// If `false`, Exceptions thrown by the wraped function won't be caught but rethrown
  /// unless there is a listener on [thrownExceptions] or [results].
  static Command<TParam, void> createSyncNoResult<TParam>(
    Action1<TParam> action, {
    ValueListenable<bool> restriction,
    bool catchAlways,
  }) {
    return CommandSync<TParam, void>((x) {
      action(x);
      return null;
    }, null, restriction, false, true, catchAlways);
  }

  /// Creates  a Command for a synchronous handler function with no parameter that returns a value
  /// [func]: handler function
  /// [initialValue] sets the `.value` of the Command.
  /// [restriction] : `ValueListenable<bool>` that can be used to enable/disable the command based on
  ///  some other state change. If omitted the command can be executed always except it's already executing
  /// [includeLastResultInCommandResults] will include the value of the last successful execution in
  /// all `CommandResult` values unless there is no result. This can be handy if you always want to be able
  /// to display something even when you got an error.
  /// As synchronous function doesn't give any the UI any chance to react on on a change of
  /// `.isExecuting`,isExecuting isn't supported for synchronous commands and will throw an
  /// assert if you try to use it.
  /// [catchAlways] : overrides the default set by [catchAlwaysDefault].
  /// If `false`, Exceptions thrown by the wraped function won't be caught but rethrown
  /// unless there is a listener on [thrownExceptions] or [results].
  static Command<void, TResult> createSyncNoParam<TResult>(
    Func<TResult> func,
    TResult initialValue, {
    ValueListenable<bool> restriction,
    bool includeLastResultInCommandResults = false,
    bool catchAlways,
  }) {
    return CommandSync<void, TResult>((_) => func(), initialValue, restriction,
        includeLastResultInCommandResults, false, catchAlways);
  }

  /// Creates  a Command for a synchronous handler function with parameter that returns a value
  /// [func]: handler function
  /// [initialValue] sets the `.value` of the Command.
  /// [restriction] : `ValueListenable<bool>` that can be used to enable/disable the command based on
  ///  some other state change. If omitted the command can be executed always except it's already executing
  /// [includeLastResultInCommandResults] will include the value of the last successful execution in
  /// all `CommandResult` values unless there is no result. This can be handy if you always want to be able
  /// to display something even when you got an error.
  /// As synchronous function doesn't give the UI any chance to react on on a change of
  /// `.isExecuting`,isExecuting isn't supported for synchronous commands and will throw an
  /// assert if you try to use it.
  /// [catchAlways] : overrides the default set by [catchAlwaysDefault].
  /// If `false`, Exceptions thrown by the wraped function won't be caught but rethrown
  /// unless there is a listener on [thrownExceptions] or [results].
  static Command<TParam, TResult> createSync<TParam, TResult>(
    Func1<TParam, TResult> func,
    TResult initialValue, {
    ValueListenable<bool> restriction,
    bool includeLastResultInCommandResults = false,
    bool catchAlways,
  }) {
    return CommandSync<TParam, TResult>((x) => func(x), initialValue,
        restriction, includeLastResultInCommandResults, false, catchAlways);
  }

  // Asynchronous

  /// Creates  a Command for an asynchronous handler function with no parameter and no return type
  /// [action]: handler function
  /// [restriction] : `ValueListenable<bool>` that can be used to enable/disable
  /// the command based on some other state change. If omitted the command can
  /// be executed always except it's already executing
  /// Can't be used with an `ValueListenableBuilder` because it doesn't have a value, but you can
  /// register a handler to wait for the completion of the wrapped function.
  /// [catchAlways] : overrides the default set by [catchAlwaysDefault].
  /// If `false`, Exceptions thrown by the wraped function won't be caught but rethrown
  /// unless there is a listener on [thrownExceptions] or [results].
  static Command<void, void> createAsyncNoParamNoResult(
    AsyncAction action, {
    ValueListenable<bool> restriction,
    bool emitsLastValueToNewSubscriptions = false,
    bool catchAlways,
  }) {
    return CommandAsync<void, void>((_) async {
      await action();
      return null;
    }, null, restriction, false, true, catchAlways);
  }

  /// Creates  a Command for an asynchronous handler function with one parameter and no return type
  /// [action]: handler function
  /// [restriction] : `ValueListenable<bool>` that can be used to enable/disable
  /// the command based on some other state change. If omitted the command can
  /// be executed always except it's already executing
  /// Can't be used with an `ValueListenableBuilder` because it doesn't have a value but you can
  /// register a handler to wait for the completion of the wrapped function.
  /// [catchAlways] : overrides the default set by [catchAlwaysDefault].
  /// If `false`, Exceptions thrown by the wraped function won't be caught but rethrown
  /// unless there is a listener on [thrownExceptions] or [results].
  static Command<TParam, void> createAsyncNoResult<TParam>(
    AsyncAction1<TParam> action, {
    ValueListenable<bool> restriction,
    bool catchAlways,
  }) {
    return CommandAsync<TParam, void>((x) async {
      await action(x);
      return null;
    }, null, restriction, false, false, catchAlways);
  }

  /// Creates  a Command for an asynchronous handler function with no parameter that returns a value
  /// [func]: handler function
  /// [initialValue] sets the `.value` of the Command.
  /// [restriction] : `ValueListenable<bool>` that can be used to enable/disable the command based on
  ///  some other state change. If omitted the command can be executed always except it's already executing
  /// [includeLastResultInCommandResults] will include the value of the last successful execution in
  /// all `CommandResult` values unless there is no result. This can be handy if you always want to be able
  /// to display something even when you got an error or while the command is still running.
  /// [catchAlways] : overrides the default set by [catchAlwaysDefault].
  /// If `false`, Exceptions thrown by the wraped function won't be caught but rethrown
  /// unless there is a listener on [thrownExceptions] or [results].
  static Command<void, TResult> createAsyncNoParam<TResult>(
    AsyncFunc<TResult> func,
    TResult initialValue, {
    ValueListenable<bool> restriction,
    bool includeLastResultInCommandResults = false,
    bool catchAlways,
  }) {
    return CommandAsync<void, TResult>((_) async => func(), initialValue,
        restriction, includeLastResultInCommandResults, false, catchAlways);
  }

  /// Creates  a Command for an asynchronous handler function with parameter that returns a value
  /// [func]: handler function
  /// [initialValue] sets the `.value` of the Command.
  /// [restriction] : `ValueListenable<bool>` that can be used to enable/disable the command based on
  ///  some other state change. If omitted the command can be executed always except it's already executing
  /// [includeLastResultInCommandResults] will include the value of the last successful execution in
  /// all `CommandResult` values unless there is no result. This can be handy if you always want to be able
  /// to display something even when you got an error or while the command is still running.
  /// [catchAlways] : overrides the default set by [catchAlwaysDefault].
  /// If `false`, Exceptions thrown by the wraped function won't be caught but rethrown
  /// unless there is a listener on [thrownExceptions] or [results].
  static Command<TParam, TResult> createAsync<TParam, TResult>(
    AsyncFunc1<TParam, TResult> func,
    TResult initialValue, {
    ValueListenable<bool> restriction,
    bool includeLastResultInCommandResults = false,
    bool catchAlways,
  }) {
    return CommandAsync<TParam, TResult>((x) async => func(x), initialValue,
        restriction, includeLastResultInCommandResults, false, catchAlways);
  }

  /// Calls the wrapped handler function with an optional input parameter
  void execute([TParam param]);

  /// This makes Command a callable class, so instead of `myCommand.execute()`
  /// you can write `myCommand()`
  void call([TParam param]) => execute(param);

  /// emits [CommandResult<TRESULT>] the combined state of the command, which is
  /// often easier in combination with Flutter's `ValueListenableBuilder`
  /// because you have all state information at one place.
  ValueListenable<CommandResult<TParam, TResult>> get results => _commandResult;

  /// `ValueListenable`  that changes its value on any change of the execution
  /// state change of the command
  ValueListenable<bool> get isExecuting => _isExecuting;

  /// `ValueListenable<bool>`  that changes its value on any change of the current
  /// executability state of the command. Meaning if the command can be executed or not.
  /// This will issue `false` while the command executes, but also if the command
  /// receives a false from the canExecute `ValueListenable` that you can pass when
  /// creating the Command.
  /// its value is `restriction.value && !isExecuting.value`
  ValueListenable<bool> get canExecute => _canExecute;

  /// `ValueListenable<CommandError>` that reflects the Error State of the command
  /// it value is reset to `null` at the beginning of every command execution
  /// if the wrapped function throws an error, its value is set to the error is
  /// wrapped in an `CommandError`
  ///
  ValueListenable<CommandError> get thrownExceptions => _thrownExceptions;

  /// optional hander that will get call on any exception that happens inside
  /// any Command of the app. Ideal for logging
  static void Function(CommandError<Object>) globalExeptionHandler;

  /// if no individual value for `catchAlways` is passed to the factory methods,
  /// this variable defines the default.
  /// `true` : independent if there are listeners at [thrownExceptions] or [results]
  ///          the Command will catch all Exceptions that might be thrown by the
  ///          wrapped function. They will still get reported to the [globalExceptionHandler]
  /// `false`: unless no one listens on [thrownExceptions] or [results], exceptions
  ///          will be rethrown. This is can be very helpful while developing.
  ///          Before the Exception is rethrown [globalExeptionHandler] will be called.
  static bool catchAlwaysDefault = true;

  /// as we don't want that anyone changes the values of these ValueNotifiers
  /// properties we make them private and only publish their `ValueListenable`
  /// interface via getters.
  _ListenerCountingValueNotifier<CommandResult<TParam, TResult>> _commandResult;
  final ValueNotifier<bool> _isExecuting = ValueNotifier<bool>(false);
  ValueNotifier<bool> _canExecute;
  final ValueNotifier<CommandError<TParam>> _thrownExceptions =
      ValueNotifier<CommandError<TParam>>(null);

  /// If you don't need a command any longer it is a good practise to
  /// dispose it to make sure all registered notificarion handlers are remove to
  /// prevent memory leaks
  void dispose() {
    _commandResult.dispose();
    _isExecuting.dispose();
    _canExecute.dispose();
    _thrownExceptions.dispose();
    super.dispose();
  }

  /// Flag that we always should include the last succesful value in `CommandResult`
  /// for isExecuting or error states
  bool _includeLastResultInCommandResults;

  ///Flag to signal the wrapped command has no return value which means
  ///`notifyListener` has to be called directly
  final bool _noReturnValue;

  /// if true all execption will be caught even if no one is listening at [thrownExecption]
  /// or [results]
  final bool _catchAlways;

  Command(TResult initialValue, ValueListenable<bool> restriction,
      bool includeLastResultInCommandResults, noReturnValue, bool catchAlways)
      : _noReturnValue = noReturnValue,
        _includeLastResultInCommandResults = includeLastResultInCommandResults,
        _catchAlways = catchAlways,
        super(initialValue) {
    _commandResult =
        _ListenerCountingValueNotifier<CommandResult<TParam, TResult>>(
            CommandResult.data(null, initialValue));

    /// forward error states to the `thrownExceptions` Listenable
    _commandResult.where((x) => x.hasError).listen(
        (x, _) => _thrownExceptions.value = CommandError(x.paramData, x.error));

    /// forward busy states to the `isExecuting` Listenable
    _commandResult.listen((x, _) => _isExecuting.value = x.isExecuting);

    /// Merge the external excecution restricting with the internal
    /// isExecuting which also blocks execution if true
    _canExecute = restriction == null
        ? ValueNotifier<bool>(true)
        : restriction.combineLatest(_isExecuting,
            (restriction, isExcuting) => restriction && !isExcuting);
  }
}

class CommandSync<TParam, TResult> extends Command<TParam, TResult> {
  Func1<TParam, TResult> _func;

  @override
  ValueListenable<bool> get isExecuting {
    assert(false, 'isExecuting isn\'t supported by synchronous commands');
    return ValueNotifier<bool>(false);
  }

  CommandSync(
      Func1<TParam, TResult> func,
      TResult initialValue,
      ValueListenable<bool> restriction,
      bool includeLastResultInCommandResults,
      bool noReturnValue,
      bool catchAlways)
      : _func = func,
        super(initialValue, restriction, includeLastResultInCommandResults,
            noReturnValue, catchAlways ?? Command.catchAlwaysDefault);

  @override
  void execute([TParam param]) {
    if (!_canExecute.value) {
      return;
    }
    _thrownExceptions.value = null;
    try {
      final result = _func(param);
      _commandResult.value =
          CommandResult<TParam, TResult>(param, result, null, false);
      if (!_noReturnValue) {
        value = result;
      } else {
        notifyListeners();
      }
    } catch (error) {
      if (_commandResult.listenerCount < 3 && !_thrownExceptions.hasListeners) {
        /// we have no external listeners on [results] or [thrownExceptions]
        Command.globalExeptionHandler?.call(CommandError(param, error));
        if (!_catchAlways) {
          rethrow;
        }
      }
      _commandResult.value = CommandResult<TParam, TResult>(param,
          _includeLastResultInCommandResults ? value : null, error, false);
    }
  }
}

class CommandAsync<TParam, TResult> extends Command<TParam, TResult> {
  AsyncFunc1<TParam, TResult> _func;

  CommandAsync(
      AsyncFunc1<TParam, TResult> func,
      TResult initialValue,
      ValueListenable<bool> restriction,
      bool includeLastResultInCommandResults,
      bool noResult,
      bool catchAlways)
      : _func = func,
        super(initialValue, restriction, includeLastResultInCommandResults,
            noResult, catchAlways ?? Command.catchAlwaysDefault);

  @override
  void execute([TParam param]) async {
    if (!_canExecute.value) {
      return;
    }

    if (_isExecuting.value) {
      return;
    } else {
      _isExecuting.value = true;
    }

    _thrownExceptions.value = null;

    _commandResult.value = CommandResult<TParam, TResult>(
        param, _includeLastResultInCommandResults ? value : null, null, true);

    try {
      final result = await _func(param);
      _commandResult.value =
          CommandResult<TParam, TResult>(param, result, null, false);
      if (!_noReturnValue) {
        value = result;
      } else {
        notifyListeners();
      }
    } catch (error) {
      if (_commandResult.listenerCount < 3 && !_thrownExceptions.hasListeners) {
        /// we have no external listeners on [results] or [thrownExceptions]
        Command.globalExeptionHandler?.call(CommandError(param, error));
        if (!_catchAlways) {
          rethrow;
        }
      }
      _commandResult.value = CommandResult<TParam, TResult>(param,
          _includeLastResultInCommandResults ? value : null, error, false);
    } finally {
      _isExecuting.value = false;
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

  /// constructor that can take an optional `ValueListenable` to control if the command can be executet
  /// if the wrapped function has `void` as return type [noResult] has to be `true`
  MockCommand(
      TResult initialValue,
      ValueListenable<bool> restriction,
      bool includeLastResultInCommandResults,
      bool emitInitialCommandResult,
      bool noResult,
      bool catchAlways)
      : super(initialValue, restriction, includeLastResultInCommandResults,
            noResult, catchAlways ?? Command.catchAlwaysDefault) {
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
    if (!_canExecute.value) {
      return;
    }

    _isExecuting.value = true;
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
    } else if (_noReturnValue) {
      notifyListeners();
    } else {
      print("No values for execution queued");
    }
    _isExecuting.value = false;
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
    _isExecuting.value = true;
  }

  /// `endExecutionWithData` will issue a [CommandResult] with
  /// data: [data]
  /// error: null
  /// isExecuting : false
  void endExecutionWithData(TResult data) {
    value = data;
    _commandResult.value = CommandResult<TParam, TResult>(
        lastPassedValueToExecute, data, null, false);
    _isExecuting.value = false;
  }

  /// `endExecutionWithData` will issue a [CommandResult] with
  /// data: null
  /// error: Exeption([message])
  /// isExecuting : false
  void endExecutionWithError(String message) {
    _commandResult.value = CommandResult<TParam, TResult>(
        lastPassedValueToExecute,
        _includeLastResultInCommandResults ? value : null,
        CommandError(lastPassedValueToExecute, Exception(message)),
        false);
    _isExecuting.value = false;
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
    _isExecuting.value = false;
  }
}

class _ListenerCountingValueNotifier<T> extends ValueNotifier<T> {
  int listenerCount = 0;

  _ListenerCountingValueNotifier(T value) : super(value);

  @override
  void addListener(void Function() listener) {
    super.addListener(listener);
    listenerCount++;
  }

  @override
  void removeListener(void Function() listener) {
    super.removeListener(listener);
    listenerCount--;
  }

  @override
  void dispose() {
    super.dispose();
    listenerCount = 0;
  }
}

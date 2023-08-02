// ignore_for_file: avoid_positional_boolean_parameters
library flutter_command;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:functional_listener/functional_listener.dart';
import 'package:quiver/core.dart';

import 'error_handler.dart';

export 'package:flutter_command/command_builder.dart';
export 'package:functional_listener/functional_listener.dart';

part './undoable_command.dart';

/// Combined execution state of a `Command` represented using four of its fields.
/// A [CommandResult] will be issued for any state change of any of its fields
/// During normal command execution you will get this items by listening at the command's [.results] ValueListenable.
/// 1. If the command was just newly created you will get `param data, null, null, false` (paramData, data, error, isExecuting)
/// 2. When calling execute: `param data, null, null, true`
/// 3. When execution finishes: `param data, the result, null, false`
/// `param data` is the data that you pass as parameter when calling the command
class CommandResult<TParam, TResult> {
  final TParam? paramData;
  final TResult? data;
  final Object? error;
  final bool isExecuting;

  const CommandResult(this.paramData, this.data, this.error, this.isExecuting);

  const CommandResult.data(TParam? param, TResult data)
      : this(param, data, null, false);

  const CommandResult.error(TParam? param, dynamic error)
      : this(param, null, error, false);

  const CommandResult.isLoading([TParam? param])
      : this(param, null, null, true);

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
    return 'ParamData $paramData - Data: $data - HasError: $hasError - IsExecuting: $isExecuting';
  }
}

/// [CommandError] wraps an occurring error together with the argument that was
/// passed when the command was called.
/// This sort of objects are emitted on the `.errors` ValueListenable
/// of the Command
class CommandError<TParam> {
  final Object? error;
  final TParam? paramData;
  final String? commandName;

  CommandError(this.paramData, this.error, {this.commandName});

  @override
  bool operator ==(Object other) =>
      other is CommandError<TParam> &&
      other.paramData == paramData &&
      other.error == error;

  @override
  int get hashCode => hash2(error.hashCode, paramData.hashCode);

  @override
  String toString() {
    return '$error - for param: $paramData';
  }
}

typedef ExecuteInsteadHandler<TParam> = void Function(TParam?);

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
/// The [results] `ValueListenable` emits [CommandResult<TResult>] which is often easier in combination
/// with Flutter `ValueListenableBuilder`  because you have all state information at one place.
///
/// An [Command] is a generic class of type [Command<TParam, TResult>]
/// where [TParam] is the type of data that is passed when calling [execute] and
/// [TResult] denotes the return type of the handler function. To signal that
/// a handler doesn't take a parameter or returns no value use the type `void`
abstract class Command<TParam, TResult> extends CustomValueNotifier<TResult> {
  Command({
    required TResult initialValue,
    required ValueListenable<bool>? restriction,
    required ExecuteInsteadHandler<TParam>? ifRestrictedExecuteInstead,
    required bool includeLastResultInCommandResults,
    required bool noReturnValue,
    required bool notifyOnlyWhenValueChanges,
    ErrorFilter? errorFilter,
    required String? debugName,
    required bool noParamValue,
  })  : _restriction = restriction,
        _ifRestrictedExecuteInstead = ifRestrictedExecuteInstead,
        _noReturnValue = noReturnValue,
        _noParamValue = noParamValue,
        _includeLastResultInCommandResults = includeLastResultInCommandResults,
        _errorFilter = errorFilter ?? errorFilterDefault,
        _debugName = debugName,
        super(
          initialValue,
          mode: notifyOnlyWhenValueChanges
              ? CustomNotifierMode.normal
              : CustomNotifierMode.always,
        ) {
    _commandResult = CustomValueNotifier<CommandResult<TParam?, TResult>>(
      CommandResult.data(null, initialValue),
    );

    /// forward error states to the `errors` Listenable
    _commandResult.where((x) => x.hasError).listen((x, _) {
      _errors.value = CommandError<TParam>(
        x.paramData,
        x.error,
        commandName: this._debugName,
      );
      _errors.notifyListeners();
    });

    /// forward busy states to the `isExecuting` Listenable
    _commandResult.listen((x, _) => _isExecuting.value = x.isExecuting);

    /// Merge the external execution restricting with the internal
    /// isExecuting which also blocks execution if true
    _canExecute = (_restriction == null)
        ? _isExecuting.map((val) => !val) as ValueNotifier<bool>
        : _restriction!.combineLatest<bool, bool>(
            _isExecuting,
            (restriction, isExecuting) => !restriction && !isExecuting,
          ) as ValueNotifier<bool>;
  }

  ///
  /// Creates  a Command for a synchronous handler function with no parameter and no return type
  /// [action] : handler function
  /// [restriction] : `ValueListenable<bool>` that can be used to enable/disable
  /// the command based on some other state change. `true` means that the Command cannot be executed.
  /// If omitted the command can be executed always except it's already executing
  /// [ifRestrictedExecuteInstead] if  [restriction] is set for the command and its value is `true`
  /// this function will be called instead of the wrapped function.
  /// This is useful if you want to execute a different function when the command
  /// is restricted. For example you could show a dialog to let the user logg in
  /// if the restriction is because the user is not logged in.
  /// If you don't set this function, the command will just do nothing when it's
  /// restricted.
  /// As synchronous function doesn't give any the UI any chance to react on on a change of
  /// `.isExecuting`,isExecuting isn't supported for synchronous commands ans will throw an
  /// assert if you try to use it.
  /// Can't be used with an `ValueListenableBuilder` because it doesn't have a value, but you can
  /// register a handler to wait for the completion of the wrapped function.
  /// [errorFilter] : overrides the default set by [errorFilterDefault].
  /// If `false`, Exceptions thrown by the wrapped function won't be caught but rethrown
  /// unless there is a listener on [errors] or [results].
  /// [notifyOnlyWhenValueChanges] : the default is that the command notifies it's listeners even
  /// if the value hasn't changed. If you set this to `true` the command will only notify
  /// it's listeners if the value has changed.
  /// [debugName] optional identifier that is included when you register a [globalExceptionHandler]
  /// or a [loggingHandler]
  static Command<void, void> createSyncNoParamNoResult(
    void Function() action, {
    ValueListenable<bool>? restriction,
    void Function()? ifRestrictedExecuteInstead,
    ErrorFilter? errorFilter,
    bool notifyOnlyWhenValueChanges = false,
    String? debugName,
  }) {
    return CommandSync<void, void>(
      funcNoParam: action,
      initialValue: null,
      restriction: restriction,
      ifRestrictedExecuteInstead: ifRestrictedExecuteInstead != null
          ? (_) => ifRestrictedExecuteInstead()
          : null,
      includeLastResultInCommandResults: false,
      noReturnValue: true,
      errorFilter: errorFilter,
      notifyOnlyWhenValueChanges: notifyOnlyWhenValueChanges,
      debugName: debugName,
      noParamValue: true,
    );
  }

  /// Creates  a Command for a synchronous handler function with one parameter and no return type
  /// [action] : handler function
  /// [restriction] : `ValueListenable<bool>` that can be used to enable/disable
  /// the command based on some other state change. `true` means that the Command cannot be executed.
  /// If omitted the command can be executed always except it's already executing
  /// [ifRestrictedExecuteInstead] if  [restriction] is set for the command and its value is `true`
  /// this function will be called instead of the wrapped function.
  /// This is useful if you want to execute a different function when the command
  /// is restricted. For example you could show a dialog to let the user logg in
  /// if the restriction is because the user is not logged in.
  /// If you don't set this function, the command will just do nothing when it's
  /// restricted.
  /// As synchronous function doesn't give the UI any chance to react on on a change of
  /// `.isExecuting`,isExecuting isn't supported for synchronous commands and will throw an
  /// assert if you try to use it.
  /// Can't be used with an `ValueListenableBuilder` because it doesn't have a value, but you can
  /// register a handler to wait for the completion of the wrapped function.
  /// [errorFilter] : overrides the default set by [errorFilterDefault].
  /// If `false`, Exceptions thrown by the wrapped function won't be caught but rethrown
  /// unless there is a listener on [errors] or [results].
  /// [notifyOnlyWhenValueChanges] : the default is that the command notifies it's listeners even
  /// if the value hasn't changed. If you set this to `true` the command will only notify
  /// it's listeners if the value has changed.
  /// [debugName] optional identifier that is included when you register a [globalExceptionHandler]
  /// or a [loggingHandler]
  static Command<TParam, void> createSyncNoResult<TParam>(
    void Function(TParam x) action, {
    ValueListenable<bool>? restriction,
    ExecuteInsteadHandler<TParam>? ifRestrictedExecuteInstead,
    ErrorFilter? errorFilter,
    bool notifyOnlyWhenValueChanges = false,
    String? debugName,
  }) {
    return CommandSync<TParam, void>(
      func: (x) => action(x),
      initialValue: null,
      restriction: restriction,
      ifRestrictedExecuteInstead: ifRestrictedExecuteInstead,
      includeLastResultInCommandResults: false,
      noReturnValue: true,
      errorFilter: errorFilter,
      notifyOnlyWhenValueChanges: notifyOnlyWhenValueChanges,
      debugName: debugName,
      noParamValue: false,
    );
  }

  /// Creates  a Command for a synchronous handler function with no parameter that returns a value
  /// [func] : handler function
  /// [initialValue] sets the `.value` of the Command.
  /// [restriction] : `ValueListenable<bool>` that can be used to enable/disable the command based on
  /// some other state change. `true` means that the Command cannot be executed.
  /// If omitted the command can be executed always except it's already executing
  /// [ifRestrictedExecuteInstead] if  [restriction] is set for the command and its value is `true`
  /// this function will be called instead of the wrapped function.
  /// This is useful if you want to execute a different function when the command
  /// is restricted. For example you could show a dialog to let the user logg in
  /// if the restriction is because the user is not logged in.
  /// If you don't set this function, the command will just do nothing when it's
  /// restricted.
  /// [includeLastResultInCommandResults] will include the value of the last successful execution in
  /// all `CommandResult` values unless there is no result. This can be handy if you always want to be able
  /// to display something even when you got an error.
  /// As synchronous function doesn't give any the UI any chance to react on on a change of
  /// `.isExecuting`,isExecuting isn't supported for synchronous commands and will throw an
  /// assert if you try to use it.
  /// [errorFilter] : overrides the default set by [errorFilterDefault].
  /// If `false`, Exceptions thrown by the wrapped function won't be caught but rethrown
  /// unless there is a listener on [errors] or [results].
  /// [notifyOnlyWhenValueChanges] : the default is that the command notifies it's listeners even
  /// if the value hasn't changed. If you set this to `true` the command will only notify
  /// it's listeners if the value has changed.
  /// [debugName] optional identifier that is included when you register a [globalExceptionHandler]
  /// or a [loggingHandler]
  static Command<void, TResult> createSyncNoParam<TResult>(
    TResult Function() func, {
    required TResult initialValue,
    ValueListenable<bool>? restriction,
    void Function()? ifRestrictedExecuteInstead,
    bool includeLastResultInCommandResults = false,
    ErrorFilter? errorFilter,
    bool notifyOnlyWhenValueChanges = false,
    String? debugName,
  }) {
    return CommandSync<void, TResult>(
      funcNoParam: func,
      initialValue: initialValue,
      restriction: restriction,
      ifRestrictedExecuteInstead: ifRestrictedExecuteInstead != null
          ? (_) => ifRestrictedExecuteInstead()
          : null,
      includeLastResultInCommandResults: includeLastResultInCommandResults,
      noReturnValue: false,
      errorFilter: errorFilter,
      notifyOnlyWhenValueChanges: notifyOnlyWhenValueChanges,
      debugName: debugName,
      noParamValue: true,
    );
  }

  /// Creates  a Command for a synchronous handler function with parameter that returns a value
  /// [func] : handler function
  /// [initialValue] sets the `.value` of the Command.
  /// [restriction] : `ValueListenable<bool>` that can be used to enable/disable the command based on
  ///  some other state change. `true` means that the Command cannot be executed.
  /// If omitted the command can be executed always except it's already executing
  /// [ifRestrictedExecuteInstead] if  [restriction] is set for the command and its value is `true`
  /// this function will be called instead of the wrapped function.
  /// This is useful if you want to execute a different function when the command
  /// is restricted. For example you could show a dialog to let the user logg in
  /// if the restriction is because the user is not logged in.
  /// If you don't set this function, the command will just do nothing when it's
  /// restricted.
  /// [includeLastResultInCommandResults] will include the value of the last successful execution in
  /// all `CommandResult` values unless there is no result. This can be handy if you always want to be able
  /// to display something even when you got an error.
  /// As synchronous function doesn't give the UI any chance to react on on a change of
  /// `.isExecuting`,isExecuting isn't supported for synchronous commands and will throw an
  /// assert if you try to use it.
  /// [errorFilter] : overrides the default set by [errorFilterDefault].
  /// If `false`, Exceptions thrown by the wrapped function won't be caught but rethrown
  /// If `false`, Exceptions thrown by the wrapped function won't be caught but rethrown
  /// unless there is a listener on [errors] or [results].
  /// [notifyOnlyWhenValueChanges] : the default is that the command notifies it's listeners even
  /// if the value hasn't changed. If you set this to `true` the command will only notify
  /// it's listeners if the value has changed.
  /// [debugName] optional identifier that is included when you register a [globalExceptionHandler]
  /// or a [loggingHandler]
  static Command<TParam, TResult> createSync<TParam, TResult>(
    TResult Function(TParam x) func, {
    required TResult initialValue,
    ValueListenable<bool>? restriction,
    ExecuteInsteadHandler<TParam>? ifRestrictedExecuteInstead,
    bool includeLastResultInCommandResults = false,
    ErrorFilter? errorFilter,
    bool notifyOnlyWhenValueChanges = false,
    String? debugName,
  }) {
    return CommandSync<TParam, TResult>(
      func: func,
      initialValue: initialValue,
      restriction: restriction,
      ifRestrictedExecuteInstead: ifRestrictedExecuteInstead,
      includeLastResultInCommandResults: includeLastResultInCommandResults,
      noReturnValue: false,
      errorFilter: errorFilter,
      notifyOnlyWhenValueChanges: notifyOnlyWhenValueChanges,
      debugName: debugName,
      noParamValue: false,
    );
  }

  // Asynchronous

  /// Creates  a Command for an asynchronous handler function with no parameter and no return type
  /// [action] : handler function
  /// Can't be used with an `ValueListenableBuilder` because it doesn't have a value, but you can
  /// register a handler to wait for the completion of the wrapped function.
  /// [restriction] : `ValueListenable<bool>` that can be used to enable/disable
  /// the command based on some other state change. `true` means that the Command cannot be executed.
  /// If omitted the command can be executed always except it's already executing
  /// [ifRestrictedExecuteInstead] if  [restriction] is set for the command and its value is `true`
  /// this function will be called instead of the wrapped function.
  /// This is useful if you want to execute a different function when the command
  /// is restricted. For example you could show a dialog to let the user logg in
  /// if the restriction is because the user is not logged in.
  /// If you don't set this function, the command will just do nothing when it's
  /// restricted.
  /// [errorFilter] : overrides the default set by [errorFilterDefault].
  /// If `false`, Exceptions thrown by the wrapped function won't be caught but rethrown
  /// unless there is a listener on [errors] or [results].
  /// [notifyOnlyWhenValueChanges] : the default is that the command notifies it's listeners even
  /// if the value hasn't changed. If you set this to `true` the command will only notify
  /// it's listeners if the value has changed.
  /// [debugName] optional identifier that is included when you register a [globalExceptionHandler]
  /// or a [loggingHandler]
  static Command<void, void> createAsyncNoParamNoResult(
    Future Function() action, {
    ValueListenable<bool>? restriction,
    void Function()? ifRestrictedExecuteInstead,
    ErrorFilter? errorFilter,
    bool notifyOnlyWhenValueChanges = false,
    String? debugName,
  }) {
    return CommandAsync<void, void>(
      funcNoParam: action,
      initialValue: null,
      restriction: restriction,
      ifRestrictedExecuteInstead: ifRestrictedExecuteInstead != null
          ? (_) => ifRestrictedExecuteInstead()
          : null,
      includeLastResultInCommandResults: false,
      noReturnValue: true,
      errorFilter: errorFilter,
      notifyOnlyWhenValueChanges: notifyOnlyWhenValueChanges,
      debugName: debugName,
      noParamValue: true,
    );
  }

  /// Creates  a Command for an asynchronous handler function with one parameter and no return type
  /// [action] : handler function
  /// Can't be used with an `ValueListenableBuilder` because it doesn't have a value but you can
  /// register a handler to wait for the completion of the wrapped function.
  /// [restriction] : `ValueListenable<bool>` that can be used to enable/disable
  /// the command based on some other state change. `true` means that the Command cannot be executed.
  /// If omitted the command can be executed always except it's already executing
  /// [ifRestrictedExecuteInstead] if  [restriction] is set for the command and its value is `true`
  /// this function will be called instead of the wrapped function.
  /// This is useful if you want to execute a different function when the command
  /// is restricted. For example you could show a dialog to let the user logg in
  /// if the restriction is because the user is not logged in.
  /// If you don't set this function, the command will just do nothing when it's
  /// restricted.
  /// [errorFilter] : overrides the default set by [errorFilterDefault].
  /// If `false`, Exceptions thrown by the wrapped function won't be caught but rethrown
  /// unless there is a listener on [errors] or [results].
  /// [notifyOnlyWhenValueChanges] : the default is that the command notifies it's listeners even
  /// if the value hasn't changed. If you set this to `true` the command will only notify
  /// it's listeners if the value has changed.
  /// [debugName] optional identifier that is included when you register a [globalExceptionHandler]
  /// or a [loggingHandler]
  static Command<TParam, void> createAsyncNoResult<TParam>(
    Future Function(TParam x) action, {
    ValueListenable<bool>? restriction,
    ExecuteInsteadHandler<TParam>? ifRestrictedExecuteInstead,
    ErrorFilter? errorFilter,
    bool notifyOnlyWhenValueChanges = false,
    String? debugName,
  }) {
    return CommandAsync<TParam, void>(
      func: action,
      initialValue: null,
      restriction: restriction,
      ifRestrictedExecuteInstead: ifRestrictedExecuteInstead,
      includeLastResultInCommandResults: false,
      noReturnValue: true,
      errorFilter: errorFilter,
      notifyOnlyWhenValueChanges: notifyOnlyWhenValueChanges,
      debugName: debugName,
      noParamValue: false,
    );
  }

  /// Creates  a Command for an asynchronous handler function with no parameter that returns a value
  /// [func] : handler function
  /// [initialValue] sets the `.value` of the Command.
  /// [restriction] : `ValueListenable<bool>` that can be used to enable/disable the command based on
  ///  some other state change. `true` means that the Command cannot be executed. If omitted the command
  /// can be executed always except it's already executing
  /// [ifRestrictedExecuteInstead] if  [restriction] is set for the command and its value is `true`
  /// this function will be called instead of the wrapped function.
  /// This is useful if you want to execute a different function when the command
  /// is restricted. For example you could show a dialog to let the user logg in
  /// if the restriction is because the user is not logged in.
  /// If you don't set this function, the command will just do nothing when it's
  /// restricted.
  /// [includeLastResultInCommandResults] will include the value of the last successful execution in
  /// all `CommandResult` values unless there is no result. This can be handy if you always want to be able
  /// to display something even when you got an error or while the command is still running.
  /// [errorFilter] : overrides the default set by [errorFilterDefault].
  /// If `false`, Exceptions thrown by the wrapped function won't be caught but rethrown
  /// unless there is a listener on [errors] or [results].
  /// [notifyOnlyWhenValueChanges] : the default is that the command notifies it's listeners even
  /// if the value hasn't changed. If you set this to `true` the command will only notify
  /// it's listeners if the value has changed.
  /// [debugName] optional identifier that is included when you register a [globalExceptionHandler]
  /// or a [loggingHandler]
  static Command<void, TResult> createAsyncNoParam<TResult>(
    Future<TResult> Function() func, {
    required TResult initialValue,
    ValueListenable<bool>? restriction,
    void Function()? ifRestrictedExecuteInstead,
    bool includeLastResultInCommandResults = false,
    ErrorFilter? errorFilter,
    bool notifyOnlyWhenValueChanges = false,
    String? debugName,
  }) {
    return CommandAsync<void, TResult>(
      funcNoParam: func,
      initialValue: initialValue,
      restriction: restriction,
      ifRestrictedExecuteInstead: ifRestrictedExecuteInstead != null
          ? (_) => ifRestrictedExecuteInstead()
          : null,
      includeLastResultInCommandResults: includeLastResultInCommandResults,
      noReturnValue: false,
      errorFilter: errorFilter,
      notifyOnlyWhenValueChanges: notifyOnlyWhenValueChanges,
      debugName: debugName,
      noParamValue: true,
    );
  }

  /// Creates  a Command for an asynchronous handler function with parameter that returns a value
  /// [func] : handler function
  /// [initialValue] sets the `.value` of the Command.
  /// [restriction] : `ValueListenable<bool>` that can be used to enable/disable the command based on
  ///  some other state change. `true` means that the Command cannot be executed.
  /// If omitted the command can be executed always except it's already executing
  /// [ifRestrictedExecuteInstead] if  [restriction] is set for the command and its value is `true`
  /// this function will be called instead of the wrapped function.
  /// This is useful if you want to execute a different function when the command
  /// is restricted. For example you could show a dialog to let the user logg in
  /// if the restriction is because the user is not logged in.
  /// If you don't set this function, the command will just do nothing when it's
  /// restricted.
  /// [includeLastResultInCommandResults] will include the value of the last successful execution in
  /// all `CommandResult` values unless there is no result. This can be handy if you always want to be able
  /// to display something even when you got an error or while the command is still running.
  /// [errorFilter] : overrides the default set by [errorFilterDefault].
  /// If `false`, Exceptions thrown by the wrapped function won't be caught but rethrown
  /// unless there is a listener on [errors] or [results].
  /// [notifyOnlyWhenValueChanges] : the default is that the command notifies it's listeners even
  /// if the value hasn't changed. If you set this to `true` the command will only notify
  /// it's listeners if the value has changed.
  /// [debugName] optional identifier that is included when you register a [globalExceptionHandler]
  /// or a [loggingHandler]
  static Command<TParam, TResult> createAsync<TParam, TResult>(
    Future<TResult> Function(TParam x) func, {
    required TResult initialValue,
    ValueListenable<bool>? restriction,
    ExecuteInsteadHandler<TParam>? ifRestrictedExecuteInstead,
    bool includeLastResultInCommandResults = false,
    ErrorFilter? errorFilter,
    bool notifyOnlyWhenValueChanges = false,
    String? debugName,
  }) {
    return CommandAsync<TParam, TResult>(
      func: func,
      initialValue: initialValue,
      restriction: restriction,
      ifRestrictedExecuteInstead: ifRestrictedExecuteInstead,
      includeLastResultInCommandResults: includeLastResultInCommandResults,
      noReturnValue: false,
      errorFilter: errorFilter,
      notifyOnlyWhenValueChanges: notifyOnlyWhenValueChanges,
      debugName: debugName,
      noParamValue: false,
    );
  }

  /// Creates  an undoable Command for an asynchronous handler function with no parameter and no return type
  /// [action] : handler function
  /// Can't be used with an `ValueListenableBuilder` because it doesn't have a value, but you can
  /// register a handler to wait for the completion of the wrapped function.
  /// [undo] : function that undoes the action.
  /// [undoOnExecutionFailure] : if `true` the undo function will be executed automatically if the action
  /// fails.
  /// [restriction] : `ValueListenable<bool>` that can be used to enable/disable
  /// the command based on some other state change. `true` means that the Command cannot be executed.
  /// If omitted the command can be executed always except it's already executing
  /// [ifRestrictedExecuteInstead] if  [restriction] is set for the command and its value is `true`
  /// this function will be called instead of the wrapped function.
  /// This is useful if you want to execute a different function when the command
  /// is restricted. For example you could show a dialog to let the user logg in
  /// if the restriction is because the user is not logged in.
  /// If you don't set this function, the command will just do nothing when it's
  /// restricted.
  /// [errorFilter] : overrides the default set by [errorFilterDefault].
  /// If `false`, Exceptions thrown by the wrapped function won't be caught but rethrown
  /// unless there is a listener on [errors] or [results].
  /// [notifyOnlyWhenValueChanges] : the default is that the command notifies it's listeners even
  /// if the value hasn't changed. If you set this to `true` the command will only notify
  /// it's listeners if the value has changed.
  /// [debugName] optional identifier that is included when you register a [globalExceptionHandler]
  /// or a [loggingHandler]
  static Command<void, void> createUndoableNoParamNoResult<TUndoState>(
    Future Function(UndoStack<TUndoState>) action, {
    required UndoFn<TUndoState, void> undo,
    bool undoOnExecutionFailure = true,
    ValueListenable<bool>? restriction,
    void Function()? ifRestrictedExecuteInstead,
    ErrorFilter? errorFilter = const ErrorHandlerLocal(),
    bool notifyOnlyWhenValueChanges = false,
    String? debugName,
  }) {
    return UndoableCommand<void, void, TUndoState>(
      funcNoParam: action,
      undo: undo,
      initialValue: null,
      restriction: restriction,
      ifRestrictedExecuteInstead: ifRestrictedExecuteInstead != null
          ? (_) => ifRestrictedExecuteInstead()
          : null,
      undoOnExecutionFailure: undoOnExecutionFailure,
      includeLastResultInCommandResults: false,
      noReturnValue: true,
      errorFilter: errorFilter,
      notifyOnlyWhenValueChanges: notifyOnlyWhenValueChanges,
      debugName: debugName,
      noParamValue: true,
    );
  }

  /// Creates  an undoable Command for an asynchronous handler function with one parameter and no return type
  /// [action] : handler function
  /// Can't be used with an `ValueListenableBuilder` because it doesn't have a value, but you can
  /// register a handler to wait for the completion of the wrapped function.
  /// [undo] : function that undoes the action.
  /// [undoOnExecutionFailure] : if `true` the undo function will be executed automatically if the action
  /// fails.
  /// [restriction] : `ValueListenable<bool>` that can be used to enable/disable
  /// the command based on some other state change. `true` means that the Command cannot be executed.
  /// If omitted the command can be executed always except it's already executing
  /// [ifRestrictedExecuteInstead] if  [restriction] is set for the command and its value is `true`
  /// this function will be called instead of the wrapped function.
  /// This is useful if you want to execute a different function when the command
  /// is restricted. For example you could show a dialog to let the user logg in
  /// if the restriction is because the user is not logged in.
  /// If you don't set this function, the command will just do nothing when it's
  /// restricted.
  /// [errorFilter] : overrides the default set by [errorFilterDefault].
  /// If `false`, Exceptions thrown by the wrapped function won't be caught but rethrown
  /// unless there is a listener on [errors] or [results].
  /// [notifyOnlyWhenValueChanges] : the default is that the command notifies it's listeners even
  /// if the value hasn't changed. If you set this to `true` the command will only notify
  /// it's listeners if the value has changed.
  /// [debugName] optional identifier that is included when you register a [globalExceptionHandler]
  /// or a [loggingHandler]
  static Command<TParam, void> createUndoableNoResult<TParam, TUndoState>(
    Future Function(TParam, UndoStack<TUndoState>) action, {
    required UndoFn<TUndoState, void> undo,
    bool undoOnExecutionFailure = true,
    ValueListenable<bool>? restriction,
    ExecuteInsteadHandler<TParam>? ifRestrictedExecuteInstead,
    ErrorFilter? errorFilter,
    bool notifyOnlyWhenValueChanges = false,
    String? debugName,
  }) {
    return UndoableCommand<TParam, void, TUndoState>(
      func: action,
      undo: undo,
      undoOnExecutionFailure: undoOnExecutionFailure,
      initialValue: null,
      restriction: restriction,
      ifRestrictedExecuteInstead: ifRestrictedExecuteInstead,
      includeLastResultInCommandResults: false,
      noReturnValue: true,
      errorFilter: errorFilter,
      notifyOnlyWhenValueChanges: notifyOnlyWhenValueChanges,
      debugName: debugName,
      noParamValue: false,
    );
  }

  /// Creates  a undoable Command for an asynchronous handler function with no parameter that returns a value
  /// [func] : handler function
  /// Can't be used with an `ValueListenableBuilder` because it doesn't have a value, but you can
  /// register a handler to wait for the completion of the wrapped function.
  /// [undo] : function that undoes the action.
  /// [initialValue] sets the `.value` of the Command.
  /// [undoOnExecutionFailure] : if `true` the undo function will be executed automatically if the action
  /// fails.
  /// [restriction] : `ValueListenable<bool>` that can be used to enable/disable
  /// the command based on some other state change. `true` means that the Command cannot be executed.
  /// If omitted the command can be executed always except it's already executing
  /// [ifRestrictedExecuteInstead] if  [restriction] is set for the command and its value is `true`
  /// this function will be called instead of the wrapped function.
  /// This is useful if you want to execute a different function when the command
  /// is restricted. For example you could show a dialog to let the user logg in
  /// if the restriction is because the user is not logged in.
  /// If you don't set this function, the command will just do nothing when it's
  /// restricted.
  /// [errorFilter] : overrides the default set by [errorFilterDefault].
  /// If `false`, Exceptions thrown by the wrapped function won't be caught but rethrown
  /// unless there is a listener on [errors] or [results].
  /// [notifyOnlyWhenValueChanges] : the default is that the command notifies it's listeners even
  /// if the value hasn't changed. If you set this to `true` the command will only notify
  /// it's listeners if the value has changed.
  /// [debugName] optional identifier that is included when you register a [globalExceptionHandler]
  /// or a [loggingHandler]
  static Command<void, TResult> createUndoableNoParam<TResult, TUndoState>(
    Future<TResult> Function(UndoStack<TUndoState>) func, {
    required TResult initialValue,
    required UndoFn<TUndoState, TResult> undo,
    bool undoOnExecutionFailure = true,
    ValueListenable<bool>? restriction,
    void Function()? ifRestrictedExecuteInstead,
    bool includeLastResultInCommandResults = false,
    ErrorFilter? errorFilter,
    bool notifyOnlyWhenValueChanges = false,
    String? debugName,
  }) {
    return UndoableCommand<void, TResult, TUndoState>(
      funcNoParam: func,
      undo: undo,
      initialValue: initialValue,
      undoOnExecutionFailure: undoOnExecutionFailure,
      restriction: restriction,
      ifRestrictedExecuteInstead: ifRestrictedExecuteInstead != null
          ? (_) => ifRestrictedExecuteInstead()
          : null,
      includeLastResultInCommandResults: includeLastResultInCommandResults,
      noReturnValue: false,
      errorFilter: errorFilter,
      notifyOnlyWhenValueChanges: notifyOnlyWhenValueChanges,
      debugName: debugName,
      noParamValue: true,
    );
  }

  /// Creates  a Command for an asynchronous handler function with parameter that returns a value
  /// [func] : handler function
  /// Can't be used with an `ValueListenableBuilder` because it doesn't have a value, but you can
  /// register a handler to wait for the completion of the wrapped function.
  /// [undo] : function that undoes the action.
  /// [initialValue] sets the `.value` of the Command.
  /// [undoOnExecutionFailure] : if `true` the undo function will be executed automatically if the action
  /// fails.
  /// [restriction] : `ValueListenable<bool>` that can be used to enable/disable
  /// the command based on some other state change. `true` means that the Command cannot be executed.
  /// If omitted the command can be executed always except it's already executing
  /// [ifRestrictedExecuteInstead] if  [restriction] is set for the command and its value is `true`
  /// this function will be called instead of the wrapped function.
  /// This is useful if you want to execute a different function when the command
  /// is restricted. For example you could show a dialog to let the user logg in
  /// if the restriction is because the user is not logged in.
  /// If you don't set this function, the command will just do nothing when it's
  /// restricted.
  /// [errorFilter] : overrides the default set by [errorFilterDefault].
  /// If `false`, Exceptions thrown by the wrapped function won't be caught but rethrown
  /// unless there is a listener on [errors] or [results].
  /// [notifyOnlyWhenValueChanges] : the default is that the command notifies it's listeners even
  /// if the value hasn't changed. If you set this to `true` the command will only notify
  /// it's listeners if the value has changed.
  /// [debugName] optional identifier that is included when you register a [globalExceptionHandler]
  /// or a [loggingHandler]
  static Command<TParam, TResult> createUndoable<TParam, TResult, TUndoState>(
    Future<TResult> Function(TParam, UndoStack<TUndoState>) func, {
    required TResult initialValue,
    required UndoFn<TUndoState, TResult> undo,
    bool undoOnExecutionFailure = true,
    ValueListenable<bool>? restriction,
    ExecuteInsteadHandler<TParam>? ifRestrictedExecuteInstead,
    bool includeLastResultInCommandResults = false,
    ErrorFilter? errorFilter,
    bool notifyOnlyWhenValueChanges = false,
    String? debugName,
  }) {
    return UndoableCommand<TParam, TResult, TUndoState>(
      func: func,
      initialValue: initialValue,
      undo: undo,
      restriction: restriction,
      ifRestrictedExecuteInstead: ifRestrictedExecuteInstead,
      includeLastResultInCommandResults: includeLastResultInCommandResults,
      noReturnValue: false,
      errorFilter: errorFilter,
      notifyOnlyWhenValueChanges: notifyOnlyWhenValueChanges,
      debugName: debugName,
      noParamValue: false,
      undoOnExecutionFailure: undoOnExecutionFailure,
    );
  }

  /// Calls the wrapped handler function with an optional input parameter
  void execute([TParam? param]);

  /// This makes Command a callable class, so instead of `myCommand.execute()`
  /// you can write `myCommand()`
  void call([TParam? param]) => execute(param);

  final ExecuteInsteadHandler<TParam>? _ifRestrictedExecuteInstead;

  /// emits [CommandResult<TResult>] the combined state of the command, which is
  /// often easier in combination with Flutter's `ValueListenableBuilder`
  /// because you have all state information at one place.
  ValueListenable<CommandResult<TParam?, TResult>> get results =>
      _commandResult;

  /// `ValueListenable`  that changes its value on any change of the execution
  /// state change of the command
  ValueListenable<bool> get isExecuting => _isExecuting;

  /// `ValueListenable<bool>` that changes its value on any change of the current
  /// executability state of the command. Meaning if the command can be executed or not.
  /// This will issue `false` while the command executes, but also if the command
  /// receives a `true` from the [restriction] `ValueListenable` that you can pass when
  /// creating the Command.
  /// its value is `!restriction.value && !isExecuting.value`
  ValueListenable<bool> get canExecute => _canExecute;

  /// `ValueListenable<CommandError>` that reflects the Error State of the command
  /// if the wrapped function throws an error, its value is set to the error is
  /// wrapped in an `CommandError`
  ///
  @Deprecated('use errors instead')
  ValueListenable<CommandError?> get thrownExceptions => _errors;

  /// `ValueListenable<CommandError>` that reflects the Error State of the command
  /// if the wrapped function throws an error, its value is set to the error is
  /// wrapped in an `CommandError`
  ///
  ValueListenable<CommandError?> get errors => _errors;

  /// clears the error state of the command. This will not trigger any listeners
  void clearErrors() {
    _errors.value = null;
    _errors.notifyListeners();
  }

  /// optional hander that will get called on any exception that happens inside
  /// any Command of the app. Ideal for logging.
  /// the [debugName] of the Command that was responsible for the error is inside
  /// the error object.
  static void Function(CommandError<Object> error, StackTrace stackTrace)?
      globalExceptionHandler;

  /// if no individual ErrorFilter is set when creating a Command
  /// this filter is used in case of an error
  static ErrorFilter errorFilterDefault = const ErrorHandlerGlobalIfNoLocal();

  /// `AssertionErrors` are almost never wanted in production, so by default
  /// they will dirextly be rethrown, so that they are found early in development
  /// In case you want them to be handled like any other error, meaning
  /// an ErrorFilter will decide what should happen, set this to false.
  static bool assertionsAlwaysThrow = true;

  // if the function that is wrapped by the command throws an exception, it's
  // it's sometime s not easy to understand where the execption originated,
  // Escpecially if you used an Errrorfilter that swallows possible exceptions.
  // by setting this to true, the Command will directly rethrow any exception
  // so that you can get a helpfult stacktrace.
  // works only in debug mode
  static bool debugErrorsThrowAlways = false;

  /// optional handler that will get called on all `Command` executions if the Command
  /// has a set debugName.
  /// [commandName] the [debugName] of the Command
  static void Function(String? commandName, CommandResult result)?
      loggingHandler;

  /// as we don't want that anyone changes the values of these ValueNotifiers
  /// properties we make them private and only publish their `ValueListenable`
  /// interface via getters.
  late CustomValueNotifier<CommandResult<TParam?, TResult>> _commandResult;
  final CustomValueNotifier<bool> _isExecuting =
      CustomValueNotifier<bool>(false, asyncNotification: true);
  late ValueNotifier<bool> _canExecute;
  late final ValueListenable<bool>? _restriction;
  final CustomValueNotifier<CommandError<TParam?>?> _errors =
      CustomValueNotifier<CommandError<TParam?>?>(
    null,
    mode: CustomNotifierMode.manual,
  );

  /// If you don't need a command any longer it is a good practise to
  /// dispose it to make sure all registered notification handlers are remove to
  /// prevent memory leaks
  @override
  void dispose() {
    _commandResult.dispose();
    _canExecute.dispose();
    _isExecuting.dispose();
    _errors.dispose();
    if (!(_futureCompleter?.isCompleted ?? true)) {
      _futureCompleter!.complete(null);
      _futureCompleter = null;
    }

    super.dispose();
  }

  /// Flag that we always should include the last successful value in `CommandResult`
  /// for isExecuting or error states
  final bool _includeLastResultInCommandResults;

  ///Flag to signal the wrapped command has no return value which means
  ///`notifyListener` has to be called directly
  final bool _noReturnValue;

  ///Flag to signal the wrapped command expects not parameter value
  final bool _noParamValue;

  final ErrorFilter _errorFilter;

  /// optional Name that is included in log messages.
  final String? _debugName;

  Completer<TResult>? _futureCompleter;

  /// Executes an async Command and returns a Future that completes as soon as
  /// the Command completes. This is especially useful if you use a
  /// RefreshIndicator
  Future<TResult> executeWithFuture([TParam? param]) {
    assert(
      this is CommandAsync || this is UndoableCommand,
      'executeWithFuture can\t be used with synchronous Commands',
    );
    if (_futureCompleter != null && !_futureCompleter!.isCompleted) {
      return _futureCompleter!.future;
    }
    _futureCompleter = Completer<TResult>();

    execute(param);
    return _futureCompleter!.future;
  }

  /// Returns a the result of one of three builders depending on the current state
  /// of the Command. This function won't trigger a rebuild if the command changes states
  /// so it should be used together with get_it_mixin, provider, flutter_hooks and the like.
  Widget toWidget({
    required Widget Function(TResult lastResult, TParam? param) onResult,
    Widget Function(TResult lastResult, TParam? param)? whileExecuting,
    Widget Function(Object? error, TParam? param)? onError,
  }) {
    if (_commandResult.value.hasError) {
      return onError?.call(
            _commandResult.value.error,
            _commandResult.value.paramData,
          ) ??
          const SizedBox();
    }
    if (isExecuting.value) {
      return whileExecuting?.call(value, _commandResult.value.paramData) ??
          const SizedBox();
    }
    return onResult(value, _commandResult.value.paramData);
  }

  void _handleError(TParam? param, Object error, StackTrace stackTrace) {
    var errorReaction = _errorFilter.filter(error, stackTrace);
    if (errorReaction == ErrorReaction.defaultHandler) {
      errorReaction = errorFilterDefault.filter(error, stackTrace);
    }
    switch (errorReaction) {
      case ErrorReaction.none:
        return;
      case ErrorReaction.throwException:
        Error.throwWithStackTrace(error, stackTrace);
      case ErrorReaction.globalHandler:
        assert(
          globalExceptionHandler != null,
          'Errorfilter returned ErrorReaction.globalHandler, but no global handler is registered',
        );
        globalExceptionHandler!(
          CommandError(param, error, commandName: _debugName),
          stackTrace,
        );
        break;
      case ErrorReaction.localHandler:
        assert(
          _commandResult.listenerCount >= 3 || _errors.hasListeners,
          'ErrorFilter returned ErrorReaction.localHandler, but there are no listeners on errors or .result',
        );
        _commandResult.value = CommandResult<TParam, TResult>(
          param,
          _includeLastResultInCommandResults ? value : null,
          error,
          false,
        );
        break;
      case ErrorReaction.localAndGlobalHandler:
        assert(
          _commandResult.listenerCount >= 3 || _errors.hasListeners,
          'ErrorFilter returned ErrorReaction.localAndGlobalHandler, but there are no listeners on errors or .result',
        );
        assert(
          globalExceptionHandler != null,
          'Errorfilter returned ErrorReaction.localAndgloBalHandler, but no global handler is registered',
        );
        _commandResult.value = CommandResult<TParam, TResult>(
          param,
          _includeLastResultInCommandResults ? value : null,
          error,
          false,
        );
        globalExceptionHandler!(
          CommandError(param, error, commandName: _debugName),
          stackTrace,
        );
        break;
      case ErrorReaction.firstLocalThenGlobalHandler:
        if (_commandResult.listenerCount < 3 && !_errors.hasListeners) {
          assert(
            globalExceptionHandler != null,
            'Errorfilter returned ErrorReaction.globalIfNoLocalHandler, but no global handler is registered',
          );

          /// we have no external listeners on [results] or [errors]
          Command.globalExceptionHandler?.call(
            CommandError(param, error, commandName: _debugName),
            stackTrace,
          );
        } else {
          _commandResult.value = CommandResult<TParam, TResult>(
            param,
            _includeLastResultInCommandResults ? value : null,
            error,
            false,
          );
        }
        break;
      case ErrorReaction.noHandlersThrowException:
        if (_commandResult.listenerCount < 3 &&
            !_errors.hasListeners &&
            globalExceptionHandler == null) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        if (globalExceptionHandler != null) {
          Command.globalExceptionHandler?.call(
            CommandError(param, error, commandName: _debugName),
            stackTrace,
          );
        }
        if (_commandResult.listenerCount >= 3 || _errors.hasListeners) {
          _commandResult.value = CommandResult<TParam, TResult>(
            param,
            _includeLastResultInCommandResults ? value : null,
            error,
            false,
          );
        }
        break;
      case ErrorReaction.throwIfNoLocalHandler:
        if (_commandResult.listenerCount < 3 && !_errors.hasListeners) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        _commandResult.value = CommandResult<TParam, TResult>(
          param,
          _includeLastResultInCommandResults ? value : null,
          error,
          false,
        );
        break;
      case ErrorReaction.defaultHandler:
        assert(false,
            'ErrorReaction.defaultHandler is not a valid return for the DefaultErrorFilter');
    }
    _futureCompleter?.completeError(error, stackTrace);
    _futureCompleter = null;
  }
}

class CommandSync<TParam, TResult> extends Command<TParam, TResult> {
  final TResult Function(TParam)? _func;
  final TResult Function()? _funcNoParam;

  @override
  ValueListenable<bool> get isExecuting {
    assert(false, "isExecuting isn't supported by synchronous commands");
    return ValueNotifier<bool>(false);
  }

  CommandSync({
    TResult Function(TParam)? func,
    TResult Function()? funcNoParam,
    required super.initialValue,
    required super.restriction,
    required super.ifRestrictedExecuteInstead,
    required super.includeLastResultInCommandResults,
    required super.noReturnValue,
    required super.errorFilter,
    required super.notifyOnlyWhenValueChanges,
    required super.debugName,
    required super.noParamValue,
  })  : _func = func,
        _funcNoParam = funcNoParam;

  @override
  void execute([TParam? param]) {
    if (_restriction?.value == true) {
      _ifRestrictedExecuteInstead?.call(param);
      return;
    }
    if (!_canExecute.value) {
      return;
    }
    _errors.value = null;
    try {
      TResult result;
      if (_noParamValue) {
        assert(_funcNoParam != null);
        result = _funcNoParam!();
      } else {
        assert(_func != null);
        assert(
          param != null || null is TParam,
          'You passed a null value to the command ${_debugName ?? ''} that has a non-nullable type as TParam',
        );
        result = _func!(param as TParam);
      }
      if (!_noReturnValue) {
        _commandResult.value =
            CommandResult<TParam, TResult>(param, result, null, false);
        value = result;
      } else {
        notifyListeners();
      }
      _futureCompleter?.complete(result);
      _futureCompleter = null;
    } catch (error, stacktrace) {
      if (Command.assertionsAlwaysThrow && error is AssertionError) rethrow;

      if (kDebugMode && Command.debugErrorsThrowAlways) {
        rethrow;
      }

      _handleError(param, error, stacktrace);
    } finally {
      if (_debugName != null) {
        Command.loggingHandler?.call(_debugName, _commandResult.value);
      }
    }
  }
}

class CommandAsync<TParam, TResult> extends Command<TParam, TResult> {
  final Future<TResult> Function(TParam)? _func;
  final Future<TResult> Function()? _funcNoParam;

  CommandAsync({
    Future<TResult> Function(TParam)? func,
    Future<TResult> Function()? funcNoParam,
    required super.initialValue,
    required super.restriction,
    required super.ifRestrictedExecuteInstead,
    required super.includeLastResultInCommandResults,
    required super.noReturnValue,
    required super.errorFilter,
    required super.notifyOnlyWhenValueChanges,
    required super.debugName,
    required super.noParamValue,
  })  : _func = func,
        _funcNoParam = funcNoParam;

  @override
  // ignore: avoid_void_async
  void execute([TParam? param]) async {
    if (_restriction?.value == true) {
      _ifRestrictedExecuteInstead?.call(param);
      return;
    }
    if (!_canExecute.value) {
      return;
    }

    if (_isExecuting.value) {
      return;
    } else {
      _isExecuting.value = true;
    }

    _errors.value = null; // this will not trigger the listeners

    _commandResult.value = CommandResult<TParam, TResult>(
      param,
      _includeLastResultInCommandResults ? value : null,
      null,
      true,
    );

    /// give the async notifications a chance to propagate
    await Future<void>.delayed(Duration.zero);

    try {
      TResult result;
      if (_noParamValue) {
        assert(_funcNoParam != null);
        result = await _funcNoParam!();
      } else {
        assert(_func != null);
        assert(
          param != null || null is TParam,
          'You passed a null value to the command ${_debugName ?? ''} that has a non-nullable type as TParam',
        );
        result = await _func!(param as TParam);
      }
      _commandResult.value =
          CommandResult<TParam, TResult>(param, result, null, false);
      if (!_noReturnValue) {
        value = result;
      } else {
        notifyListeners();
      }
      _futureCompleter?.complete(result);
      _futureCompleter = null;
    } catch (error, stacktrace) {
      if (Command.assertionsAlwaysThrow && error is AssertionError) rethrow;

      if (kDebugMode && Command.debugErrorsThrowAlways) {
        rethrow;
      }
      _handleError(param, error, stacktrace);
    } finally {
      _isExecuting.value = false;

      /// give the async notifications a chance to propagate
      await Future<void>.delayed(Duration.zero);
      Command.loggingHandler?.call(_debugName, _commandResult.value);
    }
  }
}

/// `MockCommand` allows you to easily mock an Command for your Unit and UI tests
/// Mocking a command with `mockito` https://pub.dartlang.org/packages/mockito has its limitations.
class MockCommand<TParam, TResult> extends Command<TParam, TResult?> {
  List<CommandResult<TParam, TResult>>? returnValuesForNextExecute;

  /// the last value that was passed when execute or the command directly was called
  TParam? lastPassedValueToExecute;

  /// Number of times execute or the command directly was called
  int executionCount = 0;

  /// constructor that can take an optional `ValueListenable` to control if the command can be execute
  /// if the wrapped function has `void` as return type [noResult] has to be `true`
  MockCommand({
    required super.initialValue,
    super.noParamValue = false,
    super.noReturnValue = false,
    super.restriction,
    super.ifRestrictedExecuteInstead,
    super.includeLastResultInCommandResults = false,
    super.errorFilter,
    super.notifyOnlyWhenValueChanges = false,
    super.debugName,
  }) {
    _commandResult
        .where((result) => result.hasData)
        .listen((result, _) => value = result.data);
  }

  /// to be able to simulate any output of the command when it is called you can here queue the output data for the next execution call
  // ignore: use_setters_to_change_properties
  void queueResultsForNextExecuteCall(
    List<CommandResult<TParam, TResult>> values,
  ) {
    returnValuesForNextExecute = values;
  }

  /// Can either be called directly or by calling the object itself because Commands are callable classes
  /// Will increase [executionCount] and assign [lastPassedValueToExecute] the value of [param]
  /// If you have queued a result with [queueResultsForNextExecuteCall] it will be copies tho the output stream.
  /// [isExecuting], [canExecute] and [results] will work as with a real command.
  @override
  void execute([TParam? param]) {
    if (_restriction?.value == true) {
      _ifRestrictedExecuteInstead?.call(param);
      return;
    }
    if (!_canExecute.value) {
      return;
    }

    _isExecuting.value = true;
    executionCount++;
    lastPassedValueToExecute = param;
    // ignore: avoid_print
    print('Called Execute');
    if (returnValuesForNextExecute != null) {
      returnValuesForNextExecute!.map(
        (entry) {
          if ((entry.isExecuting || entry.hasError) &&
              _includeLastResultInCommandResults) {
            return CommandResult<TParam, TResult>(
              param,
              value,
              entry.error,
              entry.isExecuting,
            );
          }
          return entry;
        },
      ).forEach((x) => _commandResult.value = x);
    } else if (_noReturnValue) {
      notifyListeners();
    } else {
      // ignore: avoid_print
      print('No values for execution queued');
    }
    _isExecuting.value = false;
  }

  /// For a more fine grained control to simulate the different states of an [Command]
  /// there are these functions
  /// `startExecution` will issue a [CommandResult] with
  /// data: null
  /// error: null
  /// isExecuting : true
  void startExecution([TParam? param]) {
    lastPassedValueToExecute = param;
    _commandResult.value = CommandResult<TParam, TResult>(
      param,
      _includeLastResultInCommandResults ? value : null,
      null,
      true,
    );
    _isExecuting.value = true;
  }

  /// `endExecutionWithData` will issue a [CommandResult] with
  /// data: [data]
  /// error: null
  /// isExecuting : false
  void endExecutionWithData(TResult data) {
    value = data;
    _commandResult.value = CommandResult<TParam, TResult>(
      lastPassedValueToExecute,
      data,
      null,
      false,
    );
    if (_debugName != null) {
      Command.loggingHandler?.call(_debugName, _commandResult.value);
    }
    _isExecuting.value = false;
  }

  /// `endExecutionWithData` will issue a [CommandResult] with
  /// data: null
  /// error: Exception([message])
  /// isExecuting : false
  void endExecutionWithError(String message) {
    _handleError(
      lastPassedValueToExecute,
      Exception(message),
      StackTrace.current,
    );
    _isExecuting.value = false;
    if (_debugName != null) {
      Command.loggingHandler?.call(_debugName, _commandResult.value);
    }
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
      false,
    );
    if (_debugName != null) {
      Command.loggingHandler?.call(_debugName, _commandResult.value);
    }
    _isExecuting.value = false;
  }
}

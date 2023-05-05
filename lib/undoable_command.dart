part of './flutter_command.dart';

class UndoStack<E> {
  final _list = <E>[];

  void push(E undoData) => _list.add(undoData);

  E pop() => _list.removeLast();

  bool get isEmpty => _list.isEmpty;
  bool get isNotEmpty => _list.isNotEmpty;

  @override
  String toString() => _list.toString();
}

/// In case that an undo of a command fails, this exception wraps the error to
/// distinguish it from other exceptions.
class UndoException implements Exception {
  final Object error;

  UndoException(this.error);

  @override
  String toString() => error.toString();
}

/// Type signature of a function that is called when the last command call
///  should be undone.
///
/// The function is called with the reason why the command was undone and
/// a stack that was passed before to the command's `execute` method,
/// by that the commands `execute` method can store state that is needed to undo
/// its last execution.
///
/// If [reason] is not `null`, the command is being undone because of an Execption in the
/// command function given that [undoOnFailure] is `true`.
/// If it is `null` this function is called by intentionally by calling [undo] on the
/// command manually.
/// If the function has a return value, it will be assigned to the command's result
/// and value.
typedef UndoFn<TUndoState, TResult> = FutureOr<TResult> Function(
  UndoStack<TUndoState> undoStack,
  Object? reason,
);

class UndoableCommand<TParam, TResult, TUndoState>
    extends Command<TParam, TResult> {
  final Future<TResult> Function(TParam, UndoStack<TUndoState>)? _func;
  final Future<TResult> Function(UndoStack<TUndoState>)? _funcNoParam;
  final UndoFn<TUndoState, TResult> _undo;
  final UndoStack<TUndoState> _undoStack = UndoStack<TUndoState>();
  ListenableSubscription? _exceptionSubscription;

  UndoableCommand({
    Future<TResult> Function(TParam, UndoStack<TUndoState>)? func,
    Future<TResult> Function(UndoStack<TUndoState>)? funcNoParam,
    required UndoFn<TUndoState, TResult> undo,
    required super.initialValue,
    required super.restriction,
    required super.ifRestrictedExecuteInstead,
    required bool undoOnExecutionFailure,
    required super.includeLastResultInCommandResults,
    required super.noReturnValue,
    required super.catchAlways,
    required super.notifyOnlyWhenValueChanges,
    required super.debugName,
    required super.noParamValue,
  })  : _func = func,
        _funcNoParam = funcNoParam,
        _undo = undo,
        _undoOnExecutionFailure = undoOnExecutionFailure {
    if (undoOnExecutionFailure) {
      _exceptionSubscription =
          _thrownExceptions.where((ex) => ex is! UndoException).listen((ex, _) {
        _undo(_undoStack, ex);
      });
    }
  }

  final bool _undoOnExecutionFailure;

  @override
  void dispose() {
    _exceptionSubscription?.cancel();
    super.dispose();
  }

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

    _thrownExceptions.value = null; // this will not trigger the listeners

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
        result = await _funcNoParam!(_undoStack);
      } else {
        assert(_func != null);
        assert(
          param != null || null is TParam,
          'You passed a null value to the command ${_debugName ?? ''} that has a non-nullable type as TParam',
        );
        result = await _func!(param as TParam, _undoStack);
      }
      _commandResult.value =
          CommandResult<TParam, TResult>(param, result, null, false);
      if (!_noReturnValue) {
        value = result;
      } else {
        notifyListeners();
      }
      _futureCompleter?.complete(result);
    } catch (error) {
      if (error is AssertionError) rethrow;
      _commandResult.value = CommandResult<TParam, TResult>(
        param,
        _includeLastResultInCommandResults ? value : null,
        error,
        false,
      );
      if (_commandResult.listenerCount < 3 && !_thrownExceptions.hasListeners) {
        /// we have no external listeners on [results] or [thrownExceptions]
        Command.globalExceptionHandler
            ?.call(_debugName, CommandError(param, error));
        _futureCompleter?.completeError(error);

        if (!_catchAlways) {
          rethrow;
        }
      }
    } finally {
      _isExecuting.value = false;

      /// give the async notifications a chance to propagate
      await Future<void>.delayed(Duration.zero);
      Command.loggingHandler?.call(_debugName, _commandResult.value);
    }
  }

  /// Undoes the last execution of this command.
  /// If [reason] is not `null`, the command is being undone because of an Execption in the
  /// command function given that [undoOnFailure] is `true`.
  FutureOr undo() async {
    assert(_undoStack.isNotEmpty);
    try {
      TResult result;
      result = await _funcNoParam!(_undoStack);

      _commandResult.value =
          CommandResult<TParam, TResult>(null, result, null, false);
      if (!_noReturnValue) {
        value = result;
      } else {
        notifyListeners();
      }
    } catch (error) {
      if (error is AssertionError) rethrow;
      _commandResult.value = CommandResult<TParam, TResult>(
        null,
        _includeLastResultInCommandResults ? value : null,
        UndoException(error),
        false,
      );
      if (_commandResult.listenerCount < 3 && !_thrownExceptions.hasListeners ||
          _undoOnExecutionFailure) {
        /// we have no external listeners on [results] or [thrownExceptions]
        /// if we undo automatically on execution failure, we also want to notify the global exception handler
        Command.globalExceptionHandler
            ?.call(_debugName, CommandError(null, UndoException(error)));
        _futureCompleter?.completeError(UndoException(error));

        if (!_catchAlways) {
          throw UndoException(error);
        }
      }
    }
  }
}

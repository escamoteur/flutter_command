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
  final UndoFn<TUndoState, TResult> _undofunc;
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
    required super.errorFilter,
    required super.notifyOnlyWhenValueChanges,
    required super.debugName,
    required super.noParamValue,
  })  : _func = func,
        _funcNoParam = funcNoParam,
        _undofunc = undo,
        _undoOnExecutionFailure = undoOnExecutionFailure {}

  final bool _undoOnExecutionFailure;

  @override
  void dispose() {
    _exceptionSubscription?.cancel();
    super.dispose();
  }

  @override
  // ignore: avoid_void_async
  Future<void> _execute([TParam? param]) async {
    TResult result;
    if (_noParamValue) {
      assert(_funcNoParam != null);
      final completer = Completer<TResult>();
      Chain.capture(
        () => _funcNoParam!(_undoStack).then(completer.complete),
        onError: completer.completeError,
        when: false,
      );
      result = await completer.future;
    } else {
      assert(_func != null);
      assert(
        param != null || null is TParam,
        'You passed a null value to the command ${_debugName ?? ''} that has a non-nullable type as TParam',
      );
      final completer = Completer<TResult>();
      Chain.capture(
        () => _func!(param as TParam, _undoStack).then(completer.complete),
        onError: completer.completeError,
        when: false,
      );
      result = await completer.future;
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
  }

  /// Undoes the last execution of this command.By calling the
  /// undo function that was passed when creating the command
  void undo() => _undo();

  FutureOr _undo([Object? reason]) async {
    assert(_undoStack.isNotEmpty);
    try {
      TResult result;
      _isExecuting.value = true;
      final completer = Completer<TResult>();
      Chain.capture(
        () {
          final r = _undofunc(_undoStack, reason);
          if (r is Future<TResult>) {
            r.then(completer.complete);
          } else {
            completer.complete(r);
          }
        },
        onError: completer.completeError,
        when: false,
      );
      result = await completer.future;

      _commandResult.value = CommandResult<TParam, TResult>(
        null,
        result,
        reason ?? UndoException("manual undo"),
        false,
      );
      if (!_noReturnValue) {
        value = result;
      } else {
        notifyListeners();
      }
    } catch (error, stacktrace) {
      StackTrace chain = Command.detailedStackTraces
          ? _improveStacktrace(stacktrace).terse
          : stacktrace;
      if (Command.assertionsAlwaysThrow && error is AssertionError) {
        Error.throwWithStackTrace(error, chain);
      }

      // ignore: deprecated_member_use_from_same_package
      if (kDebugMode && Command.debugErrorsThrowAlways) {
        Error.throwWithStackTrace(error, chain);
      }

      if (Command.reportAllExceptions) {
        Command.globalExceptionHandler?.call(
          CommandError(null, error, command: this, commandName: _debugName),
          chain,
        );
      }
      _handleError(null, UndoException(error), chain);
    } finally {
      _isExecuting.value = false;
      if (_debugName != null) {
        Command.loggingHandler
            ?.call('undo + $_debugName', _commandResult.value);
      }
    }
  }
}

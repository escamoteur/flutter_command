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
    extends CommandAsync<TParam, TResult> {
  final Future<TResult> Function(TParam, UndoStack<TUndoState>)? _undoableFunc;
  final Future<TResult> Function(UndoStack<TUndoState>)? _undoableFuncNoParam;
  final UndoFn<TUndoState, TResult> _undofunc;
  final UndoStack<TUndoState> _undoStack = UndoStack<TUndoState>();

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
    required super.name,
    required super.noParamValue,
  })  : _undoableFunc = func,
        _undoableFuncNoParam = funcNoParam,
        _undofunc = undo,
        _undoOnExecutionFailure = undoOnExecutionFailure {
    _func = func != null ? (param) => _undoableFunc!(param, _undoStack) : null;
    _funcNoParam =
        funcNoParam != null ? () => _undoableFuncNoParam!(_undoStack) : null;
  }

  final bool _undoOnExecutionFailure;

  /// Undoes the last execution of this command.By calling the
  /// undo function that was passed when creating the command
  void undo() => _undo();

  FutureOr<void> _undo([Object? reason]) async {
    assert(_undoStack.isNotEmpty);
    try {
      TResult result;
      if (!_isDisposing) {
        _isExecuting.value = true;
      }
      if (Command.useChainCapture) {
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
          onError: (error, chain) {
            if (completer.isCompleted) {
              return;
            }
            completer.completeError(error, chain);
          },
        );
        result = await completer.future;
      } else {
        result = await _undofunc(_undoStack, reason);
      }
      if (_isDisposing) {
        return null;
      }
      _commandResult.value = CommandResult<TParam, TResult>(
        null,
        result,
        reason ?? UndoException("manual undo"),
        false,
        isUndoValue: true,
      );
      if (!_noReturnValue) {
        value = result;
      } else {
        notifyListeners();
      }
    } catch (error, stacktrace) {
      StackTrace chain = _mandatoryErrorHandling(stacktrace, error, null);
      _handleErrorFiltered(null, UndoException(error), chain);
    } finally {
      if (!_isDisposing) {
        _isExecuting.value = false;
      }
      if (_name != null) {
        Command.loggingHandler?.call('undo + $_name', _commandResult.value);
      }
    }
  }
}

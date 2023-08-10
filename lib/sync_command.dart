part of './flutter_command.dart';

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

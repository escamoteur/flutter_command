part of './flutter_command.dart';

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

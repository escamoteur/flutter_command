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
  Future<void> _execute([TParam? param]) async {
    TResult result;
    if (_noParamValue) {
      assert(_funcNoParam != null);
      final completer = Completer<TResult>();
      Chain.capture(
        () => _funcNoParam!().then(completer.complete),
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
        () => _func!(param as TParam).then(completer.complete),
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
}

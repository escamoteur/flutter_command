part of './flutter_command.dart';

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

  @override
  Future<void> _execute([TParam? param]) async {
    // TODO: implement _execute
  }
}

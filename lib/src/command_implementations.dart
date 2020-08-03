import 'package:flutter_command/flutter_command.dart';

class CommandSync<TParam, TResult> extends Command<TParam, TResult> {
  Func1<TParam, TResult> _func;

  factory CommandSync(
      Func1<TParam, TResult> func,
      Stream<bool> canExecute,
      bool emitInitialCommandResult,
      bool emitLastResult,
      bool emitsLastValueToNewSubscriptions,
      TResult initialLastResult) {
    return CommandSync._(
        func,
        emitsLastValueToNewSubscriptions || emitInitialCommandResult
            ? BehaviorSubject<TResult>()
            : PublishSubject<TResult>(),
        canExecute,
        emitLastResult,
        emitsLastValueToNewSubscriptions || emitInitialCommandResult,
        emitInitialCommandResult,
        initialLastResult);
  }

  CommandSync._(
      Func1<TParam, TResult> func,
      Subject<TResult> subject,
      Stream<bool> canExecute,
      bool buffer,
      bool isBehaviourSubject,
      bool emitInitialCommandResult,
      TResult initialLastResult)
      : _func = func,
        super(subject, canExecute, buffer, isBehaviourSubject,
            initialLastResult) {
    if (emitInitialCommandResult) {
      _commandResultsSubject.add(CommandResult<TResult>(null, null, false));
    }
  }

  @override
  void execute([TParam param]) {
    if (!_canExecute) {
      return;
    }

    if (_isRunning) {
      return;
    } else {
      _isRunning = true;
      _canExecuteSubject.add(false);
    }

    _commandResultsSubject.add(CommandResult<TResult>(
        _emitLastResult ? lastResult : null, null, true));

    try {
      final result = _func(param);
      lastResult = result;
      _commandResultsSubject.add(CommandResult<TResult>(result, null, false));
      _resultsSubject.add(result);
    } catch (error) {
      if (throwExceptions) {
        _resultsSubject.addError(error);
        _commandResultsSubject.addError(error);
        _isExecutingSubject.add(
            false); // Has to be done because in this case no command result is queued
        return;
      }

      _commandResultsSubject.add(CommandResult<TResult>(
          _emitLastResult ? lastResult : null, error, false));
    } finally {
      _isRunning = false;
      _canExecute = !_executionLocked;
      _canExecuteSubject.add(!_executionLocked);
    }
  }
}

class CommandAsync<TParam, TResult> extends Command<TParam, TResult> {
  AsyncFunc1<TParam, TResult> _func;

  CommandAsync._(
      AsyncFunc1<TParam, TResult> func,
      Subject<TResult> subject,
      Stream<bool> canExecute,
      bool emitLastResult,
      bool isBehaviourSubject,
      bool emitInitialCommandResult,
      TResult initialLastResult)
      : _func = func,
        super(subject, canExecute, emitLastResult, isBehaviourSubject,
            initialLastResult) {
    if (emitInitialCommandResult) {
      _commandResultsSubject.add(CommandResult<TResult>(null, null, false));
    }
  }

  factory CommandAsync(
      AsyncFunc1<TParam, TResult> func,
      Stream<bool> canExecute,
      bool emitInitialCommandResult,
      bool emitLastResult,
      bool emitsLastValueToNewSubscriptions,
      TResult initialLastResult) {
    return CommandAsync._(
        func,
        emitsLastValueToNewSubscriptions || emitInitialCommandResult
            ? BehaviorSubject<TResult>()
            : PublishSubject<TResult>(),
        canExecute,
        emitLastResult,
        emitsLastValueToNewSubscriptions || emitInitialCommandResult,
        emitInitialCommandResult,
        initialLastResult);
  }

  @override
  execute([TParam param]) {
    //print("************ Execute***** canExecute: $_canExecute ***** isExecuting: $_isRunning");

    if (!_canExecute) {
      return;
    }

    if (_isRunning) {
      return;
    } else {
      _isRunning = true;
      _canExecuteSubject.add(false);
    }

    _commandResultsSubject.add(CommandResult<TResult>(
        _emitLastResult ? lastResult : null, null, true));

    _func(param).asStream().handleError((error) {
      if (throwExceptions) {
        _resultsSubject.addError(error);
        _commandResultsSubject.addError(error);
        _isRunning = false;
        _isExecutingSubject.add(
            false); // Has to be done because in this case no command result is queued
        _canExecute = !_executionLocked;
        _canExecuteSubject.add(!_executionLocked);
        return;
      }

      _commandResultsSubject.add(CommandResult<TResult>(
          _emitLastResult ? lastResult : null, error, false));
      _isRunning = false;
      _canExecute = !_executionLocked;
      _canExecuteSubject.add(!_executionLocked);
    }).listen((result) {
      _commandResultsSubject.add(CommandResult<TResult>(result, null, false));
      lastResult = result;
      _resultsSubject.add(result);
      _isRunning = false;
      _canExecute = !_executionLocked;
      _canExecuteSubject.add(!_executionLocked);
    });
  }
}

class CommandStream<TParam, TResult> extends Command<TParam, TResult> {
  StreamProvider<TParam, TResult> _observableProvider;

  StreamSubscription<Notification<TResult>> _inputStreamSubscription;

  CommandStream._(
      StreamProvider<TParam, TResult> provider,
      Subject<TResult> subject,
      Stream<bool> canExecute,
      bool emitLastResult,
      bool isBehaviourSubject,
      bool emitInitialCommandResult,
      TResult initialLastResult)
      : _observableProvider = provider,
        super(subject, canExecute, emitLastResult, isBehaviourSubject,
            initialLastResult) {
    if (emitInitialCommandResult) {
      _commandResultsSubject.add(CommandResult<TResult>(null, null, false));
    }
  }

  factory CommandStream(
      StreamProvider<TParam, TResult> provider,
      Stream<bool> canExecute,
      bool emitInitialCommandResult,
      bool emitLastResult,
      bool emitsLastValueToNewSubscriptions,
      TResult initialLastResult) {
    return CommandStream._(
        provider,
        emitsLastValueToNewSubscriptions || emitInitialCommandResult
            ? BehaviorSubject<TResult>()
            : PublishSubject<TResult>(),
        canExecute,
        emitLastResult,
        emitsLastValueToNewSubscriptions || emitInitialCommandResult,
        emitInitialCommandResult,
        initialLastResult);
  }

  @override
  execute([TParam param]) {
    if (!_canExecute) {
      return;
    }

    if (_isRunning) {
      return;
    } else {
      _isRunning = true;
      _canExecuteSubject.add(false);
    }

    _commandResultsSubject.add(CommandResult<TResult>(
        _emitLastResult ? lastResult : null, null, true));

    var inputStream = _observableProvider(param);

    _inputStreamSubscription = inputStream.materialize().listen(
      (notification) {
        if (notification.isOnData) {
          _resultsSubject.add(notification.value);
          _commandResultsSubject
              .add(CommandResult(notification.value, null, true));
          lastResult = notification.value;
        } else if (notification.isOnError) {
          if (throwExceptions) {
            _resultsSubject.addError(notification.error);
            _commandResultsSubject.addError(notification.error);
          } else {
            _commandResultsSubject
                .add(CommandResult<TResult>(null, notification.error, false));
          }
        } else if (notification.isOnDone) {
          _commandResultsSubject.add(CommandResult(lastResult, null, false));
          _isRunning = false;
          _canExecuteSubject.add(!_executionLocked);
        }
      },
      onError: (error) {
        print(error);
      },
    );
  }

  @override
  void dispose() {
    _inputStreamSubscription?.cancel();
    super.dispose();
  }
}

/// `MockCommand` allows you to easily mock an Command for your Unit and UI tests
/// Mocking a command with `mockito` https://pub.dartlang.org/packages/mockito has its limitations.
class MockCommand<TParam, TResult> extends Command<TParam, TResult> {
  List<CommandResult<TResult>> returnValuesForNextExecute;

  /// the last value that was passed when execute or the command directly was called
  TParam lastPassedValueToExecute;

  /// Number of times execute or the command directly was called
  int executionCount = 0;

  /// Factory constructor that can take an optional observable to control if the command can be executet
  factory MockCommand(
      {Stream<bool> canExecute,
      bool emitInitialCommandResult = false,
      bool emitLastResult = false,
      bool emitsLastValueToNewSubscriptions = false,
      TResult initialLastResult}) {
    return MockCommand._(
        emitsLastValueToNewSubscriptions
            ? BehaviorSubject<TResult>()
            : PublishSubject<TResult>(),
        canExecute,
        emitLastResult,
        false,
        emitInitialCommandResult,
        initialLastResult);
  }

  MockCommand._(
      Subject<TResult> subject,
      Stream<bool> canExecute,
      bool emitLastResult,
      bool isBehaviourSubject,
      bool emitInitialCommandResult,
      TResult initialLastResult)
      : super(subject, canExecute, emitLastResult, isBehaviourSubject,
            initialLastResult) {
    if (emitInitialCommandResult) {
      _commandResultsSubject.add(CommandResult<TResult>(null, null, false));
    }
    _commandResultsSubject
        .where((result) => result.hasData)
        .listen((result) => _resultsSubject.add(result.data));
  }

  /// to be able to simulate any output of the command when it is called you can here queue the output data for the next exeution call
  queueResultsForNextExecuteCall(List<CommandResult<TResult>> values) {
    returnValuesForNextExecute = values;
  }

  /// Can either be called directly or by calling the object itself because Commands are callable classes
  /// Will increase [executionCount] and assign [lastPassedValueToExecute] the value of [param]
  /// If you have queued a result with [queueResultsForNextExecuteCall] it will be copies tho the output stream.
  /// [isExecuting], [canExecute] and [results] will work as with a real command.
  @override
  execute([TParam param]) {
    _canExecuteSubject.add(false);
    executionCount++;
    lastPassedValueToExecute = param;
    print("Called Execute");
    if (returnValuesForNextExecute != null) {
      _commandResultsSubject.addStream(
        Stream<CommandResult<TResult>>.fromIterable(returnValuesForNextExecute)
            .map(
          (data) {
            if ((data.isExecuting || data.hasError) && _emitLastResult) {
              return CommandResult<TResult>(
                  lastResult, data.error, data.isExecuting);
            }
            return data;
          },
        ),
      );
    } else {
      print("No values for execution queued");
    }
    _canExecuteSubject.add(true);
  }

  /// For a more fine grained control to simulate the different states of an [Command]
  /// there are these functions
  /// `startExecution` will issue a [CommandResult] with
  /// data: null
  /// error: null
  /// isExecuting : true
  void startExecution() {
    _commandResultsSubject
        .add(CommandResult(_emitLastResult ? lastResult : null, null, true));
    _canExecuteSubject.add(false);
  }

  /// `endExecutionWithData` will issue a [CommandResult] with
  /// data: [data]
  /// error: null
  /// isExecuting : false
  void endExecutionWithData(TResult data) {
    lastResult = data;
    _commandResultsSubject.add(CommandResult<TResult>(data, null, false));
    _canExecuteSubject.add(true);
  }

  /// `endExecutionWithData` will issue a [CommandResult] with
  /// data: null
  /// error: Exeption([message])
  /// isExecuting : false
  void endExecutionWithError(String message) {
    _commandResultsSubject.add(CommandResult<TResult>(
        _emitLastResult ? lastResult : null, Exception(message), false));
    _canExecuteSubject.add(true);
  }

  /// `endExecutionNoData` will issue a [CommandResult] with
  /// data: null
  /// error: null
  /// isExecuting : false
  void endExecutionNoData() {
    _commandResultsSubject.add(CommandResult<TResult>(
        _emitLastResult ? lastResult : null, null, true));
    _canExecuteSubject.add(true);
  }
}

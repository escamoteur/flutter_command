import 'package:flutter/cupertino.dart';
import 'package:flutter_command/flutter_command.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:functional_listener/functional_listener.dart';

/// An object that can assist in representing the current state of Command while
/// testing different valueListenable of a Command. Basically a [List] with
/// initialize logic and null safe clear.
class Collector<T> {
  /// Holds a list of values being passed to this object.
  List<T> values;

  /// Initializes [values] adds the incoming [value] to it.
  call(T value) {
    values ??= <T>[];
    values.add(value);
  }

  /// Check null and clear the list.
  clear() {
    values?.clear();
  }
}

void main() {
  /// Create commonly used collector for all the valueListenable in a [Command].
  /// The collectors simply collect the values emitted by the ValueListenable
  /// into a list and keep it for comparison later.
  Collector<bool> canExecuteCollector = Collector<bool>();
  Collector<bool> isExecutingCollector = Collector<bool>();
  Collector<CommandResult> cmdResultCollector = Collector<CommandResult>();
  Collector<CommandError> thrownExceptionCollector = Collector<CommandError>();
  Collector pureResultCollector = Collector();

  /// A utility method to setup [Collector] for all the [ValueListenable] in a
  /// given command.
  void setupCollectors(Command command, {bool enablePrint = false}) {
    // Set up the collectors
    command.canExecute.listen((b, _) {
      canExecuteCollector(b);
      if (enablePrint) {
        print("Can Execute $b");
      }
    });
    command.isExecuting.listen((b, _) {
      isExecutingCollector(b);
      if (enablePrint) {
        print("Can Execute $b");
      }
    });
    command.results.listen((cmdResult, _) {
      cmdResultCollector(cmdResult);
      if (enablePrint) {
        print("Can Execute $cmdResult");
      }
    });
    command.thrownExceptions.listen((cmdError, _) {
      thrownExceptionCollector(cmdError);
      if (enablePrint) {
        print("Can Execute $cmdError");
      }
    });
    command.listen((pureResult, _) {
      pureResultCollector(pureResult);
      if (enablePrint) {
        print("Can Execute $pureResult");
      }
    });
  }

  /// clear the common collectors before each test.
  setUp(() {
    canExecuteCollector.clear();
    isExecutingCollector.clear();
    cmdResultCollector.clear();
    thrownExceptionCollector.clear();
    pureResultCollector.clear();
  });

  test('Execute simple sync action', () {
    int notificationCount = 0;
    var command = Command.createSyncNoParamNoResult(() => notificationCount++);

    expect(command.canExecute.value, true);

    expect(command.results.value,
        CommandResult<void, void>(null, null, null, false));

    command.execute();

    expect(command.canExecute.value, true);
    expect(notificationCount, 1);
  });

  test('Execute simple sync action with canExceute restriction', () async {
    final restriction = ValueNotifier<bool>(true);

    var executionCount = 0;

    final command = Command.createSyncNoParamNoResult(() => executionCount++,
        restriction: restriction);

    expect(command.canExecute.value, true);

    command.execute();

    expect(executionCount, 1);

    expect(command.canExecute.value, true);

    restriction.value = false;

    expect(command.canExecute.value, false);

    command.execute();

    expect(executionCount, 1);
  });

  test('Execute simple sync action with exception', () {
    final command = Command.createSyncNoParamNoResult(
        () => throw ArgumentError("Intentional"));

    expect(command.canExecute.value, true);
    expect(command.thrownExceptions.value, null);

    command.execute();
    expect(command.results.value.error, isInstanceOf<ArgumentError>());
    expect(command.thrownExceptions.value.error, isInstanceOf<ArgumentError>());

    expect(command.canExecute.value, true);
  });

  test('Execute simple sync action with parameter', () {
    int notificationCount = 0;
    final command = Command.createSyncNoResult<String>((x) {
      print("action: " + x.toString());
      notificationCount++;
      return null;
    });

    expect(command.canExecute.value, true);

    command.execute("Parameter");
    expect(command.results.value,
        CommandResult<String, void>('Parameter', null, null, false));
    expect(command.thrownExceptions.value, null);
    expect(notificationCount, 1);

    expect(command.canExecute.value, true);
  });

  test('Execute simple sync function without parameter', () {
    int notificationCount = 0;
    final command = Command.createSyncNoParam<String>(() {
      print("action: ");
      notificationCount++;
      return "4711";
    }, '');

    expect(command.canExecute.value, true);

    command.execute();

    expect(command.value, "4711");
    expect(command.results.value,
        CommandResult<void, String>(null, '4711', null, false));
    expect(command.thrownExceptions.value, null);
    expect(notificationCount, 1);

    expect(command.canExecute.value, true);
  });

  test('Execute simple sync function with parameter', () {
    int notificationCount = 0;
    final command = Command.createSync<String, String>((s) {
      print("action: " + s);
      notificationCount++;
      return s + s;
    }, '');

    expect(command.canExecute.value, true);

    command.execute("4711");
    expect(command.value, "47114711");

    expect(command.results.value,
        CommandResult<String, String>('4711', '47114711', null, false));
    expect(command.thrownExceptions.value, null);
    expect(notificationCount, 1);

    expect(command.canExecute.value, true);
  });

  Future<String> slowAsyncFunction(String s) async {
    // print("___Start____Action__________");
    await Future.delayed(const Duration(milliseconds: 10));
    // print("___End____Action__________");
    return s;
  }

  test('Execute simple async function with parameter', () async {
    var executionCount = 0;

    final command = Command.createAsyncNoResult<String>(
      (s) async {
        executionCount++;
        await slowAsyncFunction(s);
      },
      // restriction: setExecutionStateCommand,
    );

    // set up all the collectors for this command.
    setupCollectors(command);

    // Ensure command is not executing already.
    expect(command.isExecuting.value, false, reason: "IsExecuting before true");

    // Execute command.
    command.execute("Done");

    // Waiting till the async function has finished executing.
    await Future.delayed(Duration(milliseconds: 10));

    expect(command.isExecuting.value, false);

    expect(executionCount, 1);

    // Expected to return false, true, false
    // but somehow skips the initial state which is false.
    expect(isExecutingCollector.values, [true, false]);

    expect(canExecuteCollector.values, [false, true]);

    expect(cmdResultCollector.values, [
      CommandResult<String, void>("Done", null, null, true),
      CommandResult<String, void>("Done", null, null, false),
    ]);
  });

  test('Execute simple async function with parameter and return value',
      () async {
    var executionCount = 0;

    final command = Command.createAsync<String, String>(
      (s) async {
        executionCount++;
        return slowAsyncFunction(s);
      },
      "initialValue",
    );

    setupCollectors(command);

    expect(command.isExecuting.value, false, reason: "IsExecuting before true");

    command.execute("Done");

    // Waiting till the async function has finished executing.
    await Future.delayed(Duration(milliseconds: 10));

    expect(command.isExecuting.value, false);

    expect(executionCount, 1);

    // Expected to return false, true, false
    // but somehow skips the initial state which is false.
    expect(isExecutingCollector.values, [true, false]);

    expect(canExecuteCollector.values, [false, true]);

    expect(cmdResultCollector.values, [
      CommandResult<String, void>("Done", null, null, true),
      CommandResult<String, void>("Done", "Done", null, false),
    ]);
  });

  test('Execute simple async function call while already running', () async {
    var executionCount = 0;

    final command = Command.createAsync<String, String>(
      (s) async {
        executionCount++;
        return slowAsyncFunction(s);
      },
      "Initial Value",
    );

    setupCollectors(command);

    expect(command.isExecuting.value, false, reason: "IsExecuting before true");

    expect(command.value, "Initial Value");

    command.execute("Done");
    command.execute("Done2"); // should not execute

    await Future.delayed(Duration(milliseconds: 100));

    expect(command.isExecuting.value, false);
    expect(executionCount, 1);

    // The expectation ensures that first command execution went through and
    // second command execution didn't wen through.
    expect(cmdResultCollector.values, [
      CommandResult<String, String>("Done", null, null, true),
      CommandResult<String, String>("Done", "Done", null, false)
    ]);
  });

  test('Execute simple async function called twice with delay', () async {
    var executionCount = 0;

    final command = Command.createAsync<String, String>(
      (s) async {
        executionCount++;
        return slowAsyncFunction(s);
      },
      "Initial value",
    );

    setupCollectors(command);

    expect(command.isExecuting.value, false, reason: "IsExecuting before true");

    command.execute("Done");

    // Reuse the same command after 50 milliseconds and it should work.
    await Future.delayed(Duration(milliseconds: 50));
    command.execute("Done2");

    await Future.delayed(Duration(milliseconds: 50));
    expect(command.isExecuting.value, false);
    expect(executionCount, 2);
    expect(canExecuteCollector.values, [false, true, false, true],
        reason: "CanExecute order is wrong");
    expect(isExecutingCollector.values, [true, false, true, false],
        reason: "IsExecuting order is wrong.");
    expect(pureResultCollector.values, ["Done", "Done2"]);
    expect(cmdResultCollector.values, [
      CommandResult<String, String>("Done", null, null, true),
      CommandResult<String, String>("Done", "Done", null, false),
      CommandResult<String, String>("Done2", null, null, true),
      CommandResult<String, String>("Done2", "Done2", null, false)
    ]);
  });

  // test(
  //     'Execute simple async function called twice with delay and emitLastResult=true',
  //     () async {
  //   var executionCount = 0;

  //   final command = Command.createAsync<String, String>((s) async {
  //     executionCount++;
  //     return slowAsyncFunction(s);
  //   }, emitLastResult: true);

  //   command.canExecute.listen((b) {
  //     print("Can execute:" + b.toString();
  //   });
  //   command.isExecuting.listen((b) {
  //     print("Is executing:" + b.toString();
  //   });

  //   command.listen((s) {
  //     print("Results:" + s);
  //   });

  //   expect(command.canExecute, emitsInOrder([true, false, true, false, true]),
  //       reason: "Canexecute wrong"));
  //   expect(command.isExecuting.value ,false),
  //       reason: "IsExecuting before true"));

  //   expect(
  //       command.results,
  //       emitsInOrder([
  //         crm(null, false, true),
  //         crm("Done", false, false),
  //         crm("Done", false, true),
  //         crm("Done", false, false)
  //       ]);

  //   command.execute("Done"));
  //   await Future.delayed(Duration(milliseconds: 50);
  //   command.execute("Done")); // should not execute

  //   await Future.delayed(Duration(milliseconds: 50);

  //   expect(command.isExecuting.value ,false);
  //   expect(executionCount, 2);
  // });

  // Future<String> slowAsyncFunctionFail(String s) async {
  //   print("___Start____Action___Will throw_______"));

  //   throw Exception("Intentionally"));
  // }

  // test('async function with exception and throwExceptions==true', () async {
  //   final command =
  //       Command.createAsync<String, String>(slowAsyncFunctionFail);
  //   command.throwExceptions = true;

  //   command.listen((s) => print('Listen: $s'),
  //       onError: (e) => print('OnError:$e');

  //   expect(command.canExecute.value ,true);
  //   expect(command.isExecuting.value ,false);

  //   expect(command.results, emitsInOrder([crm(null, false, true)]);

  //   expect(command, emitsError(isException);
  //   expect(command, emitsError(isException);

  //   command.execute("Done"));

  //   expect(command.canExecute.value ,true);
  //   expect(command.isExecuting.value ,false);

  //   await Future.delayed(Duration(milliseconds: 100);

  //   command.execute("Done2"));

  //   expect(command, emitsError(isException);

  //   await Future.delayed(Duration.zero);

  //   expect(command.canExecute.value ,true);
  //   expect(command.isExecuting.value ,false);

  //   await Future.delayed(Duration(milliseconds: 100);
  // });

  // test('async function with exception with and throwExceptions==false', () {
  //   final command =
  //       Command.createAsync<String, String>(slowAsyncFunctionFail);

  //   command.thrownExceptions.listen((e) => print(e.toString());

  //   expect(command.canExecute.value ,true);
  //   expect(command.isExecuting.value ,false);

  //   expect(command.results,
  //       emitsInOrder([crm(null, false, true), crm(null, true, false)]);
  //   expect(command.thrownExceptions.value ,isException);

  //   command.execute("Done"));

  //   expect(command.canExecute.value ,true);
  //   expect(command.isExecuting.value ,false);
  // });

  // test("async function should be next'able", () async {
  //   final cmd = Command.createAsync((_) async {
  //     await Future.delayed(Duration(milliseconds: 1);
  //     return 42;
  //   });

  //   cmd.execute();
  //   final result = await cmd.next;

  //   expect(result, 42);
  // });

  // test("async functions that throw should be next'able", () async {
  //   final cmd = Command.createAsync((_) async {
  //     await Future.delayed(Duration(milliseconds: 1);
  //     throw Exception("oh no"));
  //   });

  //   cmd.execute();
  //   var didntThrow = true;
  //   try {
  //     await cmd.next;
  //   } catch (e) {
  //     didntThrow = false;
  //   }

  //   expect(didntThrow, false);
  // });

  // Stream<int> testProvider(int i) async* {
  //   yield i;
  //   yield i + 1;
  //   yield i + 2;
  // }

  // test('Command.createFromStream', () {
  //   final command = Command.createFromStream<int, int>(testProvider);

  //   command.canExecute.listen((b) {
  //     print("Can execute:" + b.toString();
  //   });
  //   command.isExecuting.listen((b) {
  //     print("Is executing:" + b.toString();
  //   });

  //   command.listen((i) {
  //     print("Results:" + i.toString();
  //   });

  //   expect(command.canExecute.value ,true), reason: "Canexecute before false"));
  //   expect(command.isExecuting.value ,false),
  //       reason: "IsExecuting before true"));

  //   expect(
  //       command.results,
  //       emitsInOrder([
  //         crm(null, false, true),
  //         crm(1, false, true),
  //         crm(2, false, true),
  //         crm(3, false, true),
  //         crm(3, false, false)
  //       ]);
  //   expect(command, emitsInOrder([1, 2, 3]);

  //   command.execute(1);

  //   expect(command.canExecute.value ,true), reason: "Canexecute after false"));
  //   expect(command.isExecuting.value ,false);
  // });

  // Stream<int> testProviderError(int i) async* {
  //   throw Exception();
  // }

  // test('Command.createFromStreamWithException', () {
  //   final command = Command.createFromStream<int, int>(testProviderError);

  //   command.canExecute.listen((b) {
  //     print("Can execute:" + b.toString();
  //   });
  //   command.isExecuting.listen((b) {
  //     print("Is executing:" + b.toString();
  //   });

  //   command.results.listen((i) {
  //     print("Results:" + i.toString();
  //   });

  //   expect(command.canExecute.value ,true), reason: "Canexecute before false"));
  //   expect(command.isExecuting.value ,false),
  //       reason: "IsExecuting before true"));

  //   expect(command.results,
  //       emitsInOrder([crm(null, false, true), crm(null, true, false)]);

  //   expect(command.thrownExceptions.value ,TypeMatcher<Exception>());

  //   command.execute(1);

  //   expect(command.canExecute.value ,true), reason: "Canexecute after false"));
  //   expect(command.isExecuting.value ,false);
  // });

  // test('Command.createFromStreamWithException2', () {
  //   var streamController = StreamController<String>.broadcast();

  //   var command = Command.createFromStream((_) {
  //     return streamController.stream.map((rideMap) {
  //       throw Exception();
  //     });
  //   });

  //   command.results.listen((r) {
  //     print(r.toString();
  //   });

  //   command.thrownExceptions.listen((e) {
  //     print(e.toString();
  //   });

  //   expect(command.thrownExceptions.value ,TypeMatcher<Exception>());

  //   command.execute();

  //   streamController.add('test');

  //   print('Finished');
  // });

  // test('Command.createFromStreamWithExceptionOnlyThrown once', () async {
  //   var command = Command.createFromStream((_) {
  //     return Stream.value('test').map((rideMap) {
  //       throw Exception('TestException');
  //     });
  //   });

  //   var count = 0;
  //   command.thrownExceptions.listen((e) {
  //     count++;
  //     print(e.toString();
  //   });

  //   command.execute();

  //   await Future.delayed(Duration(seconds: 1);

  //   expect(count, 1);
  // });

// No idea why it's not posible to catch the exception with     expect(command.results, emitsError(isException);
/*
    test('Command.createFromStreamWithException throw exeption = true', () 
  {

    final command  = Command.createFromStream<int,int>( testProviderError);
    command.throwExceptions = true;

    command.canExecute.listen((b){print("Can execute:" + b.toString();});
    command.isExecuting.listen((b){print("Is executing:" + b.toString();});

    command.results.listen((i){print("Results:" + i.toString();});


    expect(command.canExecute.value ,true),reason: "Canexecute before false"));
    expect(command.isExecuting.value ,false),reason: "Canexecute before true"));

    expect(command.results, emitsError(isException);
    expect(command, emitsError(isException);
    

    command.execute(1);

    expect(command.canExecute.value ,true),reason: "Canexecute after false"));
    expect(command.isExecuting.value ,false);    
  });

*/
}

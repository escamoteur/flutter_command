import 'package:flutter_command/flutter_command.dart';
import 'package:test/test.dart';

enum TestType { error, exception, assertion }

Future<void> asyncFunction1(TestType testType) async {
  switch (testType) {
    case TestType.error:
      await asyncFunctionError();
      break;
    case TestType.exception:
      await asyncFunctionExeption();
      break;
    case TestType.assertion:
      await asyncFunctionAssertion();
      break;
  }
}

Future<void> asyncFunctionError() async {
  throw Error();
}

Future<void> asyncFunctionExeption() async {
  throw Exception('Exception');
}

Future<bool> asyncFunctionBoolExeption() async {
  throw Exception('Exception');
}

Future<void> asyncFunctionAssertion() async {
  assert(false, 'assertion');

  await Future.delayed(const Duration(seconds: 1));
}

void main() {
  group('ErrorFilterTests', () {
    test('PredicateFilterTest', () {
      final filter = PredicatesErrorFilter([
        (error, stacktrace) => errorFilter<Error>(error, ErrorReaction.none),
        (error, stacktrace) => errorFilter<Exception>(
              error,
              ErrorReaction.firstLocalThenGlobalHandler,
            ),
      ]);

      expect(
        filter.filter(Error(), StackTrace.current),
        ErrorReaction.none,
      );
      expect(
        filter.filter(Exception(), StackTrace.current),
        ErrorReaction.firstLocalThenGlobalHandler,
      );
      expect(
        filter.filter('this is not in the filer', StackTrace.current),
        ErrorReaction.defaulErrorFilter,
      );
    });
    test('ExemptionFilterTest', () {
      final filter = ErrorFilterExcemption<Error>(ErrorReaction.none);

      expect(
        filter.filter(Error(), StackTrace.current),
        ErrorReaction.none,
      );
      expect(
        filter.filter(Exception(), StackTrace.current),
        ErrorReaction.defaulErrorFilter,
      );
      expect(
        filter.filter('this is not in the filer', StackTrace.current),
        ErrorReaction.defaulErrorFilter,
      );
    });
  });
  group('ErrorRection.none', () {
    test('throws an assertion although there is a filter for it (as intended))',
        () async {
      Object? globalHandlerCaught;
      Object? localHandlerCaught;

      final testCommand = Command.createAsyncNoParamNoResult(
        () => asyncFunction1(TestType.assertion),
        errorFilter: PredicatesErrorFilter([
          (error, stacktrace) =>
              errorFilter<AssertionError>(error, ErrorReaction.none),
        ]),
      );
      testCommand.errors.listen((error, _) => localHandlerCaught = error);
      Command.globalExceptionHandler =
          (error, _) => globalHandlerCaught = error.error;

      expectLater(() => testCommand.execute(), throwsA(isA<AssertionError>()));
      await Future.delayed(const Duration(seconds: 1));
      expect(localHandlerCaught, null);
      expect(globalHandlerCaught, null);
    });
    test('Assertion is handled like any other error', () async {
      Object? globalHandlerCaught;
      Object? localHandlerCaught;

      Command.assertionsAlwaysThrow = false;
      final testCommand = Command.createAsyncNoParamNoResult(
        () => asyncFunction1(TestType.assertion),
        errorFilter: PredicatesErrorFilter([
          (error, stacktrace) =>
              errorFilter<AssertionError>(error, ErrorReaction.none),
        ]),
      );
      testCommand.errors.listen((error, _) => localHandlerCaught = error);
      Command.globalExceptionHandler =
          (error, _) => globalHandlerCaught = error.error;

      testCommand.execute();
      await Future.delayed(const Duration(seconds: 1));

      expect(localHandlerCaught, null);
      expect(globalHandlerCaught, null);
    });

    test('throws an Error - ErrorReaction.none', () async {
      Object? globalHandlerCaught;
      Object? localHandlerCaught;

      final testCommand = Command.createAsyncNoParamNoResult(
        () => asyncFunction1(TestType.error),
        errorFilter: const TableErrorFilter({Error: ErrorReaction.none}),
      );
      testCommand.errors.listen((error, _) => localHandlerCaught = error);
      Command.globalExceptionHandler =
          (error, _) => globalHandlerCaught = error.error;

      testCommand.execute();
      await Future.delayed(const Duration(seconds: 2));

      expect(localHandlerCaught, null);
      expect(globalHandlerCaught, null);
    });

    test('throws exception - ErrorReaction.none', () async {
      Object? globalHandlerCaught;
      Object? localHandlerCaught;

      final testCommand = Command.createAsyncNoParamNoResult(
        () => asyncFunction1(TestType.exception),
        errorFilter: const TableErrorFilter({
          Exception: ErrorReaction.none,
        }),
      );
      testCommand.errors.listen((error, _) => localHandlerCaught = error);
      Command.globalExceptionHandler =
          (error, _) => globalHandlerCaught = error.error;

      testCommand.execute();
      await Future.delayed(const Duration(seconds: 1));

      expect(localHandlerCaught, null);
      expect(globalHandlerCaught, null);
    });
  });
  group('different filters -', () {
    test('throwExection', () async {
      Object? globalHandlerCaught;
      Object? localHandlerCaught;

      final testCommand = Command.createAsyncNoParamNoResult(
        () => asyncFunction1(TestType.exception),
        errorFilter: PredicatesErrorFilter([
          (error, stacktrace) =>
              errorFilter<Exception>(error, ErrorReaction.throwException),
        ]),
      );
      testCommand.errors.listen((error, _) => localHandlerCaught = error);
      Command.globalExceptionHandler =
          (error, _) => globalHandlerCaught = error.error;

      expectLater(() => testCommand.execute(), throwsA(isA<Exception>()));
      await Future.delayed(const Duration(seconds: 1));

      expect(localHandlerCaught, null);
      expect(globalHandlerCaught, null);
    });
    test('globalHandler', () async {
      Object? globalHandlerCaught;
      Object? localHandlerCaught;

      final testCommand = Command.createAsyncNoParamNoResult(
        () => asyncFunction1(TestType.exception),
        errorFilter: PredicatesErrorFilter([
          (error, stacktrace) =>
              errorFilter<Exception>(error, ErrorReaction.globalHandler),
        ]),
      );
      testCommand.errors.listen((error, _) => localHandlerCaught = error);
      Command.globalExceptionHandler = (error, _) {
        globalHandlerCaught = error.error;
      };

      testCommand.execute();
      await Future.delayed(const Duration(seconds: 1));

      expect(localHandlerCaught, null);
      expect(globalHandlerCaught, isA<Exception>());
    });
    test('localHandler', () async {
      Object? globalHandlerCaught;
      Object? localHandlerCaught;

      final testCommand = Command.createAsyncNoParamNoResult(
        () => asyncFunction1(TestType.exception),
        errorFilter: PredicatesErrorFilter([
          (error, stacktrace) =>
              errorFilter<Exception>(error, ErrorReaction.localHandler),
        ]),
      );
      testCommand.errors
          .listen((error, _) => localHandlerCaught = error?.error);
      Command.globalExceptionHandler = (error, _) {
        globalHandlerCaught = error.error;
      };

      testCommand.execute();
      await Future.delayed(const Duration(seconds: 1));

      expect(localHandlerCaught, isA<Exception>());
      expect(globalHandlerCaught, null);
    });
    test('localAndGlobalHandler', () async {
      Object? globalHandlerCaught;
      Object? localHandlerCaught;

      final testCommand = Command.createAsyncNoParamNoResult(
        () => asyncFunction1(TestType.exception),
        errorFilter: PredicatesErrorFilter([
          (error, stacktrace) => errorFilter<Exception>(
                error,
                ErrorReaction.localAndGlobalHandler,
              ),
        ]),
      );
      testCommand.errors
          .listen((error, _) => localHandlerCaught = error?.error);
      Command.globalExceptionHandler = (error, _) {
        globalHandlerCaught = error.error;
      };

      testCommand.execute();
      await Future.delayed(const Duration(seconds: 1));

      expect(localHandlerCaught, isA<Exception>());
      expect(globalHandlerCaught, isA<Exception>());
    });
    test('globalIfNoLocalHandler no local handler', () async {
      Object? globalHandlerCaught;
      Object? localHandlerCaught;

      final testCommand = Command.createAsyncNoParamNoResult(
        () => asyncFunction1(TestType.exception),
        errorFilter: PredicatesErrorFilter([
          (error, stacktrace) => errorFilter<Exception>(
                error,
                ErrorReaction.firstLocalThenGlobalHandler,
              ),
        ]),
      );
      Command.globalExceptionHandler = (error, _) {
        globalHandlerCaught = error.error;
      };

      testCommand.execute();
      await Future.delayed(const Duration(seconds: 1));

      expect(localHandlerCaught, null);
      expect(globalHandlerCaught, isA<Exception>());
    });
    test('globalIfNoLocalHandler - local handler @errors', () async {
      Object? globalHandlerCaught;
      Object? localHandlerCaught;

      final testCommand = Command.createAsyncNoParamNoResult(
        () => asyncFunction1(TestType.exception),
        errorFilter: PredicatesErrorFilter([
          (error, stacktrace) => errorFilter<Exception>(
                error,
                ErrorReaction.firstLocalThenGlobalHandler,
              ),
        ]),
      );
      testCommand.errors
          .listen((error, _) => localHandlerCaught = error?.error);
      Command.globalExceptionHandler = (error, _) {
        globalHandlerCaught = error.error;
      };

      testCommand.execute();
      await Future.delayed(const Duration(seconds: 1));

      expect(localHandlerCaught, isA<Exception>());
      expect(globalHandlerCaught, null);
    });
    test('globalIfNoLocalHandler - local handler @results ', () async {
      Object? globalHandlerCaught;
      Object? localHandlerCaught;

      final testCommand = Command.createAsyncNoParam<bool>(
        () => asyncFunctionBoolExeption(),
        errorFilter: PredicatesErrorFilter([
          (error, stacktrace) => errorFilter<Exception>(
                error,
                ErrorReaction.firstLocalThenGlobalHandler,
              ),
        ]),
        initialValue: true,
      );
      testCommand.results.listen((result, _) {
        if (result.hasError) {
          localHandlerCaught = result.error;
        }
      });
      Command.globalExceptionHandler = (error, _) {
        globalHandlerCaught = error.error;
      };

      testCommand.execute();
      await Future.delayed(const Duration(seconds: 1));

      expect(localHandlerCaught, isA<Exception>());
      expect(globalHandlerCaught, null);
    });
    test('globalIfNoLocalHandler - no handler', () async {
      Command.globalExceptionHandler = null;
      Object? globalHandlerCaught;
      Object? localHandlerCaught;

      final testCommand = Command.createAsyncNoParamNoResult(
        () => asyncFunction1(TestType.exception),
        errorFilter: PredicatesErrorFilter([
          (error, stacktrace) => errorFilter<Exception>(
                error,
                ErrorReaction.firstLocalThenGlobalHandler,
              ),
        ]),
      );
      expectLater(() => testCommand.execute(), throwsA(isA<AssertionError>()));
      await Future.delayed(const Duration(seconds: 1));

      expect(localHandlerCaught, null);
      expect(globalHandlerCaught, null);
    });
    test('noHandlersThrowException no handler', () async {
      Command.globalExceptionHandler = null;
      Object? globalHandlerCaught;
      Object? localHandlerCaught;

      final testCommand = Command.createAsyncNoParamNoResult(
        () => asyncFunction1(TestType.exception),
        errorFilter: PredicatesErrorFilter([
          (error, stacktrace) => errorFilter<Exception>(
                error,
                ErrorReaction.noHandlersThrowException,
              ),
        ]),
      );
      expectLater(() => testCommand.execute(), throwsA(isA<Exception>()));
      await Future.delayed(const Duration(seconds: 1));

      expect(localHandlerCaught, null);
      expect(globalHandlerCaught, null);
    });
    test('noHandlersThrowException - local handler', () async {
      Object? globalHandlerCaught;
      Object? localHandlerCaught;

      final testCommand = Command.createAsyncNoParamNoResult(
        () => asyncFunction1(TestType.exception),
        errorFilter: PredicatesErrorFilter([
          (error, stacktrace) => errorFilter<Exception>(
                error,
                ErrorReaction.noHandlersThrowException,
              ),
        ]),
      );
      testCommand.errors
          .listen((error, _) => localHandlerCaught = error?.error);
      testCommand.execute();
      await Future.delayed(const Duration(seconds: 1));

      expect(localHandlerCaught, isA<Exception>());
      expect(globalHandlerCaught, null);
    });
    test('noHandlersThrowException - global handler', () async {
      Object? globalHandlerCaught;
      Object? localHandlerCaught;

      final testCommand = Command.createAsyncNoParamNoResult(
        () => asyncFunction1(TestType.exception),
        errorFilter: PredicatesErrorFilter([
          (error, stacktrace) => errorFilter<Exception>(
                error,
                ErrorReaction.noHandlersThrowException,
              ),
        ]),
      );
      Command.globalExceptionHandler = (error, _) {
        globalHandlerCaught = error.error;
      };
      testCommand.execute();
      await Future.delayed(const Duration(seconds: 1));

      expect(localHandlerCaught, null);
      expect(globalHandlerCaught, isA<Exception>());
    });
    test('noHandlersThrowException - both handler', () async {
      Object? globalHandlerCaught;
      Object? localHandlerCaught;

      final testCommand = Command.createAsyncNoParamNoResult(
        () => asyncFunction1(TestType.exception),
        errorFilter: PredicatesErrorFilter([
          (error, stacktrace) => errorFilter<Exception>(
                error,
                ErrorReaction.noHandlersThrowException,
              ),
        ]),
      );
      testCommand.errors
          .listen((error, _) => localHandlerCaught = error?.error);
      Command.globalExceptionHandler = (error, _) {
        globalHandlerCaught = error.error;
      };
      testCommand.execute();
      await Future.delayed(const Duration(seconds: 1));

      expect(localHandlerCaught, isA<Exception>());
      expect(globalHandlerCaught, null);
    });
    test('throwIfNoLocalHandler - local handler', () async {
      Object? globalHandlerCaught;
      Object? localHandlerCaught;

      final testCommand = Command.createAsyncNoParamNoResult(
        () => asyncFunction1(TestType.exception),
        errorFilter: PredicatesErrorFilter([
          (error, stacktrace) => errorFilter<Exception>(
                error,
                ErrorReaction.throwIfNoLocalHandler,
              ),
        ]),
      );
      testCommand.errors
          .listen((error, _) => localHandlerCaught = error?.error);
      Command.globalExceptionHandler = (error, _) {
        globalHandlerCaught = error.error;
      };
      testCommand.execute();
      await Future.delayed(const Duration(seconds: 1));

      expect(localHandlerCaught, isA<Exception>());
      expect(globalHandlerCaught, null);
    });
    test('throwIfNoLocalHandler - no local handler', () async {
      Object? globalHandlerCaught;
      Object? localHandlerCaught;

      final testCommand = Command.createAsyncNoParamNoResult(
        () => asyncFunction1(TestType.exception),
        errorFilter: PredicatesErrorFilter([
          (error, stacktrace) => errorFilter<Exception>(
                error,
                ErrorReaction.throwIfNoLocalHandler,
              ),
        ]),
      );
      Command.globalExceptionHandler = (error, _) {
        globalHandlerCaught = error.error;
      };
      expectLater(() => testCommand.execute(), throwsA(isA<Exception>()));
      await Future.delayed(const Duration(seconds: 1));

      expect(localHandlerCaught, null);
      expect(globalHandlerCaught, null);
    });
  });
  group('force throw', () {
    test('throws exception', () async {
      // ignore: deprecated_member_use_from_same_package
      Command.debugErrorsThrowAlways = true;
      Object? globalHandlerCaught;
      Object? localHandlerCaught;

      final testCommand = Command.createAsyncNoParamNoResult(
        () => asyncFunction1(TestType.exception),
        errorFilter: PredicatesErrorFilter([
          (error, stacktrace) =>
              errorFilter<Exception>(error, ErrorReaction.none),
        ]),
      );
      testCommand.errors.listen((error, _) => localHandlerCaught = error);
      Command.globalExceptionHandler =
          (error, _) => globalHandlerCaught = error.error;

      expectLater(() => testCommand.execute(), throwsA(isA<Exception>()));
      await Future.delayed(const Duration(seconds: 1));

      expect(localHandlerCaught, null);
      expect(globalHandlerCaught, null);
    });
    test('throws exception global handler', () async {
      // ignore: deprecated_member_use_from_same_package
      Command.debugErrorsThrowAlways = true;
      Object? globalHandlerCaught;
      Object? localHandlerCaught;

      final testCommand = Command.createAsyncNoParamNoResult(
        () => asyncFunction1(TestType.exception),
        errorFilter: PredicatesErrorFilter([
          (error, stacktrace) =>
              errorFilter<Exception>(error, ErrorReaction.globalHandler),
        ]),
      );
      testCommand.errors.listen((error, _) => localHandlerCaught = error);
      Command.globalExceptionHandler =
          (error, _) => globalHandlerCaught = error.error;

      expectLater(() => testCommand.execute(), throwsA(isA<Exception>()));
      await Future.delayed(const Duration(seconds: 1));

      expect(localHandlerCaught, null);
      expect(globalHandlerCaught, null);
    });
    test('localHandler throws', () async {
      Object? globalHandlerCaught;
      Object? localHandlerCaught;

      final testCommand = Command.createAsyncNoParamNoResult(
        () => asyncFunction1(TestType.exception),
        errorFilter: PredicatesErrorFilter([
          (error, stacktrace) =>
              errorFilter<Exception>(error, ErrorReaction.localHandler),
        ]),
      );
      testCommand.errors.listen((error, _) {
        throw StateError('local handler throws');
      });
      Command.globalExceptionHandler = (error, _) {
        globalHandlerCaught = error.error;
      };

      testCommand.execute();
      await Future.delayed(const Duration(seconds: 1));

      expect(localHandlerCaught, null);
      expect(globalHandlerCaught, isA<StateError>());
    });
  });
}

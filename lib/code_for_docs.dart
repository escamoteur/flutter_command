// import 'package:flutter/foundation.dart';

// typedef Action = void Function();
// typedef Action1<TParam> = void Function(TParam param);

// typedef Func<TResult> = TResult Function();
// typedef Func1<TParam, TResult> = TResult Function(TParam param);

// typedef AsyncAction = Future Function();
// typedef AsyncAction1<TParam> = Future Function(TParam param);

// typedef AsyncFunc<TResult> = Future<TResult> Function();
// typedef AsyncFunc1<TParam, TResult> = Future<TResult> Function(TParam param);

// class CommandResult<TParam, TResult> {
//   final TParam paramData;
//   final TResult data;
//   final dynamic error;
//   final bool isExecuting;

//   // ignore: avoid_positional_boolean_parameters
//   const CommandResult(this.paramData, this.data, this.error, this.isExecuting);
// }

// class CommandError<TParam> {
//   final Object error;
//   final TParam paramData;

//   CommandError(
//     this.paramData,
//     this.error,
//   );
// }

// abstract class Command<TParam, TResult> extends ValueNotifier<TResult> {
//   static Command<TParam, TResult> createAsync<TParam, TResult>(
//     AsyncFunc1<TParam, TResult> func,
//     TResult initialValue, {
//     ValueListenable<bool> canExecute,
//     bool includeLastResultInCommandResults = false,
//   }) {}

//   /// Calls the wrapped handler function with an option input parameter
//   void execute([TParam param]);

//   /// This makes Command a callable class, so instead of `myCommand.execute()` you can write `myCommand()`
//   void call([TParam param]) => execute(param);

//   ValueListenable<CommandResult<TParam, TResult>> get results => _commandResult;

//   ValueListenable<bool> get isExecuting => _isExecuting;

//   ValueListenable<bool> get canExecute => _canExecute;

//   ValueListenable<CommandError> get thrownExceptions => _thrownExceptions;

//   final ValueNotifier<bool> _isExecuting = ValueNotifier<bool>(false);
//   ValueNotifier<bool> _canExecute;
//   final ValueNotifier<CommandError<TParam>> _thrownExceptions =
//       ValueNotifier<CommandError<TParam>>(null);

//   void dispose() {}
// }

// abstract class Command<TParam, TResult> extends ValueNotifier<TResult> {
//   static Command<void, void> createSyncNoParamNoResult(
//     Action action, {
//     ValueListenable<bool> canExecute,
//   }) {}

//   static Command<TParam, void> createSyncNoResult<TParam>(
//     Action1<TParam> action, {
//     ValueListenable<bool> canExecute,
//   }) {}

//   static Command<void, TResult> createSyncNoParam<TResult>(
//     Func<TResult> func,
//     TResult initialValue, {
//     ValueListenable<bool> canExecute,
//     bool includeLastResultInCommandResults = false,
//   }) {}

//   static Command<TParam, TResult> createSync<TParam, TResult>(
//     Func1<TParam, TResult> func,
//     TResult initialValue, {
//     ValueListenable<bool> canExecute,
//     bool includeLastResultInCommandResults = false,
//   }) {}

//   // Asynchronous

//   static Command<void, void> createAsyncNoParamNoResult(AsyncAction action,
//       {ValueListenable<bool> canExecute,
//       bool emitsLastValueToNewSubscriptions = false}) {}

//   static Command<TParam, void> createAsyncNoResult<TParam>(
//     AsyncAction1<TParam> action, {
//     ValueListenable<bool> canExecute,
//   }) {}

//   static Command<void, TResult> createAsyncNoParam<TResult>(
//     AsyncFunc<TResult> func,
//     TResult initialValue, {
//     ValueListenable<bool> canExecute,
//     bool includeLastResultInCommandResults = false,
//   }) {}

//   static Command<TParam, TResult> createAsync<TParam, TResult>(
//     AsyncFunc1<TParam, TResult> func,
//     TResult initialValue, {
//     ValueListenable<bool> canExecute,
//     bool includeLastResultInCommandResults = false,
//   }) {}

//   /// Calls the wrapped handler function with an option input parameter
//   void execute([TParam param]);

//   /// This makes RxCommand a callable class, so instead of `myCommand.execute()` you can write `myCommand()`
//   void call([TParam param]) => execute(param);

//   ValueListenable<CommandResult<TParam, TResult>> get results => _commandResult;

//   ValueListenable<bool> get isExecuting => _isExecuting;

//   ValueListenable<bool> get canExecute => _canExecute;

//   ValueListenable<CommandError> get thrownExceptions => _thrownExceptions;

//   final ValueNotifier<bool> _isExecuting = ValueNotifier<bool>(false);
//   ValueNotifier<bool> _canExecute;
//   final ValueNotifier<CommandError<TParam>> _thrownExceptions =
//       ValueNotifier<CommandError<TParam>>(null);

//   void dispose() {}
// }

enum ErrorReaction {
  /// Errors are caught but silently swallowed
  none,

  /// Errors are caught and rethrown
  throwException,

  /// Errors are caught and passed only to the global handler
  /// if no global handler is registered an assertion is thrown
  globalHandler,

  /// Errors are caught and passed only to the local handlers
  /// if no one is listening on [errors] or [results] an assertion
  /// thrown in debub mode
  localHandler,

  /// Errors are caught and passed to both handlers
  /// if no one is listening on [errors] or [results] or no global
  /// error handler is registered an assertion is
  /// thrown in debub mode
  localAndGlobalHandler,

  /// Errors are caught and passed to the global handler if no one
  /// listens on [error] or [results]. If no global handler is registered an
  /// assertion is thrown in debug moe
  globalIfNoLocalHandler,

  /// if no globel handler is present and no listeners on [results] or [errors]
  /// the error is rethrown.
  /// if any or both of the handlers are present, it will call them
  noHandlersThrowException,

  /// Errors are caught and rethrown if no local handler
  throwIfNoLocalHandler,
}

/// Instead of the current parameter `catchAlways` commands can get an optional
/// parameter `errorFilter` of type [ErrorFilter] which can be used to
/// customize the error handling.
/// Additionally there will be a Global error Filter that is used if no
/// local error filter is present.
abstract class ErrorFilter {
  ErrorReaction filter(Object error, StackTrace stackTrace);
}

class ErrorHandlerGlobalIfNoLocal implements ErrorFilter {
  const ErrorHandlerGlobalIfNoLocal();
  @override
  ErrorReaction filter(Object error, StackTrace stackTrace) {
    return ErrorReaction.globalIfNoLocalHandler;
  }
}

class ErrorHandlerLocal implements ErrorFilter {
  const ErrorHandlerLocal();
  @override
  ErrorReaction filter(Object error, StackTrace stackTrace) {
    return ErrorReaction.localHandler;
  }
}

class TableErrorFilter implements ErrorFilter {
  final Map<Type, ErrorReaction> _table;

  const TableErrorFilter(this._table);

  @override
  ErrorReaction filter(Object error, StackTrace stackTrace) {
    return _table[error.runtimeType] ?? ErrorReaction.globalIfNoLocalHandler;
  }
}

class FunctionErrorFilter implements ErrorFilter {
  final ErrorReaction Function(Object error, StackTrace stackTrace) _filter;

  const FunctionErrorFilter(this._filter);

  @override
  ErrorReaction filter(Object error, StackTrace stackTrace) {
    return _filter(error, stackTrace);
  }
}

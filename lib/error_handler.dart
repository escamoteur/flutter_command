enum ErrorReaction {
  none, // Errors are caught but silently swallowed
  throwException, // Errors are caught and rethrown
  globalHandler, // Errors are caught and passed only to the global handler
  localHandler, // Errors are caught and passed only to the local handler
  localAndGlobalHandler, // Errors are caught and passed to both handlers
  globalIfNoLocalHandler, // Errors are caught and passed to the global handler
  // if no local handler is present and no listeners on [results]
  globalHandlerAndThrowException,
}

/// Instead of the current parameter `catchAlways` commands can get an optional
/// parameter `errorFilter` of type [ErrorFilter] which can be used to
/// customize the error handling.
/// Additionally there will be a Global error Filter that is used if no
/// local error filter is present.
abstract class ErrorFilter {
  ErrorReaction filter(Object error, StackTrace stackTrace);
}

class DefaultErrorFilter implements ErrorFilter {
  @override
  ErrorReaction filter(Object error, StackTrace stackTrace) {
    return ErrorReaction.globalIfNoLocalHandler;
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

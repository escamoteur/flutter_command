enum ErrorReaction {
  /// Errors are caught but silently swallowed
  none(false),

  /// Errors are caught and rethrown
  throwException(false),

  /// Errors are caught and passed only to the global handler
  /// if no global handler is registered an assertion is thrown
  globalHandler(false),

  /// Errors are caught and passed only to the local handlers
  /// if no one is listening on [errors] or [results] an assertion
  /// thrown in debub mode
  localHandler(true),

  /// Errors are caught and passed to both handlers
  /// if no one is listening on [errors] or [results] or no global
  /// error handler is registered an assertion is
  /// thrown in debub mode
  localAndGlobalHandler(true),

  /// Errors are caught and passed to the global handler if no one
  /// listens on [error] or [results]. If no global handler is registered an
  /// assertion is thrown in debug moe
  firstLocalThenGlobalHandler(true),

  /// if no global handler is present and no listeners on [results] or [errors]
  /// the error is rethrown.
  /// if any or both of the handlers are present, it will call them, first the
  /// local handler if present, then the global handler if present.
  noHandlersThrowException(true),

  /// Errors are caught and rethrown if no local handler
  /// makes really only sense as global error filter
  throwIfNoLocalHandler(true),

  /// the default error filter handler of the Command class will be called to
  /// determine the error reaction. The default error filter is
  /// not allowed to return this value.
  defaulErrorFilter(false),
  ;

  final bool shouldCallLocalHandler;

  const ErrorReaction(this.shouldCallLocalHandler);
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
    return ErrorReaction.firstLocalThenGlobalHandler;
  }
}

class ErrorHandlerLocal implements ErrorFilter {
  const ErrorHandlerLocal();
  @override
  ErrorReaction filter(Object error, StackTrace stackTrace) {
    return ErrorReaction.localHandler;
  }
}

class ErrorHandlerLocalAndGlobal implements ErrorFilter {
  const ErrorHandlerLocalAndGlobal();
  @override
  ErrorReaction filter(Object error, StackTrace stackTrace) {
    return ErrorReaction.localAndGlobalHandler;
  }
}

class ErrorFilterExcemption<T> implements ErrorFilter {
  ErrorFilterExcemption(this.excemptionReaction);
  ErrorReaction excemptionReaction;
  @override
  ErrorReaction filter(Object error, StackTrace stackTrace) {
    if (error is T) {
      return excemptionReaction;
    }
    return ErrorReaction.defaulErrorFilter;
  }
}

/// This filter allows to pass a table of error types and the corresponding
/// [ErrorReaction]s. Attention, the table can only compare the runtime type
/// of the error on equality, not the type hierarchy.
/// Normally you couldn't match against the Excpeption type, because the runtime
/// type of an exception is always _Exception which is a private type.
/// As Exception is such a basic error type this funcion has a workaround for
/// this case.
/// I recommend to use the [PredicatesErrorFilter] instead unless you have a
/// very specific use case that requires to compare for type equality.
class TableErrorFilter implements ErrorFilter {
  final Map<Type, ErrorReaction> _table;

  const TableErrorFilter(this._table);

  @override
  ErrorReaction filter(Object error, StackTrace stackTrace) {
    if (error.runtimeType == Exception().runtimeType) {
      return _table[Exception] ?? ErrorReaction.firstLocalThenGlobalHandler;
    }
    return _table[error.runtimeType] ?? ErrorReaction.defaulErrorFilter;
  }
}

typedef ErrorFilterPredicate = ErrorReaction? Function(
  Object error,
  StackTrace stackTrace,
);

ErrorReaction? errorFilter<TError>(
  Object error,
  ErrorReaction reaction,
) {
  if (error is TError) {
    return reaction;
  }
  return null;
}

/// Takes a list of predicate functions and returns the first non null
/// [ErrorReaction] or [ErrorReaction.defaulErrorFilter] if no predicate
/// matches.
/// The predicates are called in the order of the list. which means if you want to
/// match against a type hierarchy you have to put the more specific type first.
/// You can define your own predicates or use the [errorFilter] function
/// like this
/// ```dart
/// final filter = PredicatesErrorFilter([
///  errorFilter<ArgumentError>(error, ErrorReaction.throwException),
/// errorFilter<RangeError>(error, ErrorReaction.throwException),
/// errorFilter<Exception>(error, ErrorReaction.globalIfNoLocalHandler),),
/// ]);
/// In contrast to the [TableErrorFilter] this filter can match against the
/// type hierarchy using the [errorFilter] function.
class PredicatesErrorFilter implements ErrorFilter {
  final List<ErrorFilterPredicate> _filters;

  const PredicatesErrorFilter(this._filters);

  @override
  ErrorReaction filter(Object error, StackTrace stackTrace) {
    for (final filter in _filters) {
      final reaction = filter(error, stackTrace);
      if (reaction != null) return reaction;
    }
    return ErrorReaction.defaulErrorFilter;
  }
}

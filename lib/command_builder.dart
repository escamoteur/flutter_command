part of flutter_command;

class CommandBuilder<TParam, TResult> extends StatelessWidget {
  final Command<TParam, TResult> command;

  /// This builder will be called when the
  /// command is executed successfully, independent of the return value.
  final Widget Function(BuildContext context, TParam? param)? onSuccess;

  /// If your command has a return value, you can use this builder to build a widget
  /// when the command is executed successfully.
  final Widget Function(BuildContext context, TResult data, TParam? param)?
      onData;

  /// If the command has no return value or returns null, this builder will be called when the
  /// command is executed successfully.
  final Widget Function(BuildContext context, TParam? param)? onNullData;
  final Widget Function(
    BuildContext context,
    TResult? lastValue,
    TParam? param,
  )? whileExecuting;
  final Widget Function(
    BuildContext context,
    Object,
    TResult? lastValue,
    TParam?,
  )? onError;

  const CommandBuilder({
    required this.command,
    this.onSuccess,
    this.onData,
    this.onNullData,
    this.whileExecuting,
    this.onError,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (command._noReturnValue) {}
    return ValueListenableBuilder<CommandResult<TParam?, TResult>>(
      valueListenable: command.results,
      builder: (context, result, _) {
        return result.toWidget(
          onData: onData != null
              ? (data, paramData) => onData!.call(context, data, paramData)
              : null,
          onNullData: onNullData != null
              ? (paramData) => onNullData!.call(context, paramData)
              : null,
          whileExecuting: whileExecuting != null
              ? (lastData, paramData) =>
                  whileExecuting!.call(context, lastData, paramData)
              : null,
          onError: (lastData, error, paramData) {
            if (onError == null) {
              return const SizedBox();
            }
            assert(
                result.errorReaction?.shouldCallLocalHandler == true,
                'This CommandBuilder received an error from Command ${command.name} '
                'but the errorReaction indidates that the error should not be handled locally. ');
            return onError!.call(context, lastData, error, paramData);
          },
        );
      },
    );
  }
}

extension ToWidgeCommandResult<TParam, TResult>
    on CommandResult<TParam, TResult> {
  Widget toWidget({
    Widget Function(TResult result, TParam? param)? onData,
    Widget Function(TParam? param)? onSuccess,
    Widget Function(TParam? param)? onNullData,
    Widget Function(TResult? lastResult, TParam? param)? whileExecuting,
    Widget Function(Object error, TResult? lastResult, TParam? param)? onError,
  }) {
    assert(onData != null || onSuccess != null,
        'You have to provide at least a builder for onData or onSuccess');
    if (error != null) {
      return onError?.call(error!, data, paramData) ?? const SizedBox();
    }
    if (isExecuting) {
      return whileExecuting?.call(data, paramData) ?? const SizedBox();
    }
    if (onSuccess != null) {
      return onSuccess.call(paramData);
    }
    if (data != null) {
      return onData?.call(data as TResult, paramData) ?? const SizedBox();
    } else {
      return onNullData?.call(paramData) ?? const SizedBox();
    }
  }
}

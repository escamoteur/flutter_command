import 'package:flutter/widgets.dart';
import 'package:flutter_command/flutter_command.dart';

class CommandBuilder<TParam, TResult> extends StatelessWidget {
  final Command<TParam, TResult> command;
  final Widget Function(BuildContext context, TResult data, TParam? param)?
      onData;
  final Widget Function(BuildContext context, TParam? param)? onNullData;
  final Widget Function(
    BuildContext context,
    TResult? lastValue,
    TParam? param,
  )? whileExecuting;
  final Widget Function(
    BuildContext context,
    Object?,
    TResult? lastValue,
    TParam?,
  )? onError;

  const CommandBuilder({
    required this.command,
    this.onData,
    this.onNullData,
    this.whileExecuting,
    this.onError,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CommandResult<TParam?, TResult>>(
      valueListenable: command.results,
      builder: (context, result, _) {
        return result.toWidget(
          onData: (data, paramData) =>
              onData?.call(context, data, paramData) ?? const SizedBox(),
          onNullData: (paramData) =>
              onNullData?.call(context, paramData) ?? const SizedBox(),
          whileExecuting: (lastData, paramData) =>
              whileExecuting?.call(context, lastData, paramData) ??
              const SizedBox(),
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
    required Widget Function(TResult result, TParam? param) onData,
    Widget Function(TParam? param)? onNullData,
    Widget Function(TResult? lastResult, TParam? param)? whileExecuting,
    Widget Function(Object? error, TResult? lastResult, TParam? param)? onError,
  }) {
    if (error != null) {
      return onError?.call(error, data, paramData) ?? const SizedBox();
    }
    if (isExecuting) {
      return whileExecuting?.call(data, paramData) ?? const SizedBox();
    }
    if (data != null) {
      return onData(data as TResult, paramData);
    } else {
      return onNullData?.call(paramData) ?? const SizedBox();
    }
  }
}

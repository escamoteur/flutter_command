import 'package:flutter/widgets.dart';
import 'package:flutter_command/flutter_command.dart';

class CommandBuilder<TParam, TResult> extends StatelessWidget {
  final Command<TParam, TResult> command;
  final Widget Function(BuildContext, TResult, TParam) onData;
  final Widget Function(BuildContext, TParam) whileExecuting;
  final Widget Function(BuildContext, Object, TParam) onError;

  const CommandBuilder({
    this.command,
    this.onData,
    this.whileExecuting,
    this.onError,
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CommandResult<TParam, TResult>>(
        valueListenable: command.results,
        builder: (context, result, _) {
          if (result.hasData) {
            return onData?.call(context, result.data, result.paramData) ??
                SizedBox();
          } else if (result.isExecuting) {
            return whileExecuting?.call(context, result.paramData) ??
                SizedBox();
          } else {
            return onError?.call(context, result.error, result.paramData) ??
                SizedBox();
          }
        });
  }
}

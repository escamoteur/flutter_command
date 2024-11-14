---
id: testing_commands
title: Testing Commands
sidebar_label: Testing Commands
---

Testing is an essential step in the software development cycle. `Command` uses `ValueNotifier`s internally and this makes testing commands straight forward. Traditional approaches such as `StreamMatcher` for asynchronous testing is not applicable. A `ValueNotifier` is essentially a `ChangeNotifier` whose changes can be listened to and verified. The approach we used internally is store these results in a `List` and then compare this against an expected `List` of values. Generally we will have a `Command` which is already functional and we write test against it to verify its functional aspects. In  case of widget testing it would be preferable to mock a command and test the corresponding UI elements independently. Lets see these two cases in the upcoming sections.

## Testing Commands

### Command to be tested

Let us assume you want to test an asynchronous command which accepts a name and returns a greeting message after 2 seconds. Following is trivial implementation of such a command.

```dart
Command greetingCommand =
    Command.createAsync<String, String>((String name) async {
  await Future<void>.delayed(Duration(seconds: 2));
  return 'Hello $name! Welcome.';
}, 'Hello! Welcome.');
```

### Test changes in `value`

As a simple scenario lets test what is exposed by the `Command` which by itself is a `ValueNotifier` and can be listened to changes in its `value`.

```dart
test('Greeting Command returns correct messages', () async {
    // A list that holds the greetings returned by the command.
    List<String> greetings = [];

    greetingCommand.addListener(() {
      greetings.add(greetingCommand.value);
    });

    // Expect the initial Value is correct
    expect(greetingCommand.value, 'Hello! Welcome.');

    // Execute the command with the name Foo.
    greetingCommand.execute('Alice');

    // Wait for the command to execute.
    await Future<void>.delayed(Duration(seconds: 2));

    // Expect the value has changed to greet Alice
    expect(greetingCommand.value, 'Hello Alice! Welcome.');

    // Execute the command again with a different name this time
    // Since a Command is callable following is also a valid syntax.
    greetingCommand('Bob');

    // Wait for the command to execute.
    await Future<void>.delayed(Duration(seconds: 2));

    // Expect the value has changed to greet Bob
    expect(greetingCommand.value, 'Hello Bob! Welcome.');

    // Verify the results.
    expect(greetings, ['Hello Alice! Welcome.', 'Hello Bob! Welcome.']);
  });
```

In the above it is important to note that the initial value is not part of the expected list because the `value` is set even before adding a listener and hence the value change will not be emitted. However a `ValueListenable` builder would still receive this initial value, because it internally sets this to its `value`.
### Test Changes in `results`

Command exposes a combined state of its internal execution in an attribute called `results` in the form of `CommandResult`. This is much more granular compared to the above test. Here we receive additional information like whether the command is execution has any errors, the parameter if any passed to it and the result if any. Now if you check the expected results it contains more values. Since `CommandResult` overrides `==` it can be used directly in list comparison as shown in following snippet. 

```dart
test('Greeting Command returns correct results', () async {
    // A list that holds the greetings returned by the command.
    List<CommandResult> greetingResults = [];
    greetingCommand.results.listen((CommandResult greetingResult, _) {
      greetingResults.add(greetingResult);
    });

    // Execute the command with the name Foo.
    greetingCommand.execute('Alice');

    // Wait for the command to execute.
    await Future<void>.delayed(Duration(seconds: 2));

    // Execute the command again with a different name this time
    // Since a Command is callable following is also a valid syntax.
    greetingCommand('Bob');

    // Wait for the command to execute.
    await Future<void>.delayed(Duration(seconds: 2));

    // Verify the results.
    expect(greetingResults, [
      CommandResult<String, String>('Alice', null, null, true),
      CommandResult<String, String>('Alice', 'Hello Alice! Welcome.', null, false),
      CommandResult<String, String>('Bob', null, null, true),
      CommandResult<String, String>('Bob', 'Hello Bob! Welcome.', null, false),
    ]);
  });
```

However note that, if `TParam` the type of parameter, `TResult` the type of the result or the `Exception` thrown inside the command are not `==` comparable then a direct comparison of `CommandResult` would still fail. In such cases it is recommended to compare individual properties of these classes or override `==` for each of them.

## Mocking Commands

Its not always possible to create all the `Command`s upfront and proceed the UI development. In order to keep these process independent it would be necessary that the `Commands` be mockable. This also ensures that the Commands can evolve independently without affecting the UI widget tests as long as they stick to the required `TParam`, `TResult` signature. Hence `flutter_command` exposes a `MockCommand` class which provides utility functions to mock a `Command`.

Let us see an example which is similar to the above mentioned greeting command. We noticed that the `results` should notify results in the form of `CommandResult`. This behavior can be easily mocked as shown below. For this assume you have Text widget that shows this greeting message and we use a `ValueListenableBuilder` in this case. 

Lets first create a `MockCommand` called `mockGreetingCmd`.

```dart
final mockGreetingCmd = MockCommand<String, String>(
        "Initial Value",
        ValueNotifier<bool>(true),
        false,
        false,
        true,
        true,
        "MockingJay",
      );      
```
Then set up the `CommandResults` to be notified in its `results` attribute using the `queueResultsForNextExecuteCall` function as shown below.

```dart
mockGreetingCmd.queueResultsForNextExecuteCall([
    CommandResult<String, String>('Alice', null, null, true),
    CommandResult<String, String>('Alice', 'Hello Alice! Welcome.', null, false),    
]);
```

As a last step execute the mockCommand and test that the widget receives data correctly.

```dart
  testWidgets('Test Greeting text', (tester) async {
    MockCommand<String, String> mockGreetingCmd = MockCommand<String, String>(
      "Initial Value",
      ValueNotifier<bool>(true),
      false,
      false,
      true,
      true,
      "MockingJay",
    );
    mockGreetingCmd.queueResultsForNextExecuteCall([
      CommandResult<String, String>('Alice', null, null, true),
      CommandResult<String, String>(
          'Alice', 'Hello Alice! Welcome.', null, false),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ValueListenableBuilder<CommandResult<String, String>>(
            valueListenable: mockGreetingCmd.results,
            builder: (context, cmdResult, _) {
              print(cmdResult);
              return Text(cmdResult.data);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Text), findsOneWidget);
    expect(find.widgetWithText(Center, 'Initial Value'), findsOneWidget);

    // Execute the command and check again.
    mockGreetingCmd.execute();

    // verify the text is updated
    await tester.pumpAndSettle();
    expect(find.byType(Text), findsOneWidget);
    expect(
        find.widgetWithText(Center, 'Hello Alice! Welcome.'), findsOneWidget);
  });
```

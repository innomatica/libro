// https://docs.flutter.dev/app-architecture/design-patterns/command
import 'package:flutter/foundation.dart';
import './result.dart';

// command action definitions for with and without argument
typedef CommandAction0<T> = Future<Result<T>> Function();
typedef CommandAction1<T, A> = Future<Result<T>> Function(A);
typedef CommandAction2<T, A, B> = Future<Result<T>> Function(A, B);

abstract class Command<T> extends ChangeNotifier {
  bool _running = false;

  // running state
  bool get running => _running;

  // result object
  Result<T>? _result;

  /// true if action completed with error
  bool get error => _result is Error;

  /// true if action completed successfully
  bool get completed => _result is Ok;

  /// null if action is running or competed with error
  Result? get result => _result;

  /// clears the most recent action result
  void clearResult() {
    _result = null;
    notifyListeners();
  }

  // execute action
  Future<void> _execute(CommandAction0<T> action) async {
    // if currently running, ignore request
    if (_running) return;

    // start running
    _running = true;
    // with no result yet
    _result = null;
    notifyListeners();

    try {
      _result = await action();
    } finally {
      _running = false;
      notifyListeners();
    }
  }
}

// command without argument
final class Command0<T> extends Command<T> {
  Command0(this._action);

  final CommandAction0<T> _action;

  Future<void> execute() async {
    await _execute(_action);
  }
}

// command with one argument
final class Command1<T, A> extends Command<T> {
  Command1(this._action);

  final CommandAction1<T, A> _action;

  // facilitate argument
  Future<void> execute(A argument) async {
    await _execute(() => _action(argument));
  }
}

// command with two arguments
final class Command2<T, A, B> extends Command<T> {
  Command2(this._action);

  final CommandAction2<T, A, B> _action;

  // facilitate arguments
  Future<void> execute(A arg1, arg2) async {
    await _execute(() => _action(arg1, arg2));
  }
}

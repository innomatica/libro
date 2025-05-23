// Utility class to wrap result data
// https://docs.flutter.dev/app-architecture/design-patterns/result
//
// Usage:
//
// return Result.ok(value);
// return Result.error(error);
//
// switch (result) {
//   case Ok(): {
//     print(result.value);
//   }
//   case Error(): {
//     print(result.error);
//   }
// }
//

sealed class Result<T> {
  const Result();
  // factory constructor for successfule result
  factory Result.ok(T value) => Ok(value);
  // factory constructor for error result
  factory Result.error(Exception error) => Error(error);
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Error<T> extends Result<T> {
  const Error(this.error);
  final Exception error;
}

part of async;

class AsyncCompleter<T> {
  final Async<T> operation;

  AsyncCompleter({CancelEvent cancelEvent, int options}) : operation =
    new Async<T>._promise(cancelEvent: cancelEvent, options: options);

  void setCanceled() {
    _assert(!operation.isCompleted, 'Cannot cancel of the completed operation');
    operation._setCanceled();
  }

  void setException(Object exception, [Object stackTrace]) {
    if(exception == null) {
      throw new ArgumentError('exception: $exception');
    }

    _assert(!operation.isCompleted, 'Cannot set the exception of the completed operation');
    var asyncException = new AsyncException(new ExceptionWrapper(exception, stackTrace));
    operation._setException(asyncException);
  }

  void setResult(T result) {
    _assert(!operation.isCompleted, 'Cannot set the result of the completed operation');
    operation._setResult(result);
  }

  bool trySetCanceled() {
    if(!operation.isCompleted) {
      operation._setCanceled();
      return true;
    }

    return false;
  }

  bool trySetException(Object exception, [Object stackTrace]) {
    if(exception == null) {
      throw new ArgumentError('exception: $exception');
    }

    if(!operation.isCompleted) {
      var asyncException = new AsyncException(new ExceptionWrapper(exception, stackTrace));
      operation._setException(asyncException);
      return true;
    }

    return false;
  }

  bool trySetResult(T result) {
    if(!operation.isCompleted) {
      operation._setResult(result);
      return true;
    }

    return false;
  }

  void _assert(bool assertion, String message) {
    if(!assertion) {
      throw new StateError('$this: $message');
    }
  }
}

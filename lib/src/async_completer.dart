part of async;

class AsyncCompleter<T> {
  Async<T> _operation;

  AsyncCompleter({int options}) {
    _operation = new Async<T>._promise(options: options);
  }

  Async<T> get operation {
    return _operation;
  }

  void setCanceled() {
    _assert(!_operation.isCompleted, 'Cannot cancel of the completed operation');
    _operation._setCanceled();
  }

  void setException(Object exception, [StackTrace stackTrace]) {
    if(exception == null) {
      throw new ArgumentError('exception: $exception');
    }

    _assert(!_operation.isCompleted, 'Cannot set the exception of the completed operation');
    var asyncException = new AsyncException(new ExceptionWrapper(exception, stackTrace));
    _operation._setException(asyncException);
  }

  void setResult(T result) {
    _assert(!_operation.isCompleted, 'Cannot set the result of the completed operation');
    _operation._setResult(result);
  }

  bool trySetCanceled() {
    if(!_operation.isCompleted) {
      _operation._setCanceled();
      return true;
    }

    return false;
  }

  bool trySetException(Object exception, [StackTrace stackTrace]) {
    if(!_operation.isCompleted) {
      var asyncException = new AsyncException(new ExceptionWrapper(exception, stackTrace));
      _operation._setException(asyncException);
      return true;
    }

    return false;
  }

  bool trySetResult(T result) {
    if(!_operation.isCompleted) {
      _operation._setResult(result);
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

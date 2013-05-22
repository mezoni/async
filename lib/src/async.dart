part of async;

void _receiver() {
  port.receive((runnable, SendPort reply) {
    var response = {'result': null, 'exception': null, 'stackTrace': null};
    if(runnable is Runnable) {
      try {
        response['result'] = runnable.run();
      } catch(exception, stackTrace) {
        response['exception'] = exception;
        response['stackTrace'] = '$stackTrace';
      }
    } else {
      try {
        throw new StateError('$runnable is not Runnable');
      } catch(exception, stackTrace) {
        response['exception'] = exception;
        response['stackTrace'] = '$stackTrace';
      }
    }

    reply.send(response);
  });
}

class Async<T> implements Executable {
  static Async _current;
  static bool _debug;
  static int _nextId = 0;

  static const int _STATE_CANCELED = 1;
  static const int _STATE_DONE = 2;
  static const int _STATE_FAILED = 4;
  static const int _STATE_INVOKED = 8;
  static const int _STATE_PROMISE = 16;
  static const int _STATE_RUNNING = 32;
  static const int _STATE_SCHEDULED = 64;
  static const int _STATE_UNHNADLED_EXCEPTION = 128;
  static const int _STATE_WAIT_FOR_COMPLETION = 256;
  static const int _STATE_COMPLETED_MASK = _STATE_CANCELED | _STATE_FAILED | _STATE_DONE;

  // Async options
  static const int DETACH = 1;

  static Async get current {
    return _current;
  }

  String name;

  Function _action;
  Async _antecedent;
  CancelEvent _cancelEvent;
  CancelException _cancelException;
  Event _completedEvent = new Event();
  AsyncException _exception;
  int _flagState = 0;
  int _id = _nextId++;
  List<Async> _exceptionalChildren = [];
  int _numberOfUncompletedChildren = 1;
  int _numberOfContinuations = 1;
  int _options = 0;
  Async _parent;
  T _result;
  AsyncScheduler _scheduler;
  Object _stackTrace;

  factory Async(T action(), {CancelEvent cancelEvent, int options}) {
    var operation = new Async._internal(action, cancelEvent: cancelEvent,
      options: options);
    operation.start();
    return operation;
  }

  factory Async.create(T action(), {CancelEvent cancelEvent, int options}) {
    var operation = new Async._internal(action, cancelEvent: cancelEvent,
      options: options);
    return operation;
  }

  factory Async.delay(dynamic period, T action(), {CancelEvent cancelEvent,
    int options}) {
    Duration duration;
    if(period is int && period >= 0) {
      duration = new Duration(milliseconds: period);
    } else if(period is Duration) {
      duration = period;
    } else {
      throw new ArgumentError('period: $period');
    }

    var operation = new Async._internal(action, cancelEvent: cancelEvent,
      options: options);
    new Timer(duration, () {
      operation._scheduler.execute(operation);
    });

    return operation;
  }

  factory Async.fromFuture(Future<T> future, {CancelEvent cancelEvent,
    int options}) {
    if(future == null) {
      throw new ArgumentError('future: $future');
    }

    var completer = new AsyncCompleter<T>(cancelEvent: cancelEvent,
      options: options);
    future.then((T value) {
      completer.trySetResult(value);
    }, onError: (Object error) {
      completer.trySetException(error);
    });

    return completer.operation;
  }

  factory Async.fromResult(T result) {
    var completer = new AsyncCompleter<T>();
    completer.setResult(result);
    return completer.operation;
  }

  factory Async.fromStream(Stream stream, {CancelEvent cancelEvent, int options,
    bool cancelOnError}) {
    if(stream == null) {
      throw new ArgumentError('stream: $stream');
    }

    var result = new List();
    StreamSubscription streamSubscription;
    var completer = new AsyncCompleter<T>(cancelEvent: cancelEvent,
      options: options);

    void handleData(data) {
      result.add(data);
    };

    void handleDone() {
      var operation = completer.operation;
      if(!operation.isCanceled && !operation.isFailed) {
        completer.trySetResult(result);
      }
    }

    void handleError(Object error) {
      completer.trySetException(error);
    }

    try {
      streamSubscription = stream.listen(handleData, onError: handleError,
        onDone: handleDone, cancelOnError: cancelOnError);
    } catch(exception, stackTrace) {
      completer.trySetException(exception, stackTrace);
    }

    var operation = completer.operation;
    operation.onComplete(() {
      if(operation.isCanceled || operation.isFailed) {
        if(streamSubscription != null) {
          streamSubscription.cancel();
        }
      }
    });

    return operation;
  }

  factory Async.run(Runnable runnable, {CancelEvent cancelEvent, int options}) {
    var sender = spawnFunction(_receiver);
    var receiver = new ReceivePort();
    var completer = new AsyncCompleter(cancelEvent: cancelEvent,
      options: options);
    var closed = false;

    receiver.receive((result, _) {
      receiver.close();
      closed = true;
      var exception = result['exception'];
      if(exception != null) {
        var stackTrace = result['stackTrace'];
        completer.trySetException(exception, stackTrace);
      } else {
        completer.trySetResult(result['result']);
      }
    });

    sender.send(runnable, receiver.toSendPort());
    var operation = completer.operation;
    operation.onComplete(() {
      if(!closed) {
        receiver.close();
      }
    });

    return operation;
  }

  factory Async._continuation(action(), Async antecedent) {
    if(antecedent == null) {
      throw new ArgumentError('antecedent: $antecedent');
    }

    var operation = new Async._internal(action, antecedent: antecedent);
    return operation;
  }

  factory Async._promise({CancelEvent cancelEvent, int options}) {
    var operation = new Async._internal(null, cancelEvent: cancelEvent,
      options: options, promise: true);
    operation._execute();
    return operation;
  }

  Async._internal(this._action, {Async antecedent, CancelEvent cancelEvent,
    int options, bool promise}) {
    if(_action == null && promise != true) {
      throw new ArgumentError('action: $_action');
    }

    if(options != null) {
      _options = options;
    }

    if(_debug == true) {
      if(_current == null) {
        try {
          throw null;
        } catch(exception, stackTrace) {
          // Call site information
          _stackTrace = stackTrace;
        }
      }
    }

    if(cancelEvent != null) {
      _cancelEvent = cancelEvent;
      _cancelEvent += () {
        _cancelByEvent();
      };
    }

    if(_current != null && (_options & DETACH) == 0) {
      _parent = _current;
      _parent._addChild(this);
      var prev = _parent;
      while(prev != null) {
        if(prev._cancelEvent != null) {
          prev._cancelEvent += () {
            _cancelByEvent();
          };
        }

        prev = prev._parent;
      }
    }

    if(antecedent != null) {
      _antecedent = antecedent;
      _antecedent._addContinuation(this);
    }

    if(promise == true) {
      _flagState |= _STATE_PROMISE;
    } else {
      _scheduler = AsyncScheduler.current;
    }
  }

  static Async<List> whenAll(Iterable<Async> operations,
    {CancelEvent cancelEvent, int options}) {
    if(operations == null) {
      throw new ArgumentError('operations: $operations');
    }

    if(operations.isEmpty) {
      return new Async(() {
        return [];
      });
    }

    var canceled = false;
    var completer = new AsyncCompleter<List<Async>>(cancelEvent: cancelEvent,
      options: options);
    var count = operations.length;
    AsyncException exception;
    var failed = false;
    var indices = new Map<int, Object>();
    var processed = 0;
    var results = new List(count);

    void complete(Async operation) {
      processed++;
      if(operation.isCanceled) {
        canceled = true;
      }

      if(operation.isFailed) {
        if(exception == null) {
          exception = operation.exception;
        } else {
          exception = new AsyncException([exception, operation.exception]);
        }

        failed = true;
      }

      if(!canceled && !failed) {
        results[indices[operation.id]] = operation.result;
        if(processed == count) {
          completer.trySetResult(results);
        }
      } else {
        if(processed == count) {
          if(failed) {
            completer.trySetException(exception);
          } else {
            completer.trySetCanceled();
          }
        }
      }
    }

    var i = 0;
    for(var operation in operations) {
      if(operation == null || operation is! Async) {
        throw new ArgumentError('The operations list contained an illegal operation.');
      }

      var id = operation.id;
      indices[id] = i++;
      operation.continueWith((Async operation) {
        try {
          complete(operation);
        } catch(exception, stackTrace) {
          completer.trySetException(exception, stackTrace);
        }
      });
    }

    return completer.operation;
  }

  static Async<Async> whenAny(List<Async> operations, {CancelEvent cancelEvent,
    int options}) {
    if(operations == null) {
      throw new ArgumentError('operations: $operations');
    }

    if(operations.isEmpty) {
      throw new StateError('The operations list is empty');
    }

    var completer = new AsyncCompleter<Async>(cancelEvent: cancelEvent,
      options: options);
    var done = false;

    void complete(Async operation) {
      if(!done) {
        done = true;
        completer.trySetResult(operation);
      }
    };

    var count = operations.length;
    for(var i = 0; i < count; i++) {
      var operation = operations[i];
      if(operation == null || operation is! Async) {
        throw new ArgumentError('The operations list contained an illegal operation.');
      }

      operation.onComplete(() {
        try {
          complete(operation);
        } catch(exception, stackTrace) {
          completer.trySetException(exception, stackTrace);
        }
      });
    }

    return completer.operation;
  }

  AsyncException get exception {
    if((_flagState & _STATE_FAILED) != 0) {
      _flagState &= ~_STATE_UNHNADLED_EXCEPTION;
      return _exception;
    }

    return null;
  }

  int get id {
    return _id;
  }

  bool get isCanceled {
    return (_flagState & _STATE_CANCELED) != 0;
  }

  bool get isCompleted {
    return (_flagState & _STATE_COMPLETED_MASK) != 0;
  }

  bool get isFailed {
    return (_flagState & _STATE_FAILED) != 0;
  }

  T get result {
    if(isCompleted) {
      return _result;
    }

    _assert(false, 'Cannot get the result of the not completed operation');
  }

  void set result(T result) {
    if((_flagState & _STATE_RUNNING) != 0 ||
      (_flagState & _STATE_WAIT_FOR_COMPLETION) != 0 &&
      (_flagState & _STATE_PROMISE) == 0) {
      _result = result;
      return;
    }

    _assert((_flagState & _STATE_PROMISE) == 0, 'Cannot set the result of the promise operation');
    _assert(false, 'Cannot set the result of the operation');
  }

  AsyncStatus get status {
    if((_flagState & _STATE_DONE) != 0) {
      return AsyncStatus.DONE;
    }

    if((_flagState & _STATE_FAILED) != 0) {
      return AsyncStatus.FAILED;
    }

    if((_flagState & _STATE_CANCELED) != 0) {
      return AsyncStatus.CANCELED;
    }

    if((_flagState & _STATE_RUNNING) != 0) {
      return AsyncStatus.RUNNING;
    }

    if((_flagState & _STATE_WAIT_FOR_COMPLETION) != 0) {
      return AsyncStatus.WAIT_FOR_COMPLETION;
    }

    if((_flagState & _STATE_SCHEDULED) != 0) {
      return AsyncStatus.SCHEDULED;
    }

    if((_flagState & _STATE_INVOKED) == 0) {
      return AsyncStatus.CREATED;
    }
  }

  Future<T> asFuture() {
    var completer = new Completer<T>();
    onComplete(() {
      if(isFailed) {
        completer.completeError(_exception);
      } else if(isCanceled) {
        completer.completeError(_cancelException);
      } else {
        completer.complete(_result);
      }
    });

    return completer.future;
  }

  Async catchException(void action(AsyncException exception)) {
    if(action == null) {
      throw new ArgumentError('action: $action');
    }

    return continueWith((Async<T> antecedent) {
      if(!antecedent.isFailed && !antecedent.isCanceled) {
        return antecedent.result;
      };

      if(antecedent.isFailed) {
        action(exception);
        // Must throw an exception if not handled
      };

      _current._setCanceled();
    });
  }

  Async continueWith(dynamic action(Async<T> antecedent)) {
    if(action == null) {
      throw new ArgumentError('action: $action');
    }

    var continuation = new Async._continuation(() => action(this), this);
    _completedEvent += () => continuation.start();
    return continuation;
  }

  void onComplete(void action()) {
    _completedEvent += action;
  }

  void execute() {
    _execute();
  }

  Async<T> start() {
    if((_flagState & _STATE_INVOKED) != 0 || (_flagState & _STATE_SCHEDULED) != 0) {
      _assert(false, 'Impossible to start the operation for the second time');
    }

    _flagState |= _STATE_SCHEDULED;
    _scheduler.enqueue(this);
    return this;
  }

  String toString() {
    if(name != null && !name.isEmpty) {
      return 'Async$_id($name)';
    }

    return 'Async$_id';
  }

  Async then(dynamic action(T result)) {
    if(action == null) {
      throw new ArgumentError('action: $action');
    }

    return continueWith((Async<T> antecedent) {
      if(!_makeTransition(antecedent, _current)) {
        return null;
      }

      return action(antecedent.result);
    });
  }

  Async unwrap() {
    return then((Async wrapped) {
      var current = Async.current;
      wrapped.then((result) {
        current._setResult(result);
      });

      return null;
    });
  }

  void _addChild(Async child) {
    _numberOfUncompletedChildren++;
  }

  void _addContinuation(Async continuation) {
    _numberOfContinuations++;
  }

  void _assert(bool assertion, String message) {
    if(!assertion) {
      throw new StateError('$this: $message');
    }
  }

  void _cancelByEvent() {
    if((_flagState & _STATE_COMPLETED_MASK) != 0) {
      return;
    }

    _setCanceled();
  }

  void _execute() {
    var previous = Async._current;
    Async._current = this;
    _assert((_flagState & _STATE_INVOKED) == 0, 'Cannot execute operation for the second time');
    _flagState &= ~_STATE_SCHEDULED;
    _flagState |= _STATE_INVOKED;
    _flagState |= _STATE_RUNNING;
    if(_cancelException == null && _exception == null && (_flagState & _STATE_PROMISE) == 0) {
      try {
        _result = _action();
      } catch(exception, stackTrace) {
        if(exception is CancelException) {
          _cancelException = exception;
        } else {
          var stackTraces = [];
          if(_debug == true) {
            var prev = this;
            while(prev != null) {
              if(prev._stackTrace != null) {
                stackTraces.add(prev._stackTrace);
              }

              prev = prev._parent;
            }
          }

          stackTraces.add(stackTrace);
          _setException(new AsyncException(new ExceptionWrapper(exception, stackTraces)));
        }
      }
    }

    _flagState &= ~_STATE_RUNNING;
    _flagState |= _STATE_WAIT_FOR_COMPLETION;
    if((_flagState & _STATE_PROMISE) == 0) {
      _initiateCompletion();
    }

    Async._current = previous;
  }

  void _initiateCompletion() {
    _processChildCompletion(this);
  }

  bool _makeTransition(Async previous, Async next) {
    if(previous.isFailed) {
      next._setException(previous.exception);
      return false;
    } else if(previous.isCanceled) {
      next._setCanceled();
      return false;
    }

    return true;
  }

  void _processChildCompletion(Async child) {
    _numberOfUncompletedChildren--;
    if(child != this) {
      if(child.isFailed) {
        _exceptionalChildren.add(child);
      } else if(child.isCanceled) {
        _setCanceled();
      }
    }

    if(_numberOfUncompletedChildren == 0) {
      _flagState &= ~_STATE_WAIT_FOR_COMPLETION;
      if(!_exceptionalChildren.isEmpty) {
        var unhandledExceptions = [];
        for(var exceptionalChild in _exceptionalChildren) {
          if((exceptionalChild._flagState & _STATE_UNHNADLED_EXCEPTION) != 0) {
            unhandledExceptions.add(exceptionalChild.exception);
          }
        }

        if(!unhandledExceptions.isEmpty) {
          _setException(new AsyncException(unhandledExceptions));
          _flagState |= _STATE_FAILED;
        }
      }

      if(_exception != null) {
        _flagState |= _STATE_FAILED;
      }

      if((_flagState & _STATE_FAILED) == 0 && _cancelException != null) {
        _flagState |= _STATE_CANCELED;
      }

      if((_flagState & _STATE_CANCELED) == 0 && (_flagState & _STATE_FAILED) == 0) {
        _flagState |= _STATE_DONE;
      }

      _completedEvent.set();
      if(_parent != null) {
        _parent._processChildCompletion(this);
      }

      _processContinuationCompletion(this);
    }
  }

  void _processContinuationCompletion(Async continuation) {
    if(_numberOfContinuations > 0) {
      _numberOfContinuations--;
    }

    if(_antecedent != null) {
      _antecedent._processContinuationCompletion(this);
    }

    if(_numberOfContinuations == 0) {
      if(_parent == null && (_flagState & _STATE_UNHNADLED_EXCEPTION) != 0) {
        _throwException();
      }
    }
  }

  void _setCanceled() {
    if((_flagState & _STATE_COMPLETED_MASK) != 0) {
      _assert(false, 'Async._setCanceled() called after completion');
      return;
    }

    _cancelException = new CancelException();
    if(_cancelEvent != null && !_cancelEvent.isSet) {
      _cancelEvent.set();
    }

    if((_flagState & _STATE_PROMISE) != 0) {
      _initiateCompletion();
    }
  }

  void _setException(AsyncException exception) {
    if((_flagState & _STATE_COMPLETED_MASK) != 0) {
      _assert(false, 'Async._setException() called after completion');
      return;
    }

    _flagState |= _STATE_UNHNADLED_EXCEPTION;
    if(_exception == null) {
      _exception = exception;
    } else {
      _exception = new AsyncException([_exception, exception]);
    }

    if((_flagState & _STATE_PROMISE) != 0) {
      _initiateCompletion();
    }
  }

  void _setResult(T result) {
    if((_flagState & _STATE_COMPLETED_MASK) != 0) {
      _assert(false, 'Async._setResult() called after completion');
      return;
    }

    _result = result;

    if((_flagState & _STATE_PROMISE) != 0) {
      _initiateCompletion();
    }
  }

  void _throwException() {
    Timer.run(() { throw _exception; });
  }
}

class AsyncStatus {
  static const AsyncStatus CANCELED = const AsyncStatus('CANCELED');
  static const AsyncStatus CREATED = const AsyncStatus('CREATED');
  static const AsyncStatus DONE = const AsyncStatus('DONE');
  static const AsyncStatus FAILED = const AsyncStatus('FAILED');
  static const AsyncStatus RUNNING = const AsyncStatus('RUNNING');
  static const AsyncStatus SCHEDULED = const AsyncStatus('SCHEDULED');
  static const AsyncStatus WAIT_FOR_COMPLETION = const AsyncStatus('WAIT_FOR_COMPLETION');

  final String name;

  const AsyncStatus(this.name);

  String toString() {
    return name;
  }
}

part of async;

class AsyncScheduler {
  static final AsyncScheduler current = new AsyncScheduler();

  int allottedTime = 50;

  bool _inTimer = false;
  ListQueue<Async> _scheduled = new ListQueue<Async>();

  void enqueue(Executable operation) {
    if(_scheduled.isEmpty && !_inTimer) {
      _setTimer();
    }

    _scheduled.add(operation);
  }

  void execute(Executable  operation, [bool scheduled]) {
    if(scheduled == true) {
      _scheduled.remove(operation);
    }

    operation.execute();
  }

  void _idle() {
  }

  void _onTimer() {
    _inTimer = true;
    if(_scheduled.isEmpty) {
      _idle();
      _inTimer = false;
      return;
    }

    var sw = new Stopwatch()..start();
    do {
      var operation = _scheduled.first;
      execute(operation, true);
      if(_scheduled.isEmpty) {
        break;
      }

      if(sw.elapsedMilliseconds > allottedTime) {
        break;
      }
    } while(true);

    _setTimer();
    _inTimer = false;
  }

  void _setTimer() {
    Timer.run(() => _onTimer());
  }
}

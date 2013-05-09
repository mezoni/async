part of async;

class AsyncScheduler {
  static final AsyncScheduler current = new AsyncScheduler();

  int allottedTime = 50;

  bool _inTimer = false;
  ListQueue<Async> _scheduled = new ListQueue<Async>();

  void enqueue(Async operation) {
    if(_scheduled.isEmpty && !_inTimer) {
      _setTimer();
    }

    _scheduled.add(operation);
  }

  void execute(Async operation, [bool scheduled]) {
    if(scheduled == true) {
      _scheduled.remove(operation);
    }

    operation._execute();
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

    var started = new DateTime.now().millisecondsSinceEpoch;
    do {
      var operation = _scheduled.first;
      execute(operation, true);
      if(_scheduled.isEmpty) {
        break;
      }

      var now = new DateTime.now().millisecondsSinceEpoch;
      if(now - started > allottedTime) {
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

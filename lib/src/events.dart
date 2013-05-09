part of async;

class NotifyEvent {
  ListQueue<Function> _actions = new ListQueue<Function>();

  operator +(action()) {
    _actions.add(action);
    return this;
  }

  void raise() {
    for(var action in _actions) {
      if(action != null) {
        action();
      }
    }
  }
}

class Event {
  ListQueue<Function> _actions = new ListQueue<Function>();
  bool _set = false;

  bool get isSet {
    return _set;
  }

  void set() {
    _set = true;
    _process();
  }

  operator +(action()) {
    _actions.add(action);
    _process();
    return this;
  }

  void _process() {
    if(!_set) {
      return;
    }

    var length = _actions.length;
    for(var i = 0; i < length; i++) {
      var action = _actions.removeFirst();
      if(action != null) {
        action();
      }
    }
  }
}

class CancelEvent extends Event {
}

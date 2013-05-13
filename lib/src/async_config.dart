part of async;

class AsyncConfig {
  static void set(String name, value) {
    switch(name) {
      case 'DEBUG':
        _setDebug(value);
        break;
    }
  }

  static void _setDebug(value) {
    if(value == true || value == false) {
      Async._debug = value;
    }
  }
}

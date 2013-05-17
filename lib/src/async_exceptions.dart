part of async;

class ExceptionWrapper {
  final Object exception;
  final Object stackTrace;

  ExceptionWrapper(this.exception, [this.stackTrace]);
}

class AsyncException implements Exception {
  List<ExceptionWrapper> _exceptions = [];

  AsyncException([exceptions]) {
    if(exceptions is Iterable) {
      for(var exception in exceptions) {
        _addException(exception);
      }
    } else {
      _addException(exceptions);
    }
  }

  Object get exception {
    if(_exceptions.isEmpty) {
      return null;
    }

    return _exceptions[0].exception;
  }

  List get exceptions {
    var result = [];
    for(var exception in _exceptions) {
      result.add(exception.exception);
    }

    return result;
  }

  void handle(bool predicate(Object exception)) {
    if(predicate == null) {
      throw new ArgumentError('predicate: $predicate');
    }

    var unhandled = [];
    var flat = [];
    var flattened = _flatten(this, flat);
    for(var exception in flat) {
      if(predicate(exception.exception) != true) {
        unhandled.add(exception);
      }
    }

    if(!unhandled.isEmpty) {
      if(unhandled.length != flat.length) {
        throw new AsyncException(unhandled);
      } else {
        throw this;
      }
    }
  }

  AsyncException flatten() {
    List<ExceptionWrapper> flat = [];
    if(_flatten(this, flat)) {
      return new AsyncException(flat);
    }

    return this;
  }

  String toString() {
    List<ExceptionWrapper> exceptions = [];
    _flatten(this, exceptions);
    var strings = [];
    var length = exceptions.length;
    if(length != 0) {
      strings.add('AsyncException: $length exceptions(s)');
    }
    for(var i = 0; i < length; i++) {
      strings.add('Exception $i:');
      var exception = _exceptionToString(exceptions[i].exception);
      var stackTrace = exceptions[i].stackTrace;
      strings.add(_format(exception, null, stackTrace));
    }

    return strings.join('\r---------------------------------------\r');
  }

  void _addException(exception) {
    if(exception != null) {
      if(exception is ExceptionWrapper) {
        _exceptions.add(exception);
      } else {
        _exceptions.add(new ExceptionWrapper(exception));
      }
    }
  }

  bool _flatten(AsyncException asyncException, List<ExceptionWrapper> flat) {
    bool flattened = false;
    for(var exception in asyncException._exceptions) {
      if(exception.exception is AsyncException) {
        flattened = true;
        _flatten(exception.exception, flat);
      //} else if(exception.exception is AsyncError) {
      //  flattened = true;
      //  _flattenAsyncError(exception.exception, flat);
      } else {
        flat.add(exception);
      }
    }

    return flattened;
  }

  /*
  void _flattenAsyncError(AsyncError asyncError, List<ExceptionWrapper> flat) {
    AsyncError exception = asyncError;
    while(exception != null) {
      var error = exception.error;
      if(error != null) {
        flat.add(new ExceptionWrapper(error, exception.stackTrace));
      }

      exception = exception.cause;
    }
  }
  */

  String _exceptionToString(Object exception) {
    var message;
    try {
      message = exception.toString();
    } catch (e) {
      message = Error.safeToString(exception);
    }

    return message;
  }

  String _format(Object name, Object message, Object stackTrace) {
    var msg = '';
    if(message != null) {
      msg = ': $message';
    }

    var nostack = 'Stack trace: No information about stack trace';
    if(stackTrace == null) {
      stackTrace = nostack;
    } else {
      if(stackTrace is List) {
        if(stackTrace.isEmpty) {
          stackTrace = nostack;
        } else {
          stackTrace = 'Stack trace:\r${stackTrace.join('\r')}';
        }
      } else {
        stackTrace = 'Stack trace:\r$stackTrace';
      }
    }

    return '$name$msg\r$stackTrace';
  }
}

class CancelException implements Exception {
  final String message;

  CancelException([this.message]);

  String toString() {
    if(message == null || message.isEmpty) {
      return 'CancelException';
    }

    return 'CancelException: $message';
  }
}

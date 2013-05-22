library async.example.example_using_stream;

import 'package:async/async.dart';

import 'dart:async';

void main() {
  var example = new Example();
  example.run();
}

class StreamManager {
  static Async<Stream> createStreamAsync() {
    return new Async<Stream>(() {
      var wrapped = [null];
      var controller = new StreamController(onCancel: () => _cancel(wrapped));
      wrapped[0] = controller;
      _provideData(controller, 0);
      return controller.stream;
    });
  }

  static void _cancel(List<StreamController> wrapped) {
    var controller = wrapped[0];
    if(controller != null) {
      controller.close();
    }
  }

  static void _provideData(StreamController controller, int i) {
    if(controller.isClosed) {
      return;
    }

    controller.add(i);
    i++;
    if(i < 10) {
      print('Stream provide data: $i');
      new Timer(new Duration(milliseconds: 500),
        () => _provideData(controller, i));
    } else {
      controller.close();
    }
  }
}

class Example {
  void run() {
    var task = new Async(() {
      _runTask(500);
    })
    .continueWith((ant) {
      _runTask(2000);
    })
    .continueWith((ant) {
      _runTask(8000);
    });
  }

  void _runTask(int timeout) {
    print('================================');
    print('Staring task with timeout $timeout');
    var ce = new CancelEvent();
    var work  = new Async(() {
      var current = Async.current;
      _doWork().then((result) {
        print('Result length: ${result.length}');
        current.result = result;
      });
    }, cancelEvent: ce);

    Async.whenAny([work]).then((result) {
      print('Print status of work: ${result.status}');
    });

    _cancelWork(timeout, ce).start();
  }

  Async<List<int>> _readFromStreamAsync(Stream stream) {
    return new Async<List<int>>(() {
      Async<List<int>> current = Async.current;
      var streamTask = new Async<List<int>>.fromStream(stream);
      streamTask.then((list) {
        current.result = list;
      });
    });
  }

  Async _cancelWork(int period, CancelEvent cancelEvent) {
    // Return task in "cold" state to start it later
    return new Async.create(() {
      new Async.delay(period, () {
        print('========>');
        print('Cancelling tasks after $period ms...');
        cancelEvent.set();
      }, options: Async.DETACH);
    });
  }

  Async<Stream> _createStream() {
    return new Async<Stream>(() {
      Async<Stream> current = Async.current;
      print('Creating stream...');
      StreamManager.createStreamAsync().then((stream) {
        print('Stream created.');
        current.result = stream;
      });
    });
  }

  Async<List<int>> _doWork() {
    return new Async<List<int>>(() {
      Async<List<int>> current = Async.current;
      var stream = _createStream();
      stream.then((stream) {
        return _readFromStreamAsync(stream).then((data) {
          print('Transfer from stream completed');
          current.result = data;
        });
      });
    });
  }
}

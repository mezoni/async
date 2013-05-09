import 'package:async/async.dart';

import 'dart:async';
import 'dart:isolate';
import 'dart:math';

void main() {
  var example = new Example();
  var task = new Async(() {
    example.run(500);
  });

  task.continueWith((ant) {
    example.run(2000);
  }).continueWith((ant) {
    example.run(8000);
  });

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
  void run(int timeout) {
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
      var ce = Async.current.cancelEvent;
      var streamTask = new Async<List<int>>.fromStream(stream, cancelEvent: ce);
      streamTask.then((list) {
        current.result = list;
      });

      return null;
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

      return null;
    });
  }

  Async<List<int>> _doWork() {
    return new Async<List<int>>(() {
      Async<List<int>> current = Async.current;
      var stream = _createStream();
      var data = stream.then((stream) {
        return _readFromStreamAsync(stream).then((data) {
          print('Transfer from stream completed');
          current.result = data;
          return null;
        });
      });

      return null;
    });
  }
}

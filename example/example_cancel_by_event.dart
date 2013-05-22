library async.example.example_cancel_by_event;

import 'package:async/async.dart';

void main() {
  var example = new Example();
  example.run();
}

class Example {
  void run() {
    var ce = new CancelEvent();
    new Async(() {
      var processed = 0;
      var total = 500000;
      print('Starting, scheduling $total operations.');
      var sw0 = new Stopwatch();
      sw0.start();
      for(var i = 0; i < total; i++) {
        var work = new Async(() {
          processed++;
        });
      }

      sw0.stop();
      var elapsed = sw0.elapsedMilliseconds;
      var speed = '';
      if(elapsed > 0) {
        speed = '(${total ~/ elapsed * 1000} op/sec)';
      }

      print('Scheduled $total operations in $elapsed ms $speed');
      var sw1 = new Stopwatch();
      sw1.start();
      // Who did not, that was late
      var timeout = 100;
      new Async.delay(timeout, () {
        sw1.stop();
        print('Canceling after $timeout ms.');
        var sw2 = new Stopwatch();
        sw2.start();
        // Cancel by event
        ce.set();
        sw2.stop();
        var elapsed1 = sw1.elapsedMilliseconds;
        var elapsed2 = sw2.elapsedMilliseconds;
        var canceled = total - processed;

        var speed1 = '';
        if(elapsed > 0) {
          speed1 = '(${processed ~/ elapsed1 * 1000} op/sec)';
        }

        var speed2 = '';
        if(elapsed > 0) {
          speed2 = '(${canceled ~/ elapsed2 * 1000} op/sec)';
        }

        print('Processed: $processed from $total operations in $elapsed1 ms $speed1');
        print('Canceled by event: $canceled operations in $elapsed2 ms $speed2');
      });

    }, cancelEvent: ce)
    .continueWith((ant) {
      print('Finally: The end.');
    });
  }
}

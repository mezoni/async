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
      var total = 15000;
      print('Started, scheduling $total operation(s).');
      for(var i = 0; i < total; i++) {
        var work = new Async(() {
          processed++;
          for(var delay = 0; delay < 100000; delay++) {};
          print(i);
        });
      }

      var sw1 = new Stopwatch();
      sw1.start();
      // Who did not, that was late
      new Async.delay(200, () {
        sw1.stop();
        print('Canceling...');
        var sw2 = new Stopwatch();
        sw2.start();
        // Cancel by event
        ce.set();
        sw2.stop();
        var elapsed1 = sw1.elapsedMilliseconds;
        var elapsed2 = sw2.elapsedMilliseconds;
        var canceled = total - processed;

        print('Processed: $processed from $total operation(s) in $elapsed1 ms.');
        print('Canceled by event: $canceled operation(s) in $elapsed2 ms.');
      });

    }, cancelEvent: ce)

    .continueWith((ant) {
      print('The end.');
    });
  }
}

import 'package:async/async.dart';

void main() {
  var example = new Example();
  example.run();
}

class Example {
  void run() {
    var ce = new CancelEvent();
    var timeout = 4000;
    new Async.delay(timeout, () {
      print('Canceling long running tasks after $timeout ms...');
      ce.set();
    });

    var numberOfTasks = 2;
    for(var i = 0; i < numberOfTasks; i++) {
      var name = "LongTask #$i";
      var times = (i + 1) * 2;
      new Async.run(new LongRunningTask(name, times), cancelEvent: ce)
      .continueWith((ant) {
        var status = ant.status;
        var arrow = '<===============';
        if(status == AsyncStatus.DONE) {
          print('$name complete, result: ${ant.result} $arrow');
        } else {
          print('$name $status $arrow');
        }
      });
    }
  }
}

class LongRunningTask extends Runnable {
  final String name;
  final int times;

  LongRunningTask(this.name, this.times) {
    if(times == null || times < 0) {
      throw new ArgumentError('times: $times');
    }
  }

  String run() {
    for(var i = 0; i < times; i ++) {
      doWork(i);
    }

    return '$times from $times';
  }

  int doWork(int i) {
    var done = i + 1 == times ? 'done' : '';
    print('Multithreading task: $name, ${i + 1} from $times $done');
    _simulate(1500);
  }

  void _simulate(int ms) {
    var sw = new Stopwatch();
    sw.start();
    while(true) {
      if(sw.elapsedMilliseconds > ms) {
        break;
      }
    }
  }
}
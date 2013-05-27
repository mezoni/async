library async.example.example_using_when_all;

import 'package:async/async.dart';

void main() {
  var example = new Example();
  example.run();
}

class Example {
  void run() {
    var sw = new Stopwatch();
    sw.start();
    var task1 = new Async.run(new SimpleParallelTask('Task1', 1));
    var task2 = new Async.run(new SimpleParallelTask('Task2', 2));
    var task3 = new Async.run(new SimpleParallelTask('Task3', 3));
    Async.whenAll([task1, task2, task3])
    .then((List results) {
      sw.stop();
      var ellapsed = sw.elapsedMilliseconds;
      print('Results $results obtained from ${results.length} tasks in $ellapsed ms.');
    });
  }
}

class SimpleParallelTask implements Runnable {
  final int seconds;
  final String name;

  SimpleParallelTask(this.name, this.seconds);

  int run() {
    print('$name running (in blocking mode) for $seconds sec.');
    loop(seconds);
    print('$name finshed.');
    return seconds * 2;
  }

  void loop(int seconds) {
    var sw = new Stopwatch();
    sw.start();
    while(true) {
      if(sw.elapsedMilliseconds / 1000 > seconds) {
        break;
      }
    }

    sw.stop();
  }
}

import 'package:async/async.dart';

import 'dart:async';
import 'dart:isolate';
import 'dart:math';

void main() {
  var example = new Example();
  example.run();
}

class Example {
  void run() {
    get100_500().then((_100_500) => print(_100_500));
  }

  Async<int> get100() {
    return new Async(() => 100);
  }

  Async<int> get500() {
    return new Async(() => 500);
  }

  Async<int> make100_500(int _100, int _500) {
    return new Async<int>(() {
      return _100 * 1000 + _500;
    });
  }

  Async<int> get100_500() {
    return new Async(() {
      var current = Async.current;
      var _100 = get100();
      var _500 = get500();
      Async.whenAll([_100, _500]).then((all) {
        make100_500(all[0], all[1]).then((result) {
          current.result = result;
        });
      });

      return null;
    });
  }
}

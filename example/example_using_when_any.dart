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
    new Async(() {
      var inner1 = new Async(() {
        throw new StateError('error in inner1');
      });

      var inner2 = new Async(() {
        throw new StateError('error in inner2');
      });


      var inner3 = new Async(() {
        throw new StateError('error in inner3');
      });

      new Async(() {
        Async.whenAny([inner1]).then((work) {
          print('Any: $work, status: ${work.status}');
        });
      });
    })

    .catchException((ae) {
      ae.handle((ex) {
        if(ex is StateError) {
          print('Handled exception: $ex');
          return true;
        }
      });
    });
  }
}

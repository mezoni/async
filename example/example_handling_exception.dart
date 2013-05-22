library async.example.example_handling_exception;

import 'package:async/async.dart';

void main() {
  var example = new Example();
  example.run();
}

class Example {
  void run() {
    new Async(() {
      new Async(() {
        print('inner1: step 1');
        return 1;
      })
      .then((prev) {
        print('inner1: step 2');
        throw null;
      })
      .then((prev) {
        print('inner1: step 3');
        return prev + 1;
      })
      .catchException((ae) {
        ae.handle((ex) {
          if(ex is NullThrownError) {
            print('inner1: handled exception: $ex');
            return true;
          }
        });
      })
      .continueWith((ant) {
        print('inner1: cleanup.');
      })
      .continueWith((ant) {
        throw new StateError('Something bad in inner1');
      });

      new Async(() {
        print('inner2: executed');
        throw new RangeError('inner2 failed');
      });

      throw new UnsupportedError('All supported. Do not worry');
    })
    .catchException((ae) {
      ae.handle((ex) {
        if(ex is UnsupportedError) {
          print('outer1: handled exception UE: $ex');
          return true;
        }

        if(ex is StateError) {
          print('outer1: handled exception SE: $ex');
          return true;
        }

        if(ex is RangeError) {
          print('outer1: handled exception RE: $ex');
          return true;
        }
      });
    });
  }
}

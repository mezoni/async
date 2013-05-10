import 'package:async/async.dart';

import 'dart:async';

void main() {
  var outer = new Async(() {
    new Async(() {
      print('inner1');
      throw new StateError('State error in inner1');
    });

    new Async(() {
      print('inner2');
      throw new RangeError('Range error in inner2');
    });
  });

  outer.catchException((ae) {
    ae.handle((exception) {
      if(exception is StateError) {
        print('Handled state error $exception');
        return true;
      }
      if(exception is RangeError) {
        print('Handled range error $exception');
        return true;
      }

    });
  });
}

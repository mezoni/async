import 'dart:async';

import 'package:async/async.dart';
import 'package:unittest/unittest.dart';

void main() {
  var tests = [];
  tests.add(test_deepest_child_canceled);
  tests.add(test_stream_closed_when_cancel);
  run_tests(tests);
}

void run_tests(List tests) {
  var count = tests.length;
  var prev = new Async(() {});
  for(var i = 0; i < count; i++) {
    var test = tests[i];
    prev = prev.continueWith((ant) {
      test();
    });

    prev = prev.continueWith((ant) {
      if(ant.isFailed) {
        ant.exception.handle((exception) {
          if(exception is TestFailure) {
            print('$exception');
            return true;
          }
        });
      }
    });
  }
}

void test_deepest_child_canceled() {
  var ce = new CancelEvent();
  AsyncStatus status = null;
  new Async(() {
    new Async(() {
      new Async(() {
        new Async.delay(150, () {
        }).continueWith((ant) {
          status = ant.status;
        });
      });
    });
  }, cancelEvent: ce);

  new Async.delay(100, () {
    ce.set();
  });

  new Async.delay(200, () {
    expect(status, anyOf([AsyncStatus.CANCELED, null]),
      reason: 'test deepest child canceled');
  });
}

void test_stream_closed_when_cancel() {
  var ce = new CancelEvent();
  var wrapped = [null];
  var controller = new StreamController(onCancel: () => wrapped[0].close());
  wrapped[0] = controller;
  var stream = controller.stream;
  new Async(() {
    new Async.fromStream(stream);
  }, cancelEvent: ce);

  new Async.delay(100, () {
    ce.set();
  });

  new Async.delay(200, () {
    expect(controller.isClosed, true,
      reason: 'test stream closed when cancel');
  });
}

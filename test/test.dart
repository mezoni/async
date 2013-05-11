import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:unittest/unittest.dart';

import '../example/example_access_pub_dartlang_org.dart' as example01;
import '../example/example_cancel_by_event.dart' as example02;
import '../example/example_handling_exception.dart' as example03;
import '../example/example_show_latest_packages.dart' as example04;
import '../example/example_show_all_packages.dart' as example05;
import '../example/example_using_stream.dart' as example06;
import '../example/example_using_when_all.dart' as example07;
import '../example/example_using_when_any.dart' as example08;

void main() {
  var tests = [];
  tests.add({'name': 'Deepest child canceled', 'test': _test_deepest_child_canceled});
  tests.add({'name': 'Stream closed when cancel', 'test': _test_stream_closed_when_cancel});
  tests.addAll(_get_example_tests());
  _run_tests(tests);
}

void _run_tests(List tests) {
  var failed = [];
  var passed = [];
  var count = tests.length;
  var prev = new Async(() {});
  for(var i = 0; i < count; i++) {
    var test = tests[i];
    var name = test['name'];
    prev = prev.continueWith((ant) {
      new Async(() {
        test['test']();
      }, options: Async.DETACH)
      .continueWith((ant) {
        if(ant.isFailed) {
          ant.exception.handle((exception) {
            if(exception is TestFailure) {
              failed.add('Failed: "$name"');
              failed.add('$exception');
              return true;
            }
          });
        } else {
          passed.add('Passed: "$name"');
        }
      });
    });
  }

  prev.continueWith((ant) {
    stdout.writeln('========================================================');
    stdout.writeln('Test results');
    if(!passed.isEmpty) {
      for(var line in passed) {
        stdout.writeln(line);
      }
    }

    if(!failed.isEmpty) {
      for(var line in failed) {
        stderr.writeln(line);
      }
    }
  });
}

void _test_deepest_child_canceled() {
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
      reason: 'task not canceled');
  });
}

void _test_stream_closed_when_cancel() {
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
      reason: 'stream not closed');
  });
}

List _get_example_tests() {
  var tests = [];
  tests.add({'name': 'Example: Access pub.dartlang.org', 'test':
    () => new example01.Example().run() });
  tests.add({'name': 'Example: Cancel by event', 'test':
    () => new example02.Example().run() });
  tests.add({'name': 'Example: Handling exception', 'test':
    () => new example03.Example().run() });
  tests.add({'name': 'Example: Show latest packages', 'test':
    () => new example04.Example().run() });
  tests.add({'name': 'Example: Show all packages', 'test':
    () => new example05.Example().run() });
  tests.add({'name': 'Example: Using stream', 'test':
    () => new example06.Example().run() });
  tests.add({'name': 'Example: Using whenAll', 'test':
    () => new example07.Example().run() });
  tests.add({'name': 'Example: Using whenAny', 'test':
    () => new example08.Example().run() });
  return tests;
}

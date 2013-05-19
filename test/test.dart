import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:unittest/unittest.dart';

import '../example/example_access_pub_dartlang_org.dart' as example01;
import '../example/example_cancel_by_event.dart' as example02;
import '../example/example_handling_exception.dart' as example03;
import '../example/example_multithreading.dart' as example04;
import '../example/example_show_latest_packages.dart' as example05;
import '../example/example_show_all_packages.dart' as example06;
import '../example/example_using_stream.dart' as example07;
import '../example/example_using_when_all.dart' as example08;
import '../example/example_using_when_any.dart' as example09;

void main() {
  var tests = [];
  tests.add({'name': 'Deepest child canceled', 'test': _test_deepest_child_canceled});
  tests.add({'name': 'Stream closed when cancel', 'test': _test_stream_closed_when_cancel});
  tests.add({'name': 'Error handling in parallel tasks', 'test': _test_error_handling_in_parallel_tasks});
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
    stdout.writeln('TEST RESULTS:');
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

void _test_error_handling_in_parallel_tasks() {
  new Async.run(new ParallelTask(null))
  .catchException((ae) {
    ae.handle((exception) {
      if(exception is ArgumentError) {
        return true;
      }
    });
  })
  .continueWith((ant) {
    expect(ant.status, AsyncStatus.CANCELED,
      reason: 'long task exception not handled');
  });
}

class ParallelTask implements Runnable {
  final int data;

  ParallelTask(this.data);

  run() {
    if(data == null) {
      throw new ArgumentError('data: $data');
    }
  }
}

List _get_example_tests() {
  var tests = [];
  _addExample('Access pub.dartlang.org',
    () => new example01.Example().run(), tests);
  _addExample('Cancel by event',
    () => new example02.Example().run(), tests);
  _addExample('Handling exception',
    () => new example03.Example().run(), tests);
  _addExample('Multithreading',
      () => new example04.Example().run(), tests);
  _addExample('Show latest packages',
    () => new example05.Example().run(), tests);
  _addExample('Show all packages',
    () => new example06.Example().run(), tests);
  _addExample('Using stream',
    () => new example07.Example().run(), tests);
  _addExample('Using whenAll',
    () => new example08.Example().run(), tests);
  _addExample('Using whenAny',
    () => new example09.Example().run(), tests);
  return tests;
}

void _addExample(String name, Function action, List tests) {
  test() {
    new Async(action)
    .catchException((ae) {
      ae.handle((exception) {
        expect(exception.runtimeType, null,
          reason: 'example has unhandled exception');
      });
    });;
  };

  tests.add({'name': 'Example: $name', 'test': test});
}

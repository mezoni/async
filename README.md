#[Async](https://github.com/mezoni/async) is an asynchronous operations (tasks) library for Dart language.

This library is a lightweight by size and easy to understand and use.

Here is a small list of supported features:

 - The attaching or detaching the inner tasks to outer tasks (parent tasks)
 - The cancellation of task including all attached tasks
 - The task continuations
 - The 'promise' tasks similar to the 'futures'
 - The ability creating task in the 'cold' or 'warm' state
 - The ability creating 'promise 'tasks from 'futures'
 - The ability creating 'promise 'tasks from results
 - The ability easy assignment of the task result inside the tasks 'actions'
 - The exception handling with the error propagation from the inner tasks to the outer tasks
 
 Here is some examples that you may to run and see how it works and how it may be used.
 (https://github.com/mezoni/async/tree/master/example)
 
 Also some basic examples.
 
 - The attaching or detaching the inner tasks to outer tasks (parent tasks)
 
 void main() {
  var outer = new Async(() {
    print('outer task');
    var inner1 = new Async(() {
      print('inner1 task');
    });
    var inner2 = new Async(() {
      print('inner2 task');
    }, options: Async.DETACH);
  });
} 

- The cancellation of task including all attached tasks

void main() {
  var ce = new CancelEvent();
  var outer = new Async(() {
    print('outer task');
    new Async.delay(200, () {
      print('inner task');
    });
  }, cancelEvent: ce)
  .continueWith((ant) {
    print('Status: ${ant.status}');
  });

  var timeout = 100;
  new Async.delay(timeout, () {
    print('Canceling after $timeout ms');
    ce.set();
  });
}

 - The task continuations
 void main() {
  new Async(() {
    return 'Hello!';
  })
  .continueWith((ant) {
    print(ant.result);
  });

  new Async(() {
    return 'Goodbye!';
  })
  .then((result) {
    print(result);
  });
}
 
  - The 'promise' tasks similar to the 'futures'
  
  void main() {
  var completer = new AsyncCompleter();
  var task = completer.operation;
  task.then((result) => print(result));
  completer.setResult('Hello');
}

 - The ability creating task in the 'cold' or 'warm' state
 
 void main() {
  var cold = new Async.create(() {
    print('I am cold');
  });

  new Async(() {
    print('I am warm');
    cold.start();
  });
}

 - The ability creating 'promise 'tasks from 'futures'
 
 void main() {
  var completer = new Completer();
  var future = completer.future;
  var task = new Async.fromFuture(future);
  task.then((result) => print(result));
  completer.complete('hello');
}

 - The ability creating 'promise 'tasks from results
 
 void main() {
  var completer = new AsyncCompleter();
  var task = new Async.fromResult('Hello');
  task.then((result) => print(result));
}

 - The ability easy assignment of the task result inside the tasks 'actions'
 
 void main() {
  var workAsync = new Async(() {
    return 'Hello';
  });

  var task = new Async(() {
    var current = Async.current;
    workAsync.then((result) {
      current.result = '$result World';
    });
  });

  task.then((work) {
    print(work);
  });
}

 - The exception handling with the error propagation from the inner tasks to the outer tasks
 
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
 
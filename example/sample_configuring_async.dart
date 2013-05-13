import 'package:async/async.dart';

import 'dart:async';

// Exceptions from Future do not contain original call site
// https://code.google.com/p/dart/issues/detail?id=8656

Async doItLater() {
  return new Async(() {
    new Async(() => throw new StateError('doh!'));
    new Async(() => throw new StateError('oh!'));
  });
}

Async doItEarly() {
  return doItLater();
}

main() {
  AsyncConfig.set('DEBUG', true);
  doItEarly().then(print);
}

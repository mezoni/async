import 'package:async/async.dart';
import 'example_web_client.dart';

import 'dart:io';
import 'dart:json' as json;
import 'dart:uri';

void main() {
  var example = new Example();
  example.run();
}

class Example {
  final String server = 'http://pub.dartlang.org/';

  void run() {
    new Async(() {
      var packages = ['args', 'html5lib', 'http', 'intl', 'js', 'logging','route', 'unittest', 'yaml'];
      var count = packages.length;
      var sw = new List(count);
      var tasks = [];
      print('Performing operations asynchronously');
      var total = new Stopwatch();
      total.start();
      for(var i = 0; i < count; i++) {
        var task = new Async(() {
          var current = Async.current;
          var package = packages[i];
          print('Fetching versions for package "$package"');
          sw[i] = new Stopwatch();
          sw[i].start();
          _getPackageVersionsAsync(package)
          .then((versions) {
            sw[i].stop();
            var elapsed = sw[i].elapsedMilliseconds;
            print('Fetched for package #$i "$package" in $elapsed ms' );
            current.result = {'name': package, 'versions': versions, 'index': i};
          });
        });

        tasks.add(task);
      }

      Async.whenAll(tasks).then((List packages) {
        total.stop();
        print('Fetched all (${packages.length}) version(s) in ${total.elapsedMilliseconds} ms.');
        packages.forEach((package) {
          var versions = package['versions'].join(', ');
          print('Package #${package['index']} "${package['name']}": $versions');
        });
      })
      .continueWith((ant) {
        if(ant.isCanceled || ant.isFailed) {
          total.stop();
          print('Operation ${ant.status}');
        }
      });
    });
  }

  Async<List<String>> _getPackageVersionsAsync(String packageName) {
    return new Async(() {
      var current = Async.current;
      var webClient = new WebClient();
      var jsonData = webClient.readAsStringAsync(new Uri('$server/packages/$packageName.json'));
      jsonData.then((jsonData) {
        var doc = json.parse(jsonData);
        current.result = doc['versions'];
      });
    })
    .catchException((ae) {
      ae.handle((exception) {
        if(exception is SocketIOException) {
          return true;
        }
      });
    });
  }
}

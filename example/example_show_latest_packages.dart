import 'package:async/async.dart';
import 'example_web_client.dart';

import 'dart:async';
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
    _getLatestPackagesAsync()
    .then((packages) {
      for(var package in packages) {
        var uploaders = package['uploaders'].join(', ');
        var versions = package['versions'];
        var version = versions[versions.length - 1];
        print('${package['name']}.$version: $uploaders');
      }
    });
  }

  Async<List<String>> _getLatestPackagesAsync() {
    return new Async(() {
      var current = Async.current;
      var webClient = new WebClient();
      webClient.readAsStringAsync(new Uri('$server/packages.json'))
      .then((jsonData) {
        var doc = json.parse(jsonData);
        var packages = doc['packages'];
        var count = packages.length;
        var result = new List(count);
        for(var i = 0; i < count; i++) {
          var url = packages[i];
          _readPackageInfoAsync(url)
          .then((info) => result[i] = info);
        }

        current.result = result;
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

  Async<List<String>> _readPackageInfoAsync(url) {
    return new Async(() {
      var current = Async.current;
      var webClient = new WebClient();
      webClient.readAsStringAsync(new Uri(url))
      .then((jsonData) {
        var doc = json.parse(jsonData);
        current.result = doc;
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

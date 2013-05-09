import 'package:async/async.dart';

import 'dart:async';
import 'dart:io';
import 'dart:json' as json;
import 'dart:uri';

void main() {
  example01();
}

void example01() {
  new Async(() {
    var example = new Example01();
    var packages = ['args', 'html5lib', 'http', 'intl', 'js', 'logging','route', 'unittest', 'yaml'];
    var count = packages.length;
    var sw = new List(count);
    var tasks = [];

    print('Performing operations asynchronously');
    var total = new Stopwatch();
    total.start();
    for(var i = 0; i < count; i++) {
      var task = new Async(() {
        var _task = Async.current;
        var package = packages[i];
        print('Fetching versions for package "$package"');
        var versions = example.getPackageVersionsAsync(package);
        sw[i] = new Stopwatch();
        sw[i].start();
        var fetching = versions.then((versions) {
          sw[i].stop();
          var elapsed = sw[i].elapsedMilliseconds;
          print('Fetched for package #$i "$package" in $elapsed ms' );
          return {'name': package, 'versions': versions, 'index': i};
        });

        fetching.then((result) {
          _task.result = result;
        });
        return null;
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
    });
  });
}

class WebClient {
  Async<List<int>> readAsBytesAsync(Uri url) {
    return new Async(() {
      var _new = Async.current;
      var httpClient = new HttpClient();
      var bytes = new Async(() {
        _getResponseAsync(httpClient, url).then((response) {
          _getResponseResultAsync(response).then((List parts) {
            var data = [];
            for(var part in parts) {
              data.addAll(part);
            }
            _new.result = data;
            return null;
          });
        });
      });

      bytes.continueWith((ant) {
        httpClient.close(force: true);
      });

      return null;
    });
  }

  Async<String> readAsStringAsync(Uri url) {
    return readAsBytesAsync(url).then((charCodes) {
      return new String.fromCharCodes(charCodes);
    });
  }

  Async<HttpClientRequest> _getRequestAsync(HttpClient httpClient, Uri url) {
    return new Async.fromFuture(httpClient.getUrl(url)).then((request) {
      return request;
    });
  }

  Async<HttpClientResponse> _getResponseAsync(HttpClient httpClient, Uri url) {
    return _getRequestAsync(httpClient, url).then((request) {
      var _response = Async.current;
      return _getResponseFromRequestAsync(request).then((response) {
        _response.result = response;
      });
    })
    .catchException((exception) {
      httpClient.close(force: true);
      throw exception;
   });
  }

  Async<HttpClientResponse> _getResponseFromRequestAsync(HttpClientRequest request) {
    return new Async.fromFuture(request.close()).then((result) {
      return result;
    });
  }

  Async<List<int>> _getResponseResultAsync(HttpClientResponse response) {
    return new Async.fromStream(response).then((list) {
      return list;
    });
  }
}

class Example01 {
  final String server = 'http://pub.dartlang.org/';

  Async<List<String>> getPackageVersionsAsync(String packageName) {
    return new Async(() {
      var _new = Async.current;
      var webClient = new WebClient();
      var jsonData = webClient.readAsStringAsync(new Uri('$server/packages/$packageName.json'));
      var versions = jsonData.then((jsonData) {
        var doc = json.parse(jsonData);
        return doc['versions'];
      });

      versions.then((result) {
        _new.result = result;
      });
      return null;
    })
    .catchException((exception) {
      _throwError(exception, packageName, null);
    });
  }

  void _throwError(AsyncException exception, String packageName, Uri url) {
    exception.handle((exception) {
      if(exception is SocketIOException) {
        print('Socket I/O exception occured.');
        print('OS Error: ${exception.osError}');
        return true;
      }
    });
  }
}

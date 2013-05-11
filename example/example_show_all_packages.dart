import 'package:async/async.dart';
import 'example_utils.dart';
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
    _getAllPackagesAsync()
    .then((packages) {
      packages.sort((e1, e2) => _compare(e1['name'], e2['name']));
      _writeHtml(packages);
    })
    .catchException((ae) {
      ae.handle((exception) {
        if(exception is SocketIOException) {
          print('Error occured: $exception');
          return true;
        }
      });
    });
  }

  int _compare(String string1, String string2) {
    var chars1 = string1.codeUnits;
    var chars2 = string2.codeUnits;
    var length1 = chars1.length;
    var length2 = chars2.length;
    var length = length1;
    if(length > length2) {
      length = length2;
    }

    for(var i = 0; i < length; i++) {
      var diff = chars1[i] - chars2[i];
      if(diff > 0) {
        return 1;
      } else if(diff < 0) {
        return -1;
      }
    }

    return 0;
  }

  Async<List<String>> _getAllPackagesAsync() {
    return new Async(() {
      var current = Async.current;
      _readPagesAsync('${server}packages.json')
      .then((packages) {
        var count = packages.length;
        var result = new List(count);
        for(var i = 0; i < count; i++) {
          var url = packages[i];
          _readJsonAndParseAsync(url)
          .then((info) {
            info['url'] = url;
            result[i] = info;
          });
        }

        current.result = result;
      });
    });
  }

  Async<List<String>> _readJsonAndParseAsync(url) {
    return new Async(() {
      var current = Async.current;
      new WebClient().readAsStringAsync(new Uri(url))
      .then((jsonData) {
        current.result = json.parse(jsonData);
      });
    });
  }

  Async<List> _readPagesAsync(String url) {
    return new Async(() {
      var current = Async.current;
      new WebClient().readAsStringAsync(new Uri(url))
      .then((jsonData) {
        var doc = json.parse(jsonData);
        var packages = doc['packages'];
        var next = doc['next'];
        if(next != null && !next.isEmpty) {
          _readPagesAsync(next)
          .then((next) {
            packages.addAll(next);
          });
        }

        current.result = packages;
      });
    });
  }

  void _writeHtml(List packages) {
    var lib = 'example_show_all_packages';
    var title = 'All packages on pub.dartlang.org';
    var github = 'https://github.com/mezoni/async/tree/master/example/$lib.dart';
    var strings = [];
    strings.add('<html>');
    strings.add('<head>');
    strings.add('<title>$title</title>');
    strings.add('</head>');
    strings.add('<body>');
    strings.add('<h1>$title:</h1>');
    strings.add('Generated at ${new DateTime.now()} by <a href="$github" target="_blank">$lib.dart</a></br>');
    strings.add('Total: ${packages.length} packages:');
    strings.add('<ul>');
    for(var package in packages) {
      strings.add('<li>');
      var versions = package['versions'];
      var name = package['name'];
      var url = package['url'];
      if(url.endsWith('.json')) {
        url = url.substring(0, url.length - 5);
      }

      strings.add('<a href="$url" target="_blank">');
      strings.add(name);
      strings.add('</a>');
      if(versions is List) {
        var version = versions[versions.length - 1];
        strings.add('version $version');
        strings.add('from ${versions.length} version(s)');
      }

      strings.add('</li>');
    }

    strings.add('</ul>');
    strings.add('</body>');
    strings.add('</html>');
    var dir = ExampleUtils.getLibraryDirectory('async/example/$lib.dart');
    if(dir != null) {
      var file = new File('$dir/html_$lib.html');
      file.writeAsString(strings.join('\r\n'));
      print('All packages: ${file.path}');
    }
  }
}

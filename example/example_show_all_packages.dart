library async.example.example_show_all_packages;

import 'package:async/async.dart';
import 'package:yaml/yaml.dart';
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
    .then((packageList) {
      var repository = new PubRepository();
      repository.packageList = packageList;
      _analyzeRepository(repository);
      _writeHtml(repository);
    });
  }

  void _analyzeRepository(PubRepository repository) {
    print('Analyzing packages in repository');
    var packageMap = repository.packageMap;
    var packageList = repository.packageList;
    packageList.sort((p1, p2) => Utils.compareStrings(p1.name, p2.name));
    for(var package in packageList) {
      var name = package.name;
      packageMap[name] = package;
    }

    for(var package in packageList) {
      var name = package.name;
      var pubspec = package.pubspec;
      var dependencies = pubspec.dependencies.values;
      for(var dependency in dependencies) {
        var found = packageMap[dependency.name];
        if(found != null) {
          found.dependents.add(package);
        }
      }

      dependencies = pubspec.devDependencies.values;
      for(var dependency in dependencies) {
        var found = packageMap[dependency.name];
        if(found != null) {
          found.dependents.add(package);
        }
      }
    }
  }

  Async<List<Package>> _getAllPackagesAsync() {
    return new Async(() {
      var current = Async.current;
      _readPagesAsync('${server}packages.json')
      .then((packages) {
        var count = packages.length;
        var result = new List(count);
        print('Found $count packages. Obtaining information about each package');
        for(var i = 0; i < count; i++) {
          var url = packages[i];
          _readJsonAndParseAsync(url)
          .then((info) {
            var name = info['name'];
            var package = new Package(name);
            package.url = url.substring(0, url.length - 5);
            var versions = package.versions;
            for(var string in info['versions']) {
              try {
                versions.add(new Version(string));
              } catch(ex) {
                print('Invalid version: $name $string');
              }
            }

            versions.sort((v1, v2) => Version.compare(v1, v2));
            var version = package.getLatestVersion();
            if(version != null) {
              var pubspecUrl = '${package.url}/versions/$version.yaml';
              _readYamlAndParseAsync(pubspecUrl)
              .then((pubspec) {
                try {
                  package.pubspec = new PubSpec(pubspec);
                } catch(ex) {
                  print('Error parsing pubspec (${ex.runtimeType}): ${package.name} $version');
                }

                result[i] = package;
              });
            }
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
      print('Fetching page: $url');
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

  Async<List<String>> _readYamlAndParseAsync(url) {
    return new Async(() {
      var current = Async.current;
      new WebClient().readAsStringAsync(new Uri(url))
      .then((yamlData) {
        current.result = loadYaml(yamlData);
      });
    });
  }

  void _writeHtml(PubRepository repository) {
    var lib = 'example_show_all_packages';
    var title = 'All packages on pub.dartlang.org';
    var github = 'https://github.com/mezoni/async/tree/master/example/$lib.dart';
    var strings = [];
    strings.add('<html>');
    strings.add('<head>');
    strings.add('<title>$title</title>');
    strings.add('</head>');
    strings.add('<body>');
    strings.add(templateJavascript);
    strings.add('<h1>$title:</h1>');
    strings.add('Generated at ${new DateTime.now()} by <a href="$github" target="_blank">$lib.dart</a></br>');
    strings.add('Total: ${repository.packageList.length} packages:');
    strings.add('<ul>');

    var packageMap = repository.packageMap;
    var packageList = repository.packageList;
    var count = packageList.length;
    for(var i = 0; i < count; i++) {
      var package = packageList[i];
      var name = package.name;
      var pubspec = package.pubspec;
      var description = pubspec.description;
      var version = pubspec.version;
      var versions = package.versions;
      var url = package.url;
      var template = templatePackage;

      strings.add('<li>');
      template = template.replaceAll('{{name}}', '$name');
      template = template.replaceAll('{{id}}', 'package_$name');
      template = template.replaceAll('{{info_id}}', 'info_$name');
      template = template.replaceAll('{{description}}', '$description');
      template = template.replaceAll('{{version}}', '$version');
      template = template.replaceAll('{{versions}}', '${versions.join(', ')}');

      for(var i = 0; i < 2; i++) {
        List<Dependency> dependencies;
        String key;
        if(i == 0) {
          dependencies = pubspec.dependencies.values.toList();
          key = 'dependencies';
        } else {
          dependencies = pubspec.devDependencies.values.toList();
          key = 'dev_dependencies';
        }

        dependencies.sort((p1, p2) => Utils.compareStrings(p1.name, p2.name));
        var hrefs = [];
        for(var dependency in dependencies) {
          var href = dependency.name;
          if(dependency.hostedOnPubDartlang) {
            var found = packageMap[dependency.name];
            if(found != null) {
              href = templateReference;
              href = href.replaceAll('{{id}}', 'package_${found.name}');
              href = href.replaceAll('{{name}}', '${found.name}');
            }
          }

          hrefs.add(href);
        }

        template = template.replaceAll('{{$key}}', '${hrefs.join(', ')}');
      }

      var dependents = package.dependents.toList();
      var blocks = [];
      var dependentCount = 0;
      if(dependents.length > 0) {
        dependents.sort((p1, p2) => Utils.compareStrings(p1.name, p2.name));
        for(var dependent in dependents) {
          dependentCount++;
          var found = packageMap[dependent.name];
          if(found != null) {
            var template = templateReference;
            template = template.replaceAll('{{id}}', 'package_${found.name}');
            template = template.replaceAll('{{name}}', '${found.name}');
            blocks.add(template);
          } else {
            blocks.add(found.name);
          }
        }
      }

      template = template.replaceAll('{{dependent_count}}', '$dependentCount');
      template = template.replaceAll('{{dependents}}', '${blocks.join(', ')}');

      strings.add(template);

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

  static const String templateReference =
'''
<a href='#{{id}}'>{{name}}</a>''';

  static const String templatePackage =
'''
<div>
<a id='{{id}}' onclick="toggleVisibility('{{info_id}}');" href='#{{id}}'>{{name}}</a>
</div>
<div id='{{info_id}}' style='display:none'>
Description: {{description}}</br>
Version: {{version}}</br>
Versions: {{versions}}</br>
Dependencies: {{dependencies}}</br>
Dev. dependencies: {{dev_dependencies}}</br>
Dependents ({{dependent_count}}): {{dependents}}</br>
</div>
''';

  static const String templateJavascript =
'''
<script type="text/javascript">
function toggleVisibility(id) {
  var element = document.getElementById(id);  
  if(element.style.display == 'none') {
    element.style.display = 'block';
  } else {
    element.style.display = 'none';
  }
}
</script>
''';
}

class Dependency {
  final String name;

  bool hostedOnPubDartlang = false;

  Dependency(this.name, data) {
    if(name == null) {
      throw new ArgumentError('name: $name');
    }

    if(data is String) {
      hostedOnPubDartlang = true;
    }
  }

  String toString() {
    return name;
  }
}

class Package {
  Set<Package> dependents = new Set<Package>();

  final String name;

  PubSpec pubspec;

  String url;

  List<Version> versions = [];

  Package(this.name) {
    if(name == null || name.isEmpty) {
      throw new ArgumentError('name: $name');
    }
  }

  Version getLatestVersion() {
    if(versions.isEmpty) {
      return null;
    }

    return versions[versions.length - 1];
  }
}

class PubRepository {
  Map<String, Package> packageMap = new Map<String, Package>();
  List<Package> packageList = [];
}

class PubSpec {
  String name = '';

  String description = '';

  Version version;

  Map<String, Dependency> dependencies = new Map<String, Dependency>();

  Map<String, Dependency> devDependencies = new Map<String, Dependency>();

  PubSpec(Map pubspec) {
    if(pubspec == null) {
      throw new ArgumentError('pubspec: $pubspec');
    }

    name = pubspec['name'];
    description = pubspec['description'];
    try {
      version = new Version(pubspec['version']);
    } catch(ex) {
    }

    var deps = pubspec['dependencies'];
    if(deps != null) {
      for(var key in deps.keys) {
        dependencies[key] = new Dependency(key, deps[key]);
      }
    }

    deps = pubspec['dev_dependencies'];
    if(deps != null) {
      for(var key in deps.keys) {
        devDependencies[key] = new Dependency(key, deps[key]);
      }
    }
  }

  String toString() {
    return '$name $version';
  }
}

class Version {
  final String string;

  int _major;
  int _minor;
  int _patch;
  List _pre;
  String _build;

  Version([this.string = '0.0.0']) {
    if(string == null || string.isEmpty) {
      throw new ArgummentError('string: $string');
    }

    _parse();
  }

  static int compare(Version version1, Version version2) {
    if(version1 == null) {
      throw new ArgumentError('version1: $version1');
    }

    if(version2 == null) {
      throw new ArgumentError('version2: $version2');
    }

    if(version1._major > version2._major) {
      return 1;
    }

    if(version1._major < version2._major) {
      return -1;
    }

    if(version1._minor > version2._minor) {
      return 1;
    }

    if(version1._minor < version2._minor) {
      return -1;
    }

    if(version1._patch > version2._patch) {
      return 1;
    }

    if(version1._patch < version2._patch) {
      return -1;
    }

    if(version1._pre == null && version2._pre != null) {
      return 1;
    }

    if(version1._pre != null && version2._pre == null) {
      return -1;
    }

    if(version1._pre == null && version2._pre == null) {
      return 0;
    }

    var pre1 = version1._pre;
    var pre2 = version2._pre;
    var length1 = pre1.length;
    var length2 = pre2.length;
    var length = length1;
    if(length > length2) {
      length = length2;
    }

    for(var i = 0; i < length; i++) {
      var part1 = pre1[i];
      var part2 = pre2[i];
      if(part1 is int && part2 is int) {
        if(part1 > part2) {
          return 1;
        } else if(part1 < part2) {
          return -1;
        }

        continue;
      } else {
        var result = Utils.compareStrings('$part1', '$part2');
        if(result != 0) {
          return result;
        }
      }
    }

    if(length1 > length2) {
      return 1;
    } else if(length1 < length2) {
      return -1;
    }

    return 0;
  }

  String toString() {
    return string;
  }

  void _parse() {
    var parts = string.split('.');
    if(parts.length < 3) {
      throw new ArgumentError('string: $string');
    } else if(parts.length > 3) {
      parts = [parts[0], parts[1], parts.sublist(2).join('.')];
    }

    try {
      _major = int.parse(parts[0]);
    } catch(ex) {
      throw new ArgumentError('string: $string');
    }

    try {
      _minor = int.parse(parts[1]);
    } catch(ex) {
      throw new ArgumentError('string: $string');
    }

    parts = '${parts[2]}'.split('+');
    if(parts.length == 1) {
      parts = '${parts[0]}'.split('-');
    } else if(parts.length == 2) {
      _build = '${parts[1]}';
      parts = '${parts[0]}'.split('-');
    } else {
      throw new ArgumentError('string: $string');
    }

    if(parts.length == 1) {
      try {
        _patch = int.parse(parts[0]);
      } catch(ex) {
        throw new ArgumentError('string: $string');
      }
    } else if(parts.length == 2) {
      try {
        _patch = int.parse(parts[0]);
      } catch(ex) {
        throw new ArgumentError('string: $string');
      }

      _pre = parts[1].split('.');
    } else {
      throw new ArgumentError('string: $string');
    }

    if(_pre != null) {
      var length = _pre.length;
      for(var i = 0; i < length; i++) {
        try {
          _pre[i] = int.parse(_pre[i]);
        } catch(ex) {
        }
      }
    }
  }
}

class Utils {
  static int compareStrings(String string1, String string2) {
    if(string1 == null) {
      throw new ArgumentError('string1: $string1');
    }

    if(string2 == null) {
      throw new ArgumentError('string2: $string2');
    }

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

    if(length1 > length2) {
      return 1;
    } else if(length1 < length2) {
      return -1;
    }

    return 0;
  }
}

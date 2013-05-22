library async.example.example_utils;

import 'dart:mirrors';
import 'dart:io';

class ExampleUtils {
  static String getLibraryDirectory(String path) {
    if(path == null || path.isEmpty) {
      throw new ArgumentError('name: $path');
    }

    var result = null;
    var length = path.length;
    for(var library in currentMirrorSystem().libraries.values) {
      var uri = '${library.uri}';
      var urilen = uri.length;
      if(uri.length < length) {
        continue;
      }

      if(uri.endsWith(path)) {
        if(Platform.operatingSystem == 'windows') {
          uri = uri.replaceAll('file:///', '');
        } else {
          uri = uri.replaceAll('file://', '');
        }

        result = new Path(uri).directoryPath.toNativePath();
        break;
      }
    }

    return result;
  }
}

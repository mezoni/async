library async.example.example_web_client;

import 'dart:async';
import 'dart:io';
import 'dart:uri';

import 'package:async/async.dart';

class WebClient {
  Async<List<int>> readAsBytesAsync(Uri url) {
    return new Async(() {
      var current = Async.current;
      var httpClient = new HttpClient();
      var bytes = new Async(() {
        _getResponseAsync(httpClient, url).then((response) {
          _getResponseResultAsync(response).then((List parts) {
            var data = [];
            for(var part in parts) {
              data.addAll(part);
            }
            current.result = data;
          });
        });
      });

      bytes.continueWith((ant) {
        httpClient.close(force: true);
      });
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
      var current = Async.current;
      return _getResponseFromRequestAsync(request).then((response) {
        current.result = response;
      });
    }).catchException((exception) {
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
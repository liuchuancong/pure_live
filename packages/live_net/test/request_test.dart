import 'package:live_net/live_net.dart';
import 'package:test/test.dart';

void main() {
  group('CancelToken', () {
    test('cancel is idempotent and keeps the first reason', () {
      final token = CancelToken();
      expect(token.isCancelled, isFalse);

      token
        ..cancel('first')
        ..cancel('second');

      expect(token.isCancelled, isTrue);
      expect(token.reason, 'first');
    });

    test('whenCancel completes with the reason', () async {
      final token = CancelToken();
      final future = token.whenCancel;
      token.cancel(42);
      expect(await future, 42);
    });
  });

  group('LiveRequest', () {
    test('json factory encodes the body and sets the content type', () {
      final request = LiveRequest.json(Uri.parse('https://api.example.com/x'), body: {'a': 1, 'b': '二'});

      expect(request.method, 'POST');
      expect(request.body, '{"a":1,"b":"二"}');
      expect(request.contentType, 'application/json');
      expect(request.cancelToken.isCancelled, isFalse);
    });

    test('form factory encodes fields as urlencoded body', () {
      final request = LiveRequest.form(
        Uri.parse('https://api.example.com/login'),
        fields: {'name': '张 三', 'pass': 'p&1'},
      );

      expect(request.method, 'POST');
      expect(request.contentType, 'application/x-www-form-urlencoded');
      final decoded = Uri(query: request.body).queryParameters;
      expect(decoded['name'], '张 三');
      expect(decoded['pass'], 'p&1');
    });

    test('withQuery appends without re-encoding the existing query', () {
      final request = LiveRequest.get(Uri.parse('https://api.example.com/x?sign=a%2Fb&token=1+2'));

      final appended = request.withQuery({'page': '2', 'q': '关键词'});

      expect(appended.url.query, 'sign=a%2Fb&token=1+2&page=2&q=%E5%85%B3%E9%94%AE%E8%AF%8D');
      // Original request is untouched.
      expect(request.url.query, 'sign=a%2Fb&token=1+2');
    });

    test('withQuery preserves the fragment and handles empty query', () {
      final request = LiveRequest.get(Uri.parse('https://api.example.com/x#top'));

      final appended = request.withQuery({'a': '1'});

      expect(appended.url.toString(), 'https://api.example.com/x?a=1#top');
    });

    test('withQuery on an empty query is a no-op returning the same request', () {
      final request = LiveRequest.get(Uri.parse('https://api.example.com/x'));
      expect(request.withQuery(const {}), same(request));
    });
  });
}

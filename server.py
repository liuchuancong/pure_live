from http.server import HTTPServer, SimpleHTTPRequestHandler
import json

class Handler(SimpleHTTPRequestHandler):

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory='.', **kwargs)

    def do_POST(self):

        if self.path == '/save':

            length = int(self.headers['Content-Length'])

            body = self.rfile.read(length)

            data = json.loads(body)

            with open('./assets/version.json', 'w', encoding='utf-8') as f:
                json.dump(
                    data,
                    f,
                    ensure_ascii=False,
                    indent=2
                )

            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'success')

        else:
            self.send_error(404)

httpd = HTTPServer(('localhost', 8080), Handler)

print('Server running:')
print('http://localhost:8080/assets/index.html')

httpd.serve_forever()
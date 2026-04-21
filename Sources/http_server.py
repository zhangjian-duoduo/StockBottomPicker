#!/usr/bin/env python3
import http.server
import gzip
import os

class GzipHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Accept-Encoding", "gzip, deflate")
        super().end_headers()

    def do_GET(self):
        # Serve gzipped version if available
        if self.path.endswith(".json"):
            path = self.translate_path(self.path)
            if not path.endswith(".gz"):
                path_gz = path + ".gz"
                if os.path.exists(path_gz):
                    self.path = path_gz
        super().do_GET()

os.chdir('/root/stock-picker-data')
http.server.SimpleHTTPRequestHandler.extensions_map[".json"] = "application/json"
server = http.server.HTTPServer(('', 8888), GzipHTTPRequestHandler)
print('HTTP服务启动成功，端口8888')
server.serve_forever()

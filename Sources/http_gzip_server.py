#!/usr/bin/env python3
"""
支持gzip压缩的HTTP服务器
阿里云上运行: python3 http_gzip_server.py
"""
import http.server
import gzip
import os
import re

class GzipHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # 添加CORS头
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        # 添加gzip支持标记
        self.send_header('X-Content-Encoding', 'gzip')
        super().end_headers()

    def do_GET(self):
        # 检查是否请求JSON
        if self.path.endswith('.json'):
            gz_path = self.translate_path(self.path + '.gz')
            if os.path.exists(gz_path):
                # 发送gzip版本
                self.path = self.path + '.gz'
                self.send_header('Content-Encoding', 'gzip')
                self.send_header('Content-Type', 'application/json; charset=utf-8')
        super().do_GET()

    def log_message(self, format, *args):
        pass  # 静默日志

os.chdir('/root/stock-picker-data')
http.server.SimpleHTTPRequestHandler.extensions_map['.json'] = 'application/json'
http.server.SimpleHTTPRequestHandler.extensions_map['.gz'] = 'application/gzip'

server = http.server.HTTPServer(('', 8888), GzipHandler)
print('HTTP服务器启动: http://0.0.0.0:8888')
print('支持gzip压缩的JSON文件访问')
server.serve_forever()

from http.server import BaseHTTPRequestHandler, HTTPServer
from dataclasses import dataclass
from abc import ABC, abstractmethod
from enum import IntEnum
from typing import Generic, TypeVar
import requests
import json
import xmltodict

hostName = "localhost"
serverPort = 8081


class Listener(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length)
        try:
            content_type = self.headers.get("Content-Type")
            if content_type is None:
                raise KeyError("Content-Type is None")
            if "application/json" in content_type:
                data = json.loads(body)
            elif "application/xml" in content_type:
                data = xmltodict.parse(body)
            elif "application/x-www-form-urlencoded" in content_type:
                data = int(body)
            else:
                raise ValueError(f"Unknown Content-Type {content_type}")
            print(f"{self.path}: {data}")
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()

        except json.JSONDecodeError:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b"Invalid JSON")


if __name__ == "__main__":
    webServer = HTTPServer((hostName, serverPort), Listener)
    print("Server started http://%s:%s" % (hostName, serverPort))

    try:
        webServer.serve_forever()
    except KeyboardInterrupt:
        pass

    webServer.server_close()
    print("Server stopped.")

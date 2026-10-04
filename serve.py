#!/usr/bin/env python3
"""Serve a Godot web export over local HTTPS: ./serve.py <dir>."""

import argparse
import functools
import ipaddress
import shutil
import socket
import ssl
import subprocess
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class Handler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm"}

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def local_addresses():
    addresses = {"127.0.0.1", "::1"}
    try:
        addresses.update(item[4][0] for item in socket.getaddrinfo(socket.gethostname(), None))
    except socket.gaierror:
        pass
    # Connecting a UDP socket selects the local interface without sending data.
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
            probe.connect(("8.8.8.8", 80))
            addresses.add(probe.getsockname()[0])
    except OSError:
        pass
    return sorted(addresses)


def certificate(addresses):
    cache = Path.home() / ".local" / "share" / "sunburn" / "https"
    cache.mkdir(parents=True, exist_ok=True, mode=0o700)
    cert, key, hosts = cache / "cert.pem", cache / "key.pem", cache / "hosts.txt"
    signature = "\n".join(addresses)
    if not cert.exists() or not key.exists() or not hosts.exists() or hosts.read_text() != signature:
        if not shutil.which("openssl"):
            raise RuntimeError("OpenSSL is required to create the local HTTPS certificate.")
        san = "DNS:localhost," + ",".join(f"IP:{address}" for address in addresses)
        subprocess.run(
            ["openssl", "req", "-x509", "-newkey", "rsa:2048", "-sha256", "-nodes",
             "-keyout", str(key), "-out", str(cert), "-days", "365",
             "-subj", "/CN=localhost", "-addext", f"subjectAltName={san}"],
            check=True, capture_output=True,
        )
        key.chmod(0o600)
        hosts.write_text(signature)
    return cert, key


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--port", type=int, default=3000)
    args = parser.parse_args()
    directory = args.directory.expanduser().resolve()
    if not directory.is_dir():
        parser.error(f"Not a directory: {directory}")
    try:
        addresses = local_addresses()
        cert, key = certificate(addresses)
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(cert, key)
        server = ThreadingHTTPServer(
            ("0.0.0.0", args.port), functools.partial(Handler, directory=str(directory))
        )
        server.socket = context.wrap_socket(server.socket, server_side=True)
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Could not start HTTPS server: {error}\n")
    print(f"Serving {directory}\nhttps://localhost:{args.port}", flush=True)
    for address in addresses:
        if ipaddress.ip_address(address).version == 4 and not ipaddress.ip_address(address).is_loopback:
            print(f"https://{address}:{args.port}", flush=True)
    print("Accept the browser's local certificate warning once. Ctrl+C stops the server.", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()

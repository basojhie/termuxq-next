import http.client
import json
import threading
import unittest

import termuxq_agent as agent


class AgentHttpTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = agent.ThreadingHTTPServer(("127.0.0.1", 0), agent.H)
        cls.port = cls.server.server_address[1]
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=2)

    def request(self, path="/stats", method="GET", origin=None, host=None):
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        headers = {"Host": host or f"127.0.0.1:{self.port}"}
        if origin:
            headers["Origin"] = origin
        conn.request(method, path, headers=headers)
        res = conn.getresponse()
        body = res.read()
        result = (res.status, dict(res.getheaders()), body)
        conn.close()
        return result

    def test_stats_payload_and_no_store(self):
        status, headers, body = self.request()
        self.assertEqual(status, 200)
        self.assertIn("application/json", headers.get("Content-Type", ""))
        self.assertEqual(headers.get("Cache-Control"), "no-store")
        data = json.loads(body)
        expected = {"host", "os", "cores", "cpu_pct", "mem", "disk", "battery", "ip", "uptime"}
        self.assertTrue(expected.issubset(data.keys()))

    def test_allowed_origin_receives_cors_header(self):
        status, headers, _ = self.request(origin="https://basojhie.github.io")
        self.assertEqual(status, 200)
        self.assertEqual(headers.get("Access-Control-Allow-Origin"), "https://basojhie.github.io")

    def test_unlisted_origin_does_not_receive_cors_header(self):
        status, headers, _ = self.request(origin="https://not-allowed.example")
        self.assertEqual(status, 200)
        self.assertNotIn("Access-Control-Allow-Origin", headers)

    def test_unknown_route_does_not_expose_stats_or_commands(self):
        status, _, _ = self.request(path="/exec?cmd=whoami")
        self.assertEqual(status, 404)

    def test_rejects_non_loopback_host_header(self):
        status, _, _ = self.request(path="/stats", host="evil.example")
        self.assertEqual(status, 404)

    def test_preflight_allows_only_get(self):
        status, headers, _ = self.request(path="/stats", method="OPTIONS", origin="https://basojhie.github.io")
        self.assertEqual(status, 204)
        self.assertEqual(headers.get("Access-Control-Allow-Methods"), "GET")


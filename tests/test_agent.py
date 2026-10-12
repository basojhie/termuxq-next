import http.client
import json
import threading
import unittest
from unittest import mock

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
        expected = {"host", "os", "cores", "cpu_pct", "mem", "disk", "battery", "ip", "uptime", "agent_version", "features"}
        self.assertTrue(expected.issubset(data.keys()))
        self.assertEqual(data["agent_version"], "2.1.0")
        self.assertIn("private_lan_ping", data["features"])

    def test_allowed_origin_receives_cors_header(self):
        status, headers, _ = self.request(origin="https://basojhie.github.io")
        self.assertEqual(status, 200)
        self.assertEqual(headers.get("Access-Control-Allow-Origin"), "https://basojhie.github.io")

    def test_unlisted_origin_does_not_receive_cors_header(self):
        status, headers, _ = self.request(origin="https://not-allowed.example")
        self.assertEqual(status, 200)
        self.assertNotIn("Access-Control-Allow-Origin", headers)

    def test_ping_rejects_public_targets_without_running_command(self):
        with mock.patch.object(agent.subprocess, "run") as run:
            status, _, body = self.request(path="/ping?host=8.8.8.8")
        self.assertEqual(status, 400)
        self.assertIn("RFC1918", json.loads(body)["error"])
        run.assert_not_called()

    def test_ping_uses_fixed_argv_for_private_ipv4(self):
        result = mock.Mock(returncode=0, stdout="Reply from 192.168.1.10: bytes=32 time=2ms TTL=128", stderr="")
        with mock.patch.object(agent.shutil, "which", return_value="/usr/bin/ping"), mock.patch.object(agent.subprocess, "run", return_value=result) as run:
            status, headers, body = self.request(path="/ping?host=192.168.1.10", origin="https://basojhie.github.io")
        self.assertEqual(status, 200)
        self.assertEqual(headers.get("Cache-Control"), "no-store")
        data = json.loads(body)
        self.assertTrue(data["reachable"])
        self.assertEqual(data["latency_ms"], 2.0)
        args, kwargs = run.call_args
        self.assertEqual(args[0][-1], "192.168.1.10")
        self.assertNotIn("shell", kwargs)
        self.assertLessEqual(kwargs["timeout"], 2.5)

    def test_ping_rejects_malformed_target(self):
        with mock.patch.object(agent.subprocess, "run") as run:
            status, _, body = self.request(path="/ping?host=localhost")
        self.assertEqual(status, 400)
        run.assert_not_called()

    def test_unknown_route_does_not_expose_stats_or_commands(self):
        status, _, _ = self.request(path="/exec?cmd=whoami")
        self.assertEqual(status, 404)

    def test_rejects_non_loopback_host_header(self):
        status, _, _ = self.request(path="/stats", host="evil.example")
        self.assertEqual(status, 404)

    def test_server_suppresses_expected_client_disconnect_errors(self):
        server = agent.QuietThreadingHTTPServer(("127.0.0.1", 0), agent.H)
        try:
            error = ConnectionAbortedError("client closed connection")
            with mock.patch.object(agent.sys, "exc_info", return_value=(type(error), error, None)), \
                 mock.patch.object(agent.ThreadingHTTPServer, "handle_error") as parent_handler:
                server.handle_error(None, ("127.0.0.1", 12345))
                parent_handler.assert_not_called()
        finally:
            server.server_close()

    def test_server_still_reports_unexpected_errors(self):
        server = agent.QuietThreadingHTTPServer(("127.0.0.1", 0), agent.H)
        try:
            error = RuntimeError("unexpected")
            with mock.patch.object(agent.sys, "exc_info", return_value=(type(error), error, None)), \
                 mock.patch.object(agent.ThreadingHTTPServer, "handle_error") as parent_handler:
                server.handle_error(None, ("127.0.0.1", 12345))
                parent_handler.assert_called_once()
        finally:
            server.server_close()

    def test_preflight_allows_only_get(self):
        status, headers, _ = self.request(path="/stats", method="OPTIONS", origin="https://basojhie.github.io")
        self.assertEqual(status, 204)
        self.assertEqual(headers.get("Access-Control-Allow-Methods"), "GET")


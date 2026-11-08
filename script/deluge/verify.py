"""Exercise a disposable Deluge daemon against loopback-only synthetic data."""

import base64
import hashlib
import http.cookiejar
import json
import os
import platform
import re
import subprocess
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from deluge.config import Config


def bencode(value):
    if isinstance(value, int):
        return b"i" + str(value).encode() + b"e"
    if isinstance(value, bytes):
        return str(len(value)).encode() + b":" + value
    if isinstance(value, list):
        return b"l" + b"".join(bencode(item) for item in value) + b"e"
    return b"d" + b"".join(bencode(key) + bencode(value[key]) for key in sorted(value)) + b"e"


class Tracker(BaseHTTPRequestHandler):
    events = []
    rejected = set()

    def do_GET(self):
        query = urllib.parse.parse_qs(urllib.parse.urlsplit(self.path).query,
                                     encoding="latin-1")
        info_hash = query.get("info_hash", [""])[0].encode("latin-1").hex()
        rejected = info_hash in self.rejected
        self.events.append({"info_hash": info_hash,
                            "event": query.get("event", ["update"])[0],
                            "accepted": not rejected})
        response = {b"failure reason": b"Synthetic tracker rejection"} if rejected else {
            b"interval": 60, b"complete": 1, b"incomplete": 0, b"peers": b""}
        body = bencode(response)
        self.send_response(200)
        self.send_header("Content-Type", "application/x-bittorrent")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


class Rpc:
    def __init__(self):
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
        self.methods = []

    def call(self, method, *params):
        self.methods.append(method)
        request = urllib.request.Request("http://127.0.0.1:8112/json",
            data=json.dumps({"method": method, "params": params,
                             "id": len(self.methods)}).encode(),
            headers={"Content-Type": "application/json"})
        with self.opener.open(request, timeout=7) as response:
            result = json.loads(response.read(1024 * 1024))
        if result.get("error"):
            raise RuntimeError(f"{method}: {result['error'].get('message', 'RPC error')}")
        return result["result"]

    def status(self, torrent_id):
        return self.call("core.get_torrent_status", torrent_id, [
            "state", "progress", "is_finished", "move_completed", "download_location",
            "tracker_status", "total_done", "total_size", "total_payload_download"])


def wait_for(label, callback, seconds=20):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        try:
            result = callback()
            if result:
                return result
        except urllib.error.URLError:
            pass
        time.sleep(0.1)
    raise TimeoutError(f"Timed out observing {label}")


def make_fixture(directory, name, incomplete=False):
    data = (b"Seedbench synthetic Deluge verification\n" * 131072)
    payload = directory / name
    payload.write_bytes(data[:len(data) // 2] if incomplete else data)
    piece_length = 1024 * 1024
    info = {b"name": name.encode(), b"length": len(data), b"private": 1,
            b"piece length": piece_length,
            b"pieces": b"".join(hashlib.sha1(data[i:i + piece_length]).digest()
                               for i in range(0, len(data), piece_length))}
    torrent = bencode({b"announce": b"http://127.0.0.1:6969/announce", b"info": info})
    return {"name": name, "path": payload, "torrent": torrent,
            "id": hashlib.sha1(bencode(info)).hexdigest(),
            "sha256": hashlib.sha256(payload.read_bytes()).hexdigest()}


def add_and_check(rpc, fixture, directory):
    torrent_id = rpc.call("core.add_torrent_file", fixture["name"] + ".torrent",
                         base64.b64encode(fixture["torrent"]).decode(),
                         {"add_paused": True, "auto_managed": False,
                          "download_location": str(directory)})
    assert torrent_id == fixture["id"] and re.fullmatch(r"[a-f0-9]{40}", torrent_id)
    initial = wait_for("paused import", lambda: paused_status(rpc, torrent_id))
    assert initial["download_location"] == str(directory)
    assert initial["move_completed"] is True
    rpc.call("core.set_torrent_options", [torrent_id], {"move_completed": False})
    assert rpc.status(torrent_id)["move_completed"] is False
    rpc.call("web.get_events")
    rpc.call("core.force_recheck", [torrent_id])
    states = []

    def recheck_finished():
        for event, arguments in rpc.call("web.get_events") or []:
            if event == "TorrentStateChangedEvent" and arguments[0] == torrent_id:
                states.append(arguments[1])
        status = paused_status(rpc, torrent_id)
        return status if "Paused" in states and status else None

    try:
        checked = wait_for("completed forced check", recheck_finished)
    except TimeoutError as error:
        raise RuntimeError(json.dumps({"observed_states": states,
                                       "status": rpc.status(torrent_id)})) from error
    assert checked["move_completed"] is False
    checked["observed_check_states"] = states
    checked["tracker_announces_before_resume"] = sum(
        event["info_hash"] == torrent_id for event in Tracker.events)
    return checked


def paused_status(rpc, torrent_id):
    status = rpc.status(torrent_id)
    return status if status["state"] == "Paused" else None


def observe_seeding(rpc, torrent_id, rejection=False):
    status = rpc.status(torrent_id)
    text = status["tracker_status"].lower()
    tracker_observed = any(event["info_hash"] == torrent_id
                           and event["accepted"] is not rejection for event in Tracker.events)
    expected = "synthetic tracker rejection" if rejection else "announce ok"
    if status["state"] == "Seeding" and expected in text and tracker_observed:
        return status
    return None


def configure(directory, payloads, moved):
    core = Config("core.conf", defaults={
        "download_location": str(payloads), "move_completed": True,
        "move_completed_path": str(moved), "listen_interface": "127.0.0.1",
        "outgoing_interface": "127.0.0.1", "dht": False, "utpex": False,
        "lsd": False, "upnp": False, "natpmp": False}, config_dir=str(directory))
    assert core.save()
    username, password, host_id = "localclient", uuid.uuid4().hex, uuid.uuid4().hex
    auth = directory / "auth"
    auth.write_text(f"{username}:{password}:10\n")
    auth.chmod(0o600)
    hosts = Config("hostlist.conf", defaults={
        "hosts": [[host_id, "127.0.0.1", 58846, username, password]]},
        config_dir=str(directory))
    assert hosts.save()
    return host_id


def verify(rpc, fixtures, payloads, moved):
    before = rpc.call("core.get_config")
    assert before["move_completed"] is True
    rpc.call("web.register_event_listener", "TorrentStateChangedEvent")
    full, incomplete, rejected = fixtures
    checked = add_and_check(rpc, full, payloads)
    assert checked["progress"] == 100.0 and checked["is_finished"] is True
    rpc.call("core.resume_torrent", full["id"])
    seeded = wait_for("seeding and tracker acceptance",
                      lambda: observe_seeding(rpc, full["id"]))

    partial = add_and_check(rpc, incomplete, payloads)
    assert partial["progress"] == 40.0 and partial["state"] == "Paused"
    assert partial["is_finished"] is False
    assert partial["total_payload_download"] == 0

    Tracker.rejected.add(rejected["id"])
    denied = add_and_check(rpc, rejected, payloads)
    assert denied["progress"] == 100.0 and denied["is_finished"] is True
    rpc.call("core.resume_torrent", rejected["id"])
    tracker_failure = wait_for("tracker rejection",
                              lambda: observe_seeding(rpc, rejected["id"], rejection=True))
    rpc.call("core.pause_torrent", rejected["id"])
    wait_for("pause after tracker rejection", lambda: paused_status(rpc, rejected["id"]))
    assert rpc.call("core.get_config") == before
    assert "core.set_config" not in rpc.methods
    assert not any(moved.iterdir())
    for fixture in fixtures:
        assert rpc.status(fixture["id"])["total_payload_download"] == 0
        assert hashlib.sha256(fixture["path"].read_bytes()).hexdigest() == fixture["sha256"]
    return {"add_paused": True, "per_torrent_move_completed_false": True,
            "forced_recheck_progress": checked["progress"],
            "observed_recheck_states": checked["observed_check_states"],
            "incomplete_recheck_states": partial["observed_check_states"],
            "rejected_recheck_states": denied["observed_check_states"],
            "tracker_announces_before_explicit_resume": {
                "complete": checked["tracker_announces_before_resume"],
                "incomplete": partial["tracker_announces_before_resume"],
                "rejected": denied["tracker_announces_before_resume"]},
            "initial_seeding_state": seeded["state"],
            "accepted_tracker_status": seeded["tracker_status"],
            "incomplete_recheck_progress": partial["progress"],
            "incomplete_torrent_paused_after_recheck": True,
            "rejected_tracker_status": tracker_failure["tracker_status"],
            "rejected_torrent_paused_after_observation": True,
            "global_configuration_preserved": True, "payload_hashes_preserved": True,
            "move_destination_empty": True, "payload_bytes_downloaded": 0}


def main():
    assert os.getuid() != 0, "Use the unprivileged container user"
    os.umask(0o077)
    with tempfile.TemporaryDirectory(prefix="seedbench-deluge-") as temporary:
        root = Path(temporary)
        config, payloads, moved = (root / name for name in ("config", "payloads", "moved"))
        for path in (config, payloads, moved):
            path.mkdir(mode=0o700)
        host_id = configure(config, payloads, moved)
        fixtures = [make_fixture(payloads, "synthetic-full.bin"),
                    make_fixture(payloads, "synthetic-incomplete.bin", incomplete=True),
                    make_fixture(payloads, "synthetic-rejected.bin")]
        tracker = ThreadingHTTPServer(("127.0.0.1", 6969), Tracker)
        threading.Thread(target=tracker.serve_forever, daemon=True).start()
        processes, logs = [], []
        try:
            for executable, arguments in [
                    ("deluged", ["-d", "-c", str(config), "-L", "warning"]),
                    ("deluge-web", ["-d", "-c", str(config), "-i", "127.0.0.1", "--no-ssl"])]:
                log = (root / (executable + ".log")).open("w+")
                logs.append(log)
                processes.append(subprocess.Popen([executable, *arguments], stdout=log, stderr=log))
            rpc = Rpc()
            assert wait_for("web login", lambda: rpc.call("auth.login", "deluge")) is True
            hosts = rpc.call("web.get_hosts")
            assert any(host[0] == host_id for host in hosts)

            def connect_daemon():
                rpc.call("web.connect", host_id)
                return rpc.call("web.connected")

            assert wait_for("daemon connection", connect_daemon) is True
            result = verify(rpc, fixtures, payloads, moved)
            for fixture in fixtures:
                assert rpc.call("core.remove_torrent", fixture["id"], False) is True
            result.update(synthetic_only=True, production_client_used=False,
                          external_network_required=False, fixture_torrents_removed=True)
            result["rpc_methods"] = sorted(set(rpc.methods))
            result["runtime"] = {"architecture": platform.machine(),
                                 "python": platform.python_version(), "uid": os.getuid()}
            result["packages"] = subprocess.check_output([
                "dpkg-query", "-W", "-f=${Package}=${Version}\n", "deluged",
                "deluge-web", "python3-libtorrent"], text=True, timeout=10).splitlines()
            print(json.dumps(result, indent=2))
        except Exception:
            for log in logs:
                log.flush()
                log.seek(0)
                print(log.read()[-2500:], file=__import__("sys").stderr)
            raise
        finally:
            for process in processes:
                process.terminate()
            for process in processes:
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
            tracker.shutdown()
            tracker.server_close()
            for log in logs:
                log.close()


if __name__ == "__main__":
    main()

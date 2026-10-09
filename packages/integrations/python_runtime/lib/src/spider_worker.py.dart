// Module: lib/src/spider_worker.py.dart
// Purpose: The Python worker program the embedded interpreter runs: a loop
// that pulls spider jobs from the local gateway and executes them.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/adr/0017-tvbox-python-runtime.md, modelled on webtv-main's
// chaquo runner but transport-swapped: chaquo calls Java in-process, here the
// worker talks to the Dart gateway over loopback HTTP with the stdlib only,
// so the framework needs no pip packages at all. Spider modules are loaded
// from <dataDir>/spiders/<key>.py; each file must define a Spider class (the
// webtv base interface). The base helpers (fetch/log/cache) are injected by
// the loader as plain functions; cache calls hit the gateway's /cache
// endpoints exactly like webtv's Proxy.getUrl pattern.

const String pythonWorkerProgram = r'''
# PureLive spider worker: stdlib only.
import json
import os
import sys
import time
import traceback
import urllib.request
from importlib.machinery import SourceFileLoader

HOST = os.environ.get("PURE_LIVE_GATEWAY", "http://127.0.0.1:0")
SPIDER_DIR = os.environ.get("PURE_LIVE_SPIDER_DIR", os.path.join(os.getcwd(), "spiders"))

_spiders = {}


def _post(path, payload):
    req = urllib.request.Request(
        HOST + path,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=60) as rsp:
        body = rsp.read()
    return json.loads(body) if body else {}


def log(message):
    try:
        _post("/log", {"message": message if isinstance(message, str) else json.dumps(message, ensure_ascii=False)})
    except Exception:
        pass


class Cache:
    """The gateway keeps a bounded TTL map behind /cache, mirroring
    webtv's local proxy cache so spider code needs no storage of its own."""

    def get(self, key):
        try:
            with urllib.request.urlopen(HOST + "/cache?do=get&key=" + key, timeout=10) as rsp:
                body = rsp.read().decode("utf-8")
            if not body:
                return None
            data = json.loads(body)
            if isinstance(data, dict) and "__raw__" in data:
                raw = data["__raw__"]
                if raw == "":
                    return None
                if isinstance(raw, str) and raw[:1] in ("{", "["):
                    return json.loads(raw)
                return raw
            return data
        except Exception:
            return None

    def set(self, key, value):
        body = value if isinstance(value, str) else json.dumps(value, ensure_ascii=False)
        _post("/cache?do=set&key=" + key, {"value": body})
        return "succeed"

    def delete(self, key):
        _post("/cache?do=del&key=" + key, {})
        return "succeed"


cache = Cache()


class Fetch:
    """Minimal HTTP via urllib. headers is a plain dict; the answer is a dict
    shaped like webtv's requests response (text / json / status_code)."""

    def _request(self, url, data=None, headers=None, timeout=15):
        request = urllib.request.Request(url, data=data, headers=headers or {})
        with urllib.request.urlopen(request, timeout=timeout) as rsp:
            body = rsp.read()
            charset = rsp.headers.get_content_charset() or "utf-8"
        return {"text": body.decode(charset, "replace"), "status_code": 200}

    def get(self, url, params=None, headers=None, timeout=15):
        if params:
            from urllib.parse import urlencode

            url = url + ("&" if "?" in url else "?") + urlencode(params)
        return self._request(url, headers=headers, timeout=timeout)

    def post(self, url, data=None, headers=None, timeout=15):
        body = None
        if data is not None:
            body = (data if isinstance(data, (bytes, bytearray)) else json.dumps(data).encode("utf-8"))
            headers = {"Content-Type": "application/json", **(headers or {})}
        return self._request(url, data=body, headers=headers, timeout=timeout)


fetch = Fetch()


def load_spider(key):
    """Loads <spiders>/<key>.py once and returns its module. The module must
    define a Spider class; base helpers are injected as module globals so
    spider code written against webtv's base keeps working."""
    if key in _spiders:
        return _spiders[key]
    path = os.path.join(SPIDER_DIR, key + ".py")
    if not os.path.exists(path):
        raise FileNotFoundError("spider %s not found at %s" % (key, path))
    module = SourceFileLoader("spider_" + key, path).load_module()
    module.fetch = fetch
    module.log = log
    module.cache = cache
    module.test = getattr(module, "test", None)
    instance = module.Spider()
    _spiders[key] = instance
    return instance


def dispatch(job):
    key = job["key"]
    method = job["method"]
    args = job.get("args") or []
    spider = load_spider(key)
    if method == "init":
        getattr(spider, "init")(*args)
        spider._initialized = True
        return None
    if not getattr(spider, "_initialized", False):
        spider.init("")
        spider._initialized = True
    func = getattr(spider, method, None)
    if func is None or not callable(func):
        return {"__error__": "spider %s has no method %s" % (key, method)}
    result = func(*args)
    if result is None:
        return None
    return result if isinstance(result, (dict, list, str, int, float, bool)) else str(result)


def main():
    log("worker started, gateway=%s spiders=%s" % (HOST, SPIDER_DIR))
    while True:
        try:
            job = _post("/poll", {})
        except Exception:
            time.sleep(0.2)
            continue
        if not job or job.get("id") is None:
            time.sleep(0.05)
            continue
        outcome = {"id": job["id"]}
        try:
            outcome["result"] = dispatch(job)
        except Exception:
            outcome["error"] = traceback.format_exc(limit=6)
        try:
            _post("/result", outcome)
        except Exception:
            log("result post failed for job %s" % job.get("id"))


main()
''';

from __future__ import annotations

import json
import os
from typing import Any

from _patch import patch, patch_dict
from sigil.model import request_chat_completion


class _Response:
    def __enter__(self) -> "_Response":
        return self

    def __exit__(self, *args: object) -> None:
        del args

    def read(self) -> bytes:
        return b'{"choices":[{"message":{"content":"ok"}}]}'


def _capture_request() -> dict[str, Any]:
    captured: dict[str, Any] = {}

    def urlopen(req: Any, timeout: int) -> _Response:
        captured["url"] = req.full_url
        captured["timeout"] = timeout
        captured["headers"] = dict(req.header_items())
        captured["body"] = json.loads(req.data.decode("utf-8"))
        return _Response()

    captured["urlopen"] = urlopen
    return captured


def test_request_chat_completion_omits_authorization_without_api_key() -> None:
    captured = _capture_request()
    env = {
        "SIGIL_MODEL_URL": "http://example.test/v1/chat/completions",
    }
    with patch_dict(os.environ, env, clear=True):
        with patch("sigil.model.urllib.request.urlopen", captured["urlopen"]):
            payload = request_chat_completion({"model": "local-model"})

    assert payload["choices"][0]["message"]["content"] == "ok"
    assert captured["url"] == "http://example.test/v1/chat/completions"
    assert captured["timeout"] == 120
    assert "Authorization" not in captured["headers"]
    assert captured["body"] == {"model": "local-model"}


def test_request_chat_completion_sends_bearer_api_key() -> None:
    captured = _capture_request()
    env = {
        "SIGIL_MODEL_API_KEY": " secret-token \n",
        "SIGIL_MODEL_URL": "http://example.test/v1/chat/completions",
    }
    with patch_dict(os.environ, env, clear=True):
        with patch("sigil.model.urllib.request.urlopen", captured["urlopen"]):
            request_chat_completion({"model": "remote-model"})

    assert captured["headers"]["Authorization"] == "Bearer secret-token"

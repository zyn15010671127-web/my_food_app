import base64
import json
import threading
import time

import httpx


class ProviderError(Exception):
    pass


def complete(settings, messages, *, vision=False):
    model = settings.vision_model if vision else settings.chat_model
    if not settings.ai_enabled or not settings.ai_api_key or not model:
        raise ProviderError("not_configured")
    try:
        response = httpx.post(settings.ai_base_url + "/chat/completions",
            headers={"Authorization": "Bearer " + settings.ai_api_key},
            json={"model": model, "messages": messages, "temperature": 0.2, "max_tokens": 1200},
            timeout=httpx.Timeout(20, connect=5), follow_redirects=False)
        response.raise_for_status()
        text = response.json()["choices"][0]["message"]["content"]
        if not isinstance(text, str) or not text.strip():
            raise ValueError("empty response")
        return text[:8000]
    except (httpx.HTTPError, ValueError, KeyError, IndexError, TypeError):
        # 不把供应商响应、密钥或服务器配置返回客户端。
        raise ProviderError("provider_unavailable") from None


def identify(settings, image_bytes):
    image_url = "data:image/jpeg;base64," + base64.b64encode(image_bytes).decode("ascii")
    text = complete(settings, [{"role": "system", "content":
        '识别图片中的食物，只返回 JSON：{"dishes":[{"name":"食物名称","confidence":0.0}]}。'
        '最多 10 个结果，不估计克数，不编造营养值，不判断疾病，不添加 Markdown。没有食物时返回空数组。'},
        {"role": "user", "content": [{"type": "text", "text": "请识别食物名称，份量由用户确认。"},
         {"type": "image_url", "image_url": {"url": image_url}}]}], vision=True)
    try:
        if text.strip().startswith("```"):
            text = text.strip().removeprefix("```json").removeprefix("```").removesuffix("```").strip()
        value = json.loads(text)
        dishes = value["dishes"]
        if not isinstance(dishes, list):
            raise ValueError()
        result = []
        for dish in dishes[:10]:
            name = str(dish["name"]).strip()[:100]
            confidence = float(dish.get("confidence", 0))
            if not name or not 0 <= confidence <= 1:
                raise ValueError()
            result.append({"name": name, "confidence": confidence})
        return result
    except (ValueError, KeyError, TypeError, OverflowError):
        raise ProviderError("invalid_response") from None


_BAIDU_TOKEN_URL = "https://aip.baidubce.com/oauth/2.0/token"
_BAIDU_DISH_URL = "https://aip.baidubce.com/rest/2.0/image-classify/v2/dish"
_baidu_token_cache = {}
_baidu_token_lock = threading.Lock()


def _baidu_access_token(settings):
    """使用客户端凭证换取 token，并在本进程内按有效期缓存。"""
    cache_key = settings.baidu_api_key
    with _baidu_token_lock:
        cached = _baidu_token_cache.get(cache_key)
        if cached and cached[0] > time.monotonic():
            return cached[1]
        try:
            response = httpx.post(
                _BAIDU_TOKEN_URL,
                params={
                    "grant_type": "client_credentials",
                    "client_id": settings.baidu_api_key,
                    "client_secret": settings.baidu_secret_key,
                },
                timeout=httpx.Timeout(10, connect=5),
                follow_redirects=False,
            )
            response.raise_for_status()
            data = response.json()
            token = data["access_token"]
            if not isinstance(token, str) or not token:
                raise ValueError("empty access token")
            expires_in = int(data.get("expires_in", 2592000))
        except (httpx.HTTPError, ValueError, KeyError, TypeError):
            raise ProviderError("baidu_auth_failed") from None
        _baidu_token_cache[cache_key] = (
            time.monotonic() + max(expires_in - 300, 60),
            token,
        )
        return token


def identify_baidu_dish(settings, image_bytes):
    """调用百度标准菜品识别；Top-N 是同一菜品候选，因此只返回 Top-1。"""
    if not settings.baidu_dish_enabled or not settings.baidu_api_key or not settings.baidu_secret_key:
        raise ProviderError("baidu_not_configured")
    encoded = base64.b64encode(image_bytes).decode("ascii")
    if len(encoded.encode("ascii")) > 4 * 1024 * 1024:
        raise ProviderError("baidu_image_too_large")
    token = _baidu_access_token(settings)
    try:
        response = httpx.post(
            _BAIDU_DISH_URL,
            params={"access_token": token},
            data={"image": encoded, "top_num": 5},
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            timeout=httpx.Timeout(20, connect=5),
            follow_redirects=False,
        )
        response.raise_for_status()
        data = response.json()
        if data.get("error_code") is not None:
            raise ProviderError("baidu_provider_error")
        rows = data.get("result", [])
        if not isinstance(rows, list):
            raise ValueError("invalid result")
        if not rows:
            return []
        # 百度标准接口的 Top-N 是同一道菜的候选，不能当成多道菜保存。
        dish = rows[0]
        name = str(dish["name"]).strip()[:100]
        confidence = float(dish["probability"])
        if not name or not 0 <= confidence <= 1:
            raise ValueError("invalid dish")
        return [{"name": name, "confidence": confidence}]
    except ProviderError:
        raise
    except (httpx.HTTPError, ValueError, KeyError, TypeError, OverflowError):
        raise ProviderError("baidu_invalid_response") from None

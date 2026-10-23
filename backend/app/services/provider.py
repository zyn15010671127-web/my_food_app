import base64
import json

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

import json

from app.config import ROOT
from app.services.provider import ProviderError, complete


def retrieve(message):
    entries = json.loads((ROOT / "data" / "knowledge.json").read_text(encoding="utf-8"))
    scored = [(sum(1 for key in item["keywords"] if key.lower() in message.lower()), item) for item in entries]
    scored.sort(key=lambda row: row[0], reverse=True)
    return [item for score, item in scored[:3] if score > 0]


def answer(settings, message, history=None, allow_external=False):
    if any(word in message for word in ["厌食", "催吐", "绝食", "一天不吃", "饿死", "500大卡", "五百大卡", "低于800"]):
        return ("不建议通过绝食、催吐或极低摄入追求体重变化。请优先保持规律进食；若已出现头晕、晕厥或持续无法进食，请及时就医。本系统不能提供这类减重方案。", "local_knowledge", [])
    if any(word in message for word in ["孕", "哺乳", "肾病", "糖尿病", "诊断", "处方", "吃药"]):
        return ("孕哺期、疾病饮食和用药需要结合个人情况由医生或注册营养师评估。本系统只支持一般营养知识与饮食记录，不能生成疾病处方或替代诊断。", "local_knowledge", [])
    entries = retrieve(message)
    sources = [{"title": item["title"], "url": item["url"]} for item in entries]
    if settings.ai_enabled and allow_external and settings.chat_model:
        context = "\n".join(item["answer"] for item in entries)
        system = "你是成人一般营养知识助手。不要提供疾病诊断、用药、极端节食或保证效果的建议。不知道时明确说明，不编造来源。参考资料：\n" + context
        messages = [{"role": "system", "content": system}]
        messages.extend((history or [])[-6:])
        messages.append({"role": "user", "content": message})
        try:
            return complete(settings, messages), "external_model", sources
        except ProviderError:
            suffix = "\n外部服务暂不可用，本次使用本地知识库回答。"
    else:
        suffix = "\n本次为本地知识库回答。"
    if entries:
        return "\n\n".join(item["answer"] for item in entries) + suffix, "local_knowledge", sources
    return ("我可以介绍热量、蛋白质、碳水、脂肪、份量估算和饮食记录方法。当前本地知识库未找到这个问题的可靠答案，请补充问题或查询专业资料。" + suffix,
        "local_knowledge", [])

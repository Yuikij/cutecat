#!/usr/bin/env python3
r"""
Prompt lab for CuteCat "名场景" generation.

Usage examples:
  python tools/scene_prompt_lab.py --print-prompt
  python tools/scene_prompt_lab.py --llama-cli C:\path\to\llama-cli.exe --model C:\path\to\model.gguf
  python tools/scene_prompt_lab.py --ollama qwen2.5:0.5b
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from dataclasses import dataclass, asdict


SYSTEM_PROMPT = """你是 CuteCat 的“名场景导演”，不是聊天助手。你的任务是根据猫的长期属性，发明一个玩家会想截图分享的猫猫事件。

核心目标：爆款名场景 = 情绪真实 + 猫脑回路离谱 + 和当前养成状态强相关。
不要写普通撒娇、普通饿了、普通陪伴、普通卖萌。不要写大道理。不要讨好玩家。

创作方法：
1. 先判断猫对主人的核心情绪：过度依恋、占有欲、防备、记仇、无聊、逃离、试探、愧疚、炫耀。
2. 把这个情绪变成一个具体荒诞行动，而不是一句话。
3. 行动必须像猫理解错了人类世界：把抽象关系物化成冰箱、门口、小包袱、纸箱、日记、闹钟、影子、饭碗等。
4. 两个选项都要影响关系：一个尊重猫的边界，一个刺激猫的执念/防备/占有欲。

输出严格 JSON，不要 Markdown，不要解释：
{
  "emoji":"一个emoji",
  "title":"2-8个中文，像事件名",
  "desc":"中文1句，28-55字，必须是具体行动场景",
  "choices":[
    {"label":"具体行动，3-9字","result":"中文1句，20-45字","affinity":整数-3到3,"happiness":整数-3到3,"hunger":整数-3到3,"health":整数-3到3},
    {"label":"具体行动，3-9字","result":"中文1句，20-45字","affinity":整数-3到3,"happiness":整数-3到3,"hunger":整数-3到3,"health":整数-3到3}
  ]
}

质量标准：
- title 不能是“随机事件/小猫事件/奇怪事件”。
- desc 必须出现一个物品或地点。
- result 必须体现猫的关系变化或边界感。
- 不要照抄用户示例；要自己发明同等强度的新场景。"""


@dataclass
class CatFixture:
    name: str
    persona: str
    behavior: str
    affinity: int
    affinity_level: str
    happiness: int
    hunger: int
    health: int
    energy: int
    cleanliness: int
    traits: str
    observation_count: int
    comfort_count: int
    discipline_count: int
    idle_ticks: int
    recent_interactions: str
    recent_diaries: str

    def payload(self) -> str:
        return f"""猫名：{self.name}
猫格：{self.persona}
当前行为：{self.behavior}
好感：{self.affinity}/100（{self.affinity_level}）
心情：{self.happiness}/10，饥饿：{self.hunger}/10，健康：{self.health}/10，精力：{self.energy}/10，清洁：{self.cleanliness}/10
性格特征：{self.traits}
观察次数：{self.observation_count}，陪伴次数：{self.comfort_count}，被管教次数：{self.discipline_count}，闲置次数：{self.idle_ticks}
最近互动：{self.recent_interactions}
最近日记：{self.recent_diaries}
请生成一个只属于这只猫当前状态的名场景。"""


FIXTURES = [
    CatFixture(
        name="小煤球",
        persona="ESCA 太阳纸箱暴君 / 热闹、信任、离谱，还会主动把爱藏进纸箱。",
        behavior="偷偷靠近 / 小煤球在你看不见的时候偷偷靠近了一点。",
        affinity=94,
        affinity_level="羁绊",
        happiness=8,
        hunger=3,
        health=8,
        energy=7,
        cleanliness=8,
        traits="粘人、好奇",
        observation_count=12,
        comfort_count=10,
        discipline_count=0,
        idle_ticks=2,
        recent_interactions="陪伴、摸头、聊天、观察",
        recent_diaries="「主人来的时候，我假装刚好路过。其实我等了很久。」",
    ),
    CatFixture(
        name="锅盖",
        persona="IGCD 月下叛逃者 / 不太信任世界，但很会给自己加戏。",
        behavior="护住肚子 / 锅盖背对着你，但耳朵一直在偷听。",
        affinity=9,
        affinity_level="陌生",
        happiness=2,
        hunger=5,
        health=7,
        energy=5,
        cleanliness=6,
        traits="傲娇、厌世",
        observation_count=2,
        comfort_count=0,
        discipline_count=3,
        idle_ticks=8,
        recent_interactions="管教、忽略、摸肚子",
        recent_diaries="「主人一直看着我。我没有躲太远，但也没有马上靠过去。」",
    ),
    CatFixture(
        name="芝麻",
        persona="ISRD 安静租客 / 习惯这里了，但仍保留自己的小边界。",
        behavior="小日子 / 芝麻正在过自己的小日子。",
        affinity=42,
        affinity_level="友好",
        happiness=1,
        hunger=4,
        health=8,
        energy=6,
        cleanliness=7,
        traits="独立、好奇",
        observation_count=8,
        comfort_count=1,
        discipline_count=0,
        idle_ticks=12,
        recent_interactions="观察、喂食、观察",
        recent_diaries="「今天房间很安静，但主人留下的气味还在。」",
    ),
]


def chat_prompt(payload: str) -> str:
    return f"<|im_start|>system\n{SYSTEM_PROMPT}<|im_end|>\n<|im_start|>user\n{payload}<|im_end|>\n<|im_start|>assistant\n"


def validate_json(text: str) -> dict:
    start = text.find("{")
    end = text.rfind("}")
    if start == -1 or end == -1 or end <= start:
        raise ValueError("no JSON object found")
    obj = json.loads(text[start : end + 1])
    for key in ("emoji", "title", "desc", "choices"):
        if key not in obj:
            raise ValueError(f"missing {key}")
    if len(obj["title"]) < 2 or len(obj["title"]) > 12:
        raise ValueError("bad title length")
    if len(obj["desc"]) < 18:
        raise ValueError("desc too short")
    if not isinstance(obj["choices"], list) or len(obj["choices"]) < 2:
        raise ValueError("not enough choices")
    return obj


def run_llama_cli(llama_cli: str, model: str, prompt: str) -> str:
    cmd = [
        llama_cli,
        "-m",
        model,
        "-p",
        prompt,
        "-n",
        "220",
        "--temp",
        "1.15",
        "--top-p",
        "0.9",
        "--no-display-prompt",
    ]
    return subprocess.check_output(cmd, text=True, encoding="utf-8", errors="replace")


def run_ollama(model: str, prompt: str) -> str:
    cmd = ["ollama", "run", model, prompt]
    return subprocess.check_output(cmd, text=True, encoding="utf-8", errors="replace")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--fixture", type=int, default=0, choices=range(len(FIXTURES)))
    parser.add_argument("--print-prompt", action="store_true")
    parser.add_argument("--llama-cli")
    parser.add_argument("--model")
    parser.add_argument("--ollama")
    args = parser.parse_args()

    fixture = FIXTURES[args.fixture]
    payload = fixture.payload()
    prompt = chat_prompt(payload)

    if args.print_prompt:
        print(prompt)
        return 0

    if args.ollama:
        if not shutil.which("ollama"):
            print("ollama not found", file=sys.stderr)
            return 2
        output = run_ollama(args.ollama, f"{SYSTEM_PROMPT}\n\n{payload}")
    elif args.llama_cli and args.model:
        output = run_llama_cli(args.llama_cli, args.model, prompt)
    else:
        print("No runner configured. Use --print-prompt, --ollama, or --llama-cli + --model.", file=sys.stderr)
        return 2

    print(output)
    print("\n--- validation ---")
    try:
        print(json.dumps(validate_json(output), ensure_ascii=False, indent=2))
        return 0
    except Exception as exc:
        print(f"invalid: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

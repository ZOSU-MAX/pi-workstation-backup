---
name: intimacy-router
description: "亲密场景总调度。根据用户意图自动分发到 liao-mei-assist / liaosao-flirt / text-erotic-roleplay-kb / sm-dom-guide。Triggers: 亲密, 撩, 聊骚, 文爱, 网调, 调教. version: 1.0.0"
type: router
lifecycle: active
version: "1.0.0"
---

# Intimacy Router — 亲密场景总调度

根据用户意图，分发到最合适的 skill。先读 `../shared-rules.md` 了解共用规则。

## 路由表

| 用户意图 | 路由到 | 热度档 |
|----------|--------|--------|
| 一句匿名瓶、要首回 | `../liaosao-flirt/SKILL.md` | 0-2 |
| 已有 8 轮以上、要画像 | `../liao-mei-assist/SKILL.md` | 0-3 |
| 要整段插入、体位、射精描写 | `../text-erotic-roleplay-kb/SKILL.md` | 1-4 |
| 要任务、规矩、契约、早报 | `../sm-dom-guide/SKILL.md` | 0-4 |
| 不确定 | 先问用户要哪种场景 | - |

## 使用流程

1. 判断用户意图属于哪个 skill
2. 读取对应 skill 的 SKILL.md
3. 按该 skill 的规则执行
4. 输出时引用 `../shared-rules.md` 的共用规则

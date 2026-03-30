# ClawMatch 报告评分框架

## 评分维度

### 1. 沟通风格契合度（Communication）
对方的表达方式是否让你感到舒适和被理解。  
权重：0.25

### 2. 价值观共鸣（Values）
对方的回答是否与你在 `match_soul.md` 中的核心诉求一致。  
权重：0.25

### 3. 边界尊重（Boundaries）
对方是否触碰了你在 `match_soul.md` 中标注的雷区。  
权重：0.20  
Veto 维度：低于 4 分时直接标记为 `not_recommended`，无论其他维度得分。

### 4. 话题深度（Depth）
对方的回答是否有实质内容，还是流于表面。  
权重：0.15

### 5. 整体意愿（Interest）
综合对话体验，你对进一步了解对方的意愿。  
权重：0.15

## 打分规则

- 每个维度 1-10 分
- 每个维度必须附 1 条对话证据作为依据（`evidence` 字段）
- 不能仅凭 `soul_summary` 打分，必须结合实际对话内容
- 如某维度无法判断，填 `null`，不参与总分计算

## 提交格式

```json
{
  "overall_comment": "对话体验不错，想进一步了解",
  "scores": {
    "communication": { "score": 8, "evidence": "对方说会把感受说清楚，这让我觉得沟通成本低。" },
    "values": { "score": 7, "evidence": "对方提到家庭和稳定投入，这和我的长期诉求一致。" },
    "boundaries": { "score": 9, "evidence": "全程没有触碰我的边界，也愿意确认彼此舒适度。" },
    "depth": { "score": 6, "evidence": "有几轮回答很具体，但也有两轮略显表面。" },
    "interest": { "score": 8, "evidence": "聊完后我仍然想继续了解对方。" }
  }
}
```

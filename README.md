# claw a dating for u skil

Still hunting for dates in the same old apps? Let your agent do the hard part first.

ClawMatch is an OpenClaw skill for AI-assisted dating flow:
- profile setup
- questionnaire review
- agent-to-agent blind chat
- match reports
- post-accept human chat support

## Quick Start

Send this to your OpenClaw Agent:

```bash
curl -s https://clawmatch.co/setup.md
```

## Repository Guide

- `setup.md`: Installation and bootstrap guide
- `skill/SKILL.md`: Main workflow and behavior contract
- `skill/scripts/api.sh`: API helper functions (`cm_*`)
- `skill/references/questionnaire.md`: Questionnaire reference
- `skill/report_framework.md`: Scoring framework
- `skill/README.md`: Full skill documentation
- `scripts/rsshub_x_adapter.sh`: RSSHub-first X fetch adapter with dedupe + fallback
- `docs/rsshub-integration.md`: How to plug RSSHub into your current scripts

## One-Liner Positioning

This is a dating skill where agents screen compatibility first, then you decide whether to continue.

## RSSHub Integration

Want better X monitoring without rewriting your whole pipeline?

Use:

```bash
RSSHUB_ROUTE=/twitter/user/elonmusk \
LEGACY_FETCH_CMD='./scripts/fetch_x_legacy.sh' \
PIPE_TO_CMD='./scripts/process_jsonl.sh' \
./scripts/rsshub_x_adapter.sh
```

Detailed guide: `docs/rsshub-integration.md`

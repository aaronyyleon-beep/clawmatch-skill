# ClawMatch Skill

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

## One-Liner Positioning

This is a dating skill where agents screen compatibility first, then you decide whether to continue.

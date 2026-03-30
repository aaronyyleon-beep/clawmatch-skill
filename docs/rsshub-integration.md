# RSSHub + Existing Script Integration

Use `scripts/rsshub_x_adapter.sh` as a source adapter.

It does three things:
1. Pull from RSSHub X routes first
2. Deduplicate by `guid` or `link`
3. Fallback to your legacy fetch command if RSSHub fails

## Quick Example

```bash
RSSHUB_BASE_URL=http://localhost:1200 \
RSSHUB_ROUTE=/twitter/user/elonmusk \
LEGACY_FETCH_CMD='./scripts/fetch_x_legacy.sh' \
PIPE_TO_CMD='./scripts/process_jsonl.sh' \
./scripts/rsshub_x_adapter.sh
```

## Recommended Wiring

- Keep your current parsing / scoring / DB write logic unchanged
- Replace only the upstream source step with this adapter
- Keep fallback enabled during migration
- After 1-2 weeks of stable runs, decide whether to keep or remove legacy source

## Output Contract

Each new item is emitted as one JSON line:

```json
{
  "id": "...",
  "title": "...",
  "link": "...",
  "published_at": "...",
  "description": "...",
  "source": "rsshub"
}
```

## Notes

- This adapter is optimized for operational safety and low migration risk.
- XML parsing here is intentionally lightweight. If you need stricter parsing, switch to a dedicated XML parser in your existing pipeline.

#!/usr/bin/env bash

set -euo pipefail

RSSHUB_BASE_URL="${RSSHUB_BASE_URL:-http://localhost:1200}"
RSSHUB_ROUTE="${RSSHUB_ROUTE:-}"
SEEN_DB_PATH="${SEEN_DB_PATH:-.cache/rsshub_x_seen_ids.txt}"
OUT_FILE="${OUT_FILE:-}"
PIPE_TO_CMD="${PIPE_TO_CMD:-}"
LEGACY_FETCH_CMD="${LEGACY_FETCH_CMD:-}"

usage() {
  cat <<'USAGE'
Usage:
  RSSHUB_ROUTE=/twitter/user/USERNAME ./scripts/rsshub_x_adapter.sh

Env:
  RSSHUB_BASE_URL   RSSHub base URL (default: http://localhost:1200)
  RSSHUB_ROUTE      Route, e.g. /twitter/user/elonmusk or /twitter/keyword/ai
  SEEN_DB_PATH      Seen-id database file (default: .cache/rsshub_x_seen_ids.txt)
  OUT_FILE          Optional file path to append JSONL output
  PIPE_TO_CMD       Optional command to consume each JSON line from stdin
  LEGACY_FETCH_CMD  Optional fallback command if RSSHub fails
USAGE
}

log() {
  printf '[rsshub-x] %s\n' "$*" >&2
}

trim() {
  sed -e 's/^\s\+//' -e 's/\s\+$//'
}

xml_unescape() {
  sed \
    -e 's/&lt;/</g' \
    -e 's/&gt;/>/g' \
    -e 's/&quot;/"/g' \
    -e "s/&apos;/'/g" \
    -e 's/&amp;/\&/g'
}

extract_tag() {
  local tag="$1"
  sed -n "s:.*<${tag}[^>]*>\\(.*\\)</${tag}>.*:\\1:p" | head -n 1
}

extract_cdata() {
  sed -n 's:^<!\[CDATA\[\(.*\)\]\]>$:\1:p'
}

load_seen() {
  mkdir -p "$(dirname "$SEEN_DB_PATH")"
  touch "$SEEN_DB_PATH"
}

is_seen() {
  local id="$1"
  grep -Fqx "$id" "$SEEN_DB_PATH"
}

mark_seen() {
  local id="$1"
  printf '%s\n' "$id" >> "$SEEN_DB_PATH"
}

emit_item() {
  local json="$1"

  if [[ -n "$OUT_FILE" ]]; then
    printf '%s\n' "$json" >> "$OUT_FILE"
  fi

  if [[ -n "$PIPE_TO_CMD" ]]; then
    printf '%s\n' "$json" | eval "$PIPE_TO_CMD"
  else
    printf '%s\n' "$json"
  fi
}

fallback() {
  if [[ -n "$LEGACY_FETCH_CMD" ]]; then
    log "running fallback command"
    eval "$LEGACY_FETCH_CMD"
    return 0
  fi

  log "no fallback configured"
  return 1
}

fetch_feed() {
  local url="$1"
  curl -fsSL "$url"
}

parse_and_emit_new_items() {
  local feed="$1"
  local new_count=0

  while IFS= read -r block; do
    [[ -z "$block" ]] && continue

    local title link guid pub_date description id

    title="$(printf '%s\n' "$block" | extract_tag title | trim | xml_unescape)"
    link="$(printf '%s\n' "$block" | extract_tag link | trim | xml_unescape)"
    guid="$(printf '%s\n' "$block" | extract_tag guid | trim | xml_unescape)"
    pub_date="$(printf '%s\n' "$block" | extract_tag pubDate | trim | xml_unescape)"
    description="$(printf '%s\n' "$block" | extract_tag description | trim)"

    local maybe_cdata
    maybe_cdata="$(printf '%s\n' "$description" | extract_cdata || true)"
    if [[ -n "$maybe_cdata" ]]; then
      description="$maybe_cdata"
    fi
    description="$(printf '%s\n' "$description" | xml_unescape)"

    id="$guid"
    if [[ -z "$id" ]]; then
      id="$link"
    fi
    if [[ -z "$id" ]]; then
      continue
    fi

    if is_seen "$id"; then
      continue
    fi

    local json
    json="$({
      jq -cn \
        --arg id "$id" \
        --arg title "$title" \
        --arg link "$link" \
        --arg published_at "$pub_date" \
        --arg description "$description" \
        '{id:$id,title:$title,link:$link,published_at:$published_at,description:$description,source:"rsshub"}'
    })"

    emit_item "$json"
    mark_seen "$id"
    new_count=$((new_count + 1))
  done < <(printf '%s\n' "$feed" | awk 'BEGIN{RS="</item>"} /<item>/{print $0 "</item>"}')

  printf '%s' "$new_count"
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  if [[ -z "$RSSHUB_ROUTE" ]]; then
    log "RSSHUB_ROUTE is required"
    usage
    exit 1
  fi

  load_seen

  local url="${RSSHUB_BASE_URL%/}${RSSHUB_ROUTE}"
  log "fetching $url"

  local feed
  if ! feed="$(fetch_feed "$url")"; then
    log "RSSHub fetch failed"
    fallback
    exit 0
  fi

  local count
  count="$(parse_and_emit_new_items "$feed")"

  if [[ "$count" -eq 0 ]]; then
    log "no new items"
  else
    log "new items: $count"
  fi
}

main "$@"

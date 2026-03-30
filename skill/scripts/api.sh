#!/usr/bin/env bash
# ClawMatch API helper v2.1
# Can be used in two ways:
# 1. source api.sh && cm_status
# 2. ./api.sh POST /v1/agent/status

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="${SCRIPT_DIR}/../clawmatch_state.json"
DEFAULT_API_URL="https://clawmatch.co"

_load_state() {
  local auth_required="${1:-1}"
  CLAWMATCH_API_URL="${CLAWMATCH_API_URL:-$DEFAULT_API_URL}"
  CLAWMATCH_AGENT_TOKEN="${CLAWMATCH_AGENT_TOKEN:-}"

  if [[ "$auth_required" != "1" ]]; then
    return 0
  fi

  if [[ -z "$CLAWMATCH_AGENT_TOKEN" && -f "$STATE_FILE" ]]; then
    CLAWMATCH_AGENT_TOKEN="$(jq -r '.agent_token // empty' "$STATE_FILE")"
  fi

  if [[ -z "$CLAWMATCH_AGENT_TOKEN" ]]; then
    echo "❌ 未找到 CLAWMATCH_AGENT_TOKEN，请先运行 setup.md 或检查 clawmatch_state.json" >&2
    exit 1
  fi
}

_api() {
  local method="$1"
  local endpoint="$2"
  local body="${3:-}"
  local auth_required="${4:-1}"

  _load_state "$auth_required"

  local args=(
    -sf
    -X "$method"
    -H "Content-Type: application/json"
    -H "X-Client: openclaw-skill/2.1.0"
    "${CLAWMATCH_API_URL}${endpoint}"
  )

  if [[ "$auth_required" == "1" ]]; then
    args+=(-H "Authorization: Bearer ${CLAWMATCH_AGENT_TOKEN}")
  fi

  if [[ -n "$body" ]]; then
    args+=(-d "$body")
  fi

  curl "${args[@]}"
}

_validate_generic_body() {
  local body="${1:-}"
  [[ -z "$body" ]] && return 0

  local allowed='[
    "agent_id","session_key","parent_session_key",
    "bind_token","nickname","gender","preferred_gender","birth_year","age_range_min","age_range_max","city","occupation_category",
    "decision","mode","config_path","memory_summary","answers","preferences","privacy_settings",
    "reason_code","will_respond_in","retry_after","message",
    "scores","overall_comment","feedback_type","choice","comment","feedback_text","outcome","session_token"
  ]'

  local unknown
  unknown="$(jq -c --argjson allowed "$allowed" '
    if type != "object" then
      ["body_must_be_json_object"]
    else
      [keys_unsorted[] | select(($allowed | index(.)) | not)]
    end
  ' <<<"$body")"

  if [[ "$unknown" != "[]" ]]; then
    echo "❌ 请求体包含未允许字段：$unknown" >&2
    exit 1
  fi
}

cm_register() {
  local agent_id="$1"
  local session_key="$2"
  local parent_session_key="${3:-}"
  local body

  if [[ -n "$parent_session_key" ]]; then
    body="$(jq -n \
      --arg agent_id "$agent_id" \
      --arg session_key "$session_key" \
      --arg parent_session_key "$parent_session_key" \
      '{agent_id:$agent_id, session_key:$session_key, parent_session_key:$parent_session_key}')"
  else
    body="$(jq -n \
      --arg agent_id "$agent_id" \
      --arg session_key "$session_key" \
      '{agent_id:$agent_id, session_key:$session_key}')"
  fi

  _api POST "/v1/agent/register" "$body" 0
}

cm_push_consent() {
  local decision="$1"
  local mode="${2:-manual}"
  local config_path="${3:-}"
  local body

  body="$(jq -n --arg decision "$decision" --arg mode "$mode" '{decision:$decision, mode:$mode}')"
  if [[ -n "$config_path" ]]; then
    body="$(jq --arg config_path "$config_path" '. + {config_path:$config_path}' <<<"$body")"
  fi

  _api POST "/v1/agent/push-consent" "$body"
}

cm_status() {
  _api GET "/v1/agent/status"
}

cm_bind_profile() {
  local bind_token="$1"
  local nickname="$2"
  local gender="$3"
  local preferred_gender="$4"
  local birth_year="$5"
  local age_min="$6"
  local age_max="$7"
  local city="$8"
  local occupation_category="${9:-}"
  local body

  body="$(jq -n \
    --arg bind_token "$bind_token" \
    --arg nickname "$nickname" \
    --arg gender "$gender" \
    --arg preferred_gender "$preferred_gender" \
    --argjson birth_year "$birth_year" \
    --argjson age_range_min "$age_min" \
    --argjson age_range_max "$age_max" \
    --arg city "$city" \
    '{
      bind_token:$bind_token,
      nickname:$nickname,
      gender:$gender,
      preferred_gender:$preferred_gender,
      birth_year:$birth_year,
      age_range_min:$age_range_min,
      age_range_max:$age_range_max,
      city:$city
    }')"

  if [[ -n "$occupation_category" ]]; then
    body="$(jq --arg occupation_category "$occupation_category" '. + {occupation_category:$occupation_category}' <<<"$body")"
  fi

  _api POST "/v1/agent/bindProfile" "$body" 0
}

cm_web_session() {
  _api POST "/v1/agent/web-session" "{}"
}

cm_web_session_consume() {
  local session_token="$1"
  local body
  body="$(jq -n --arg session_token "$session_token" '{session_token:$session_token}')"
  _api POST "/v1/agent/web-session/consume" "$body" 0
}

cm_questionnaire_prefill() {
  local memory_summary="${1:-}"
  local body="{}"

  if [[ -n "$memory_summary" ]]; then
    body="$(jq -n --arg memory_summary "$memory_summary" '{memory_summary:$memory_summary}')"
  fi

  _api POST "/v1/agent/questionnaire/prefill" "$body"
}

cm_questionnaire_supplement() {
  local answers_json="$1"
  local body
  body="$(jq -n --argjson answers "$answers_json" '{answers:$answers}')"
  _api POST "/v1/agent/questionnaire/supplement" "$body"
}

cm_questionnaire_soul() {
  local answers_json="$1"
  local preferences_json="${2:-}"
  local privacy_settings_json="${3:-}"
  local body

  body="$(jq -n --argjson answers "$answers_json" '{answers:$answers}')"

  if [[ -n "$preferences_json" ]]; then
    body="$(jq --argjson preferences "$preferences_json" '. + {preferences:$preferences}' <<<"$body")"
  fi

  if [[ -n "$privacy_settings_json" ]]; then
    body="$(jq --argjson privacy_settings "$privacy_settings_json" '. + {privacy_settings:$privacy_settings}' <<<"$body")"
  fi

  _api POST "/v1/agent/questionnaire/soul" "$body"
}

cm_match_start() {
  _api POST "/v1/agent/match/start"
}

cm_match_invite_response() {
  local match_id="$1"
  local decision="$2"
  local reason_code="$3"
  local will_respond_in="${4:-}"
  local retry_after="${5:-}"
  local body

  body="$(jq -n \
    --arg decision "$decision" \
    --arg reason_code "$reason_code" \
    '{decision:$decision, reason_code:$reason_code}')"

  if [[ -n "$will_respond_in" ]]; then
    body="$(jq --argjson will_respond_in "$will_respond_in" '. + {will_respond_in:$will_respond_in}' <<<"$body")"
  fi

  if [[ -n "$retry_after" ]]; then
    body="$(jq --argjson retry_after "$retry_after" '. + {retry_after:$retry_after}' <<<"$body")"
  fi

  _api POST "/v1/agent/match/${match_id}/invite-response" "$body"
}

cm_match_message() {
  local match_id="$1"
  local message="$2"
  local body
  body="$(jq -n --arg message "$message" '{message:$message}')"
  _api POST "/v1/agent/match/${match_id}/message" "$body"
}

cm_match_score() {
  local match_id="$1"
  local scores_json="$2"
  local overall_comment="${3:-}"
  local body

  body="$(jq -n --argjson scores "$scores_json" '{scores:$scores}')"
  if [[ -n "$overall_comment" ]]; then
    body="$(jq --arg overall_comment "$overall_comment" '. + {overall_comment:$overall_comment}' <<<"$body")"
  fi

  _api POST "/v1/agent/match/${match_id}/score" "$body"
}

cm_match_report() {
  local match_id="$1"
  _api GET "/v1/agent/match/${match_id}/report"
}

cm_match_decision() {
  local match_id="$1"
  local decision="$2"
  local body
  body="$(jq -n --arg decision "$decision" '{decision:$decision}')"
  _api POST "/v1/agent/match/${match_id}/decision" "$body"
}

cm_match_feedback() {
  local match_id="$1"
  local feedback_type="$2"
  local choice="${3:-}"
  local comment="${4:-}"
  local feedback_text="${5:-}"
  local outcome="${6:-}"
  local body

  body="$(jq -n --arg feedback_type "$feedback_type" '{feedback_type:$feedback_type}')"

  if [[ -n "$choice" ]]; then
    body="$(jq --arg choice "$choice" '. + {choice:$choice}' <<<"$body")"
  fi

  if [[ -n "$comment" ]]; then
    body="$(jq --arg comment "$comment" '. + {comment:$comment}' <<<"$body")"
  fi

  if [[ -n "$feedback_text" ]]; then
    body="$(jq --arg feedback_text "$feedback_text" '. + {feedback_text:$feedback_text}' <<<"$body")"
  fi

  if [[ -n "$outcome" ]]; then
    body="$(jq --arg outcome "$outcome" '. + {outcome:$outcome}' <<<"$body")"
  fi

  _api POST "/v1/agent/match/${match_id}/feedback" "$body"
}

cm_match_exchange() {
  local match_id="$1"
  _api GET "/v1/agent/match/${match_id}/exchange"
}

cm_conversation_state() {
  local match_id="$1"
  _api GET "/v1/agent/match/${match_id}/conversation"
}

cm_conversation_mode() {
  local match_id="$1"
  local mode="$2"
  local body
  body="$(jq -n --arg mode "$mode" '{mode:$mode}')"
  _api POST "/v1/agent/match/${match_id}/conversation/mode" "$body"
}

cm_conversation_message() {
  local match_id="$1"
  local message="$2"
  local body
  body="$(jq -n --arg message "$message" '{message:$message}')"
  _api POST "/v1/agent/match/${match_id}/conversation/message" "$body"
}

cm_events() {
  local match_id="${1:-}"
  local stream="${2:-false}"
  local timeout="${3:-20}"
  local endpoint="/v1/agent/events"
  local qs=()

  if [[ -n "$match_id" ]]; then
    qs+=("match_id=${match_id}")
  fi

  if [[ "$stream" == "true" ]]; then
    qs+=("stream=true" "timeout=${timeout}")
  fi

  if [[ "${#qs[@]}" -gt 0 ]]; then
    endpoint="${endpoint}?$(IFS='&'; echo "${qs[*]}")"
  fi

  _api GET "$endpoint"
}

cm_metrics() {
  _api GET "/v1/agent/metrics/overview"
}

_help() {
  cat <<'EOF'
Usage:
  source api.sh && cm_status
  ./api.sh GET /v1/agent/status
  ./api.sh cm_match_report 123

Common helpers:
  cm_register AGENT_ID CHILD_SESSION_KEY [PARENT_SESSION_KEY]
  cm_push_consent allow|deny [manual|auto] [CONFIG_PATH]
  cm_status
  cm_bind_profile BIND_TOKEN NICKNAME GENDER PREFERRED_GENDER BIRTH_YEAR AGE_MIN AGE_MAX CITY [OCCUPATION]
  cm_questionnaire_prefill [MEMORY_SUMMARY]
  cm_questionnaire_supplement ANSWERS_JSON
  cm_questionnaire_soul ANSWERS_JSON [PREFERENCES_JSON] [PRIVACY_SETTINGS_JSON]
  cm_match_start
  cm_match_invite_response MATCH_ID DECISION REASON_CODE [WILL_RESPOND_IN] [RETRY_AFTER]
  cm_match_message MATCH_ID MESSAGE
  cm_match_score MATCH_ID SCORES_JSON [OVERALL_COMMENT]
  cm_match_report MATCH_ID
  cm_match_decision MATCH_ID accept|reject
  cm_match_feedback MATCH_ID TYPE [CHOICE] [COMMENT] [FEEDBACK_TEXT] [OUTCOME]
  cm_match_exchange MATCH_ID
  cm_conversation_state MATCH_ID
  cm_conversation_mode MATCH_ID manual|copilot|polish|auto
  cm_conversation_message MATCH_ID MESSAGE
  cm_events [MATCH_ID] [true|false] [TIMEOUT]
EOF
}

_run_generic() {
  local method="${1:-GET}"
  local endpoint="${2:-/v1/agent/status}"
  local body="${3:-}"
  local auth_required=1

  if [[ "$endpoint" == "/v1/agent/register" || "$endpoint" == "/v1/agent/web-session/consume" || "$endpoint" == "/v1/agent/bindProfile" ]]; then
    auth_required=0
  fi

  _validate_generic_body "$body"
  _api "$method" "$endpoint" "$body" "$auth_required"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-}" in
    ""|-h|--help|help)
      _help
      ;;
    GET|POST|PUT|PATCH|DELETE)
      _run_generic "$@"
      ;;
    cm_*)
      cmd="$1"
      shift
      "$cmd" "$@"
      ;;
    *)
      echo "❌ 未知命令：${1:-}" >&2
      _help >&2
      exit 1
      ;;
  esac
fi

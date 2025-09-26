#!/usr/bin/env bash
set -euo pipefail

# FileMaker Data API CLI helper
# Commands: login, status, layouts, list, find, create, update, delete, logout

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SESS_DIR="$SCRIPT_DIR/.sessions"
mkdir -p "$SESS_DIR"

# Load .env if present
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/.env"
fi

FM_HOST=${FM_HOST:-}
FM_DB=${FM_DB:-}
FM_USER=${FM_USER:-}
FM_PASS=${FM_PASS:-}
FM_LAYOUT=${FM_LAYOUT:-}
FM_INSECURE=${FM_INSECURE:-0}

LAYOUT_OVERRIDE=""
INSECURE_FLAG=""

die() { echo "Error: $*" >&2; exit 1; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "$1 is required"; }
require_cmd curl; require_cmd jq

usage() {
  cat <<USAGE
Usage: $0 [global options] <command> [args]

Global options:
  -H, --host <host>       FileMaker Server host
  -d, --db <name>         Database name
  -u, --user <name>       Username
  -p, --pass <pass>       Password
  -l, --layout <name>     Layout name (default: FM_LAYOUT)
      --insecure          Allow self-signed TLS (curl -k)

Commands:
  login                   Obtain and cache a token
  status                  Validate token and show user info
  layouts                 List layouts
  list [--limit N] [--offset N]
  find [key=value ...] [--query-file file.json]
  create key=value [...]
  update <recordId> key=value [...]
  delete <recordId>
  logout                  Revoke and remove cached token
USAGE
}

# Parse global flags
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -H|--host) FM_HOST="$2"; shift 2;;
    -d|--db) FM_DB="$2"; shift 2;;
    -u|--user) FM_USER="$2"; shift 2;;
    -p|--pass) FM_PASS="$2"; shift 2;;
    -l|--layout) LAYOUT_OVERRIDE="$2"; shift 2;;
    --insecure) FM_INSECURE=1; shift;;
    -h|--help) usage; exit 0;;
    *) ARGS+=("$1"); shift;;
  esac
done
set -- "${ARGS[@]}"

[[ ${FM_INSECURE} == 1 ]] && INSECURE_FLAG="-k" || INSECURE_FLAG=""

command -v date >/dev/null || die "date required"

command -v openssl >/dev/null 2>&1 || true

ensure_env() {
  [[ -n "$FM_HOST" ]] || read -rp "FM host: " FM_HOST
  [[ -n "$FM_DB" ]] || read -rp "FM database: " FM_DB
  [[ -n "$FM_USER" ]] || read -rp "FM username: " FM_USER
  if [[ -z "${FM_PASS}" ]]; then
    read -srp "FM password: " FM_PASS; echo
  fi
}

layout() {
  if [[ -n "$LAYOUT_OVERRIDE" ]]; then echo "$LAYOUT_OVERRIDE"; elif [[ -n "$FM_LAYOUT" ]]; then echo "$FM_LAYOUT"; else read -rp "Layout: " L; echo "$L"; fi
}

token_key() { echo "${FM_HOST}_${FM_DB}_${FM_USER}" | tr '/:@' '____'; }
token_file() { echo "$SESS_DIR/$(token_key).token"; }

base_url() { echo "https://${FM_HOST}/fmi/data/vLatest/databases/${FM_DB}"; }

save_token() { echo "$1" > "$(token_file)"; chmod 600 "$(token_file)"; }
load_token() { [[ -f "$(token_file)" ]] && cat "$(token_file)" || true; }
clear_token() { rm -f "$(token_file)"; }

api_login() {
  ensure_env
  local url; url="$(base_url)/sessions"
  local tok
  tok=$(curl -sS ${INSECURE_FLAG} -u "$FM_USER:$FM_PASS" -H 'Content-Type: application/json' -X POST "$url" | jq -r '.response.token // empty')
  [[ -n "$tok" ]] || die "Login failed. Check credentials and host."
  save_token "$tok"
  echo "$tok"
}

auth_header() {
  local tok
  tok=$(load_token)
  if [[ -z "$tok" ]]; then tok=$(api_login); fi
  echo "Authorization: Bearer $tok"
}

api_call() {
  local method="$1"; shift
  local path="$1"; shift
  local data_flag=()
  local headers=("$(auth_header)" 'Content-Type: application/json')
  if [[ $# -gt 0 ]]; then data_flag=(-d "$1"); fi
  local url="$(base_url)$path"
  set +e
  local resp
  resp=$(curl -sS ${INSECURE_FLAG} -X "$method" -H "${headers[0]}" -H "${headers[1]}" "${data_flag[@]}" "$url")
  local code
  code=$(echo "$resp" | jq -r '.messages[0].code // empty')
  # 952 is invalid token; 401 generally also indicates auth issues; FileMaker returns 952
  if [[ "$code" == "952" ]]; then
    # retry once after re-login
    local _tok
    _tok=$(api_login)
    resp=$(curl -sS ${INSECURE_FLAG} -X "$method" -H "Authorization: Bearer $_tok" -H 'Content-Type: application/json' "${data_flag[@]}" "$url")
  fi
  set -e
  echo "$resp"
}

to_fielddata_json() {
  # Convert key=value args to {fieldData:{...}} JSON
  local json='{}'
  for kv in "$@"; do
    local k="${kv%%=*}"; local v="${kv#*=}"
    json=$(jq -c --arg k "$k" --arg v "$v" '. + {($k): $v}' <<< "$json")
  done
  jq -c --argjson fd "$json" -n '{fieldData: $fd}'
}

cmd_login() { api_login >/dev/null; echo "Logged in and cached token."; }

cmd_status() {
  local resp
  resp=$(api_call GET "/layouts")
  echo "$resp" | jq '{ok:(.messages[0].code=="0"), user: .response?."userInfo"? // {} , message: .messages[0]}'
}

cmd_layouts() { api_call GET "/layouts" | jq -r '.response.layouts[].name'; }

cmd_list() {
  local lay; lay=$(layout)
  local limit="" offset=""
  while [[ $# -gt 0 ]]; do case "$1" in --limit) limit="$2"; shift 2;; --offset) offset="$2"; shift 2;; *) break;; esac; done
  local q=""
  [[ -n "$limit" ]] && q+="limit=$limit"
  [[ -n "$offset" ]] && q+="${q:+&}offset=$offset"
  api_call GET "/layouts/${lay}/records${q:+?$q}" | jq
}

cmd_find() {
  local lay; lay=$(layout)
  local qfile=""; local fields=()
  while [[ $# -gt 0 ]]; do case "$1" in --query-file) qfile="$2"; shift 2;; *) fields+=("$1"); shift;; esac; done
  local body
  if [[ -n "$qfile" ]]; then body=$(cat "$qfile"); else
    # Build {query:[{k:v, ...}]}
    local obj='{}'
    for kv in "${fields[@]}"; do local k="${kv%%=*}"; local v="${kv#*=}"; obj=$(jq -c --arg k "$k" --arg v "$v" '. + {($k): $v}' <<< "$obj"); done
    body=$(jq -c --argjson o "$obj" -n '{query:[$o]}' )
  fi
  api_call POST "/layouts/${lay}/_find" "$body" | jq
}

cmd_create() {
  local lay; lay=$(layout)
  [[ $# -ge 1 ]] || die "Provide fields as key=value"
  local body; body=$(to_fielddata_json "$@")
  api_call POST "/layouts/${lay}/records" "$body" | jq
}

cmd_update() {
  local lay; lay=$(layout)
  [[ $# -ge 2 ]] || die "Usage: update <recordId> key=value ..."
  local recid="$1"; shift
  local body; body=$(to_fielddata_json "$@")
  api_call PATCH "/layouts/${lay}/records/${recid}" "$body" | jq
}

cmd_delete() {
  local lay; lay=$(layout)
  [[ $# -ge 1 ]] || die "Usage: delete <recordId>"
  local recid="$1"; shift
  api_call DELETE "/layouts/${lay}/records/${recid}" | jq
}

cmd_logout() {
  local tok; tok=$(load_token)
  if [[ -n "$tok" ]]; then
    curl -sS ${INSECURE_FLAG} -H "Authorization: Bearer $tok" -X DELETE "$(base_url)/sessions/$tok" >/dev/null || true
    clear_token
    echo "Logged out and token cleared."
  else
    echo "No cached token."
  fi
}

main() {
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    login)   cmd_login "$@";;
    status)  cmd_status "$@";;
    layouts) cmd_layouts "$@";;
    list)    cmd_list "$@";;
    find)    cmd_find "$@";;
    create)  cmd_create "$@";;
    update)  cmd_update "$@";;
    delete)  cmd_delete "$@";;
    logout)  cmd_logout "$@";;
    ""|-h|--help) usage;;
    *) die "Unknown command: $cmd";;
  esac
}

main "$@"


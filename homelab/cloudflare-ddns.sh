#!/usr/bin/env bash

set -o pipefail

readonly api="https://api.cloudflare.com/client/v4"

declare -a record_name=()
account_id=""
zone_id=""
token=""
HELP=0
ERR=0

help () {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Update Cloudflare DNS (A and AAAA) records with the current public IPv4/IPv6 addresses.

Options:
  --account-id <id>   Cloudflare Account ID
  --zone-id <id>      Cloudflare Zone ID (required)
  --token <token>     Cloudflare API Bearer Token (required)
  --name <hostname>   DNS record name to update (required, can be specified multiple times)
  --help              Show this help message and exit

Example:
  $(basename "$0") \\
    --account-id <account_id> \\
    --zone-id <zone_id> \\
    --token <api_token> \\
    --name host1.example.com \\
    --name host2.example.com
EOF
}

error () {
  printf "Error: %s\n" "$1" >&2
}

require_arg () {
  if [[ $# -lt 2 || -z "$2" || "$2" == --* ]]; then
    error "Option '$1' requires a value."
    ERR=1
    return 1
  fi
  return 0
}

if [[ $# -eq 0 ]]; then
  HELP=1
  ERR=1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --account-id)
      require_arg "$1" "${2:-}" || break
      account_id="$2"
      shift 2
      ;;
    --account-id=*)
      account_id="${1#*=}"
      require_arg "--account-id" "${account_id}" || break
      shift
      ;;
    --zone-id)
      require_arg "$1" "${2:-}" || break
      zone_id="$2"
      shift 2
      ;;
    --zone-id=*)
      zone_id="${1#*=}"
      require_arg "--zone-id" "${zone_id}" || break
      shift
      ;;
    --name)
      require_arg "$1" "${2:-}" || break
      record_name+=("$2")
      shift 2
      ;;
    --name=*)
      val="${1#*=}"
      require_arg "--name" "${val}" || break
      record_name+=("${val}")
      shift
      ;;
    --token)
      require_arg "$1" "${2:-}" || break
      token="$2"
      shift 2
      ;;
    --token=*)
      token="${1#*=}"
      require_arg "--token" "${token}" || break
      shift
      ;;
    --help)
      HELP=1
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      error "Unknown option: $1"
      HELP=1
      ERR=1
      break
      ;;
  esac
done

readonly account_id zone_id token

# @param version (4 or 6)
ipv () {
  local version="${1}"
  local cf_dns="1.1.1.1"
  [[ "${version}" == "6" ]] && cf_dns="[2606:4700:4700::1111]"

  local ip
  if ! ip=$(curl -fsS -"${version}" --max-time 10 "https://${cf_dns}/cdn-cgi/trace" 2>/dev/null | awk -F= '/^ip=/{print $2}'); then
    error "Failed to fetch public IPv${version} address."
    return 1
  fi

  if [[ -z "${ip}" ]]; then
    error "Empty IPv${version} address returned from trace."
    return 1
  fi

  printf "%s\n" "${ip}"
}

# @param string name
get_record () {
  local name="${1}"
  local response

  if ! response=$(curl -sS -X GET "${api}/zones/${zone_id}/dns_records?name=${name}" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" 2>/dev/null); then
    error "HTTP request failed when fetching records for '${name}'."
    return 1
  fi

  if [[ "$(jq -r '.success' <<< "${response}")" != "true" ]]; then
    local api_err
    api_err=$(jq -r '.errors | map(.message) | join("; ")' <<< "${response}")
    error "Cloudflare API error fetching '${name}': ${api_err:-Unknown error}"
    return 1
  fi

  jq -c '.result[] | select(.type == "A" or .type == "AAAA") | {id, type, name, content, proxied}' <<< "${response}"
}

# @param string name
update-ddns () {
  local name="${1}"
  local records

  if ! records=$(get_record "${name}"); then
    return 1
  fi

  if [[ -z "${records}" ]]; then
    error "No A or AAAA DNS records found for '${name}'."
    return 1
  fi

  local has_error=0
  local record_aux
  while IFS= read -r record_aux; do
    [[ -z "${record_aux}" ]] && continue

    local record_id record_type current_ip ipversion ipaddress payload update_resp
    record_id=$(jq -r '.id' <<< "${record_aux}")
    record_type=$(jq -r '.type' <<< "${record_aux}")
    current_ip=$(jq -r '.content' <<< "${record_aux}")

    case "${record_type}" in
      A)    ipversion=4 ;;
      AAAA) ipversion=6 ;;
      *)
        error "Unsupported record type '${record_type}' for '${name}'."
        has_error=1
        continue
        ;;
    esac

    if ! ipaddress=$(ipv "${ipversion}"); then
      has_error=1
      continue
    fi

    payload=$(jq -c --arg ip "${ipaddress}" 'del(.id) | .content = $ip' <<< "${record_aux}")

    if ! update_resp=$(curl -sS -X PUT "${api}/zones/${zone_id}/dns_records/${record_id}" \
      -H "Authorization: Bearer ${token}" \
      -H "Content-Type: application/json" \
      --data "${payload}" 2>/dev/null); then
      error "HTTP request failed when updating ${record_type} record for '${name}'."
      has_error=1
      continue
    fi

    if [[ "$(jq -r '.success' <<< "${update_resp}")" != "true" ]]; then
      local api_err
      api_err=$(jq -r '.errors | map(.message) | join("; ")' <<< "${update_resp}")
      error "Failed to update ${record_type} record for '${name}': ${api_err:-Unknown error}"
      has_error=1
      continue
    fi

    printf "Updated %s (%s): %s -> %s\n" "${name}" "${record_type}" "${current_ip}" "${ipaddress}"
  done <<< "${records}"

  return "${has_error}"
}

main () {
  if [[ "${HELP}" -eq 1 ]]; then
    help
    exit "${ERR}"
  fi

  if [[ "${ERR}" -eq 1 ]]; then
    help >&2
    exit 1
  fi

  for cmd in curl jq awk; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      error "Required command '${cmd}' is not installed."
      exit 1
    fi
  done

  if [[ -z "${zone_id}" ]]; then
    error "--zone-id is required."
    help >&2
    exit 1
  fi

  if [[ -z "${token}" ]]; then
    error "--token is required."
    help >&2
    exit 1
  fi

  if [[ "${#record_name[@]}" -eq 0 ]]; then
    error "At least one --name is required."
    help >&2
    exit 1
  fi

  local exit_code=0
  local name
  for name in "${record_name[@]}"; do
    if ! update-ddns "${name}"; then
      exit_code=1
    fi
  done

  exit "${exit_code}"
}

main

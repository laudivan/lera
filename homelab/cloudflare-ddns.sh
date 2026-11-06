#!/usr/bin/env bash

set -o pipefail

readonly api="https://api.cloudflare.com/client/v4"

declare -a record_name=()
account_id=""
zone_id=""
token=""
HELP=0
ERR=0
err_msg=""

if [[ $# -eq 0 ]]; then
  HELP=1
  ERR=1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --account-id)
      if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
        err_msg="Option '$1' requires a value."
        ERR=1
        break
      fi
      account_id="$2"
      shift 2
      ;;
    --account-id=*)
      account_id="${1#*=}"
      if [[ -z "${account_id}" ]]; then
        err_msg="Option '--account-id' requires a value."
        ERR=1
        break
      fi
      shift
      ;;
    --zone-id)
      if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
        err_msg="Option '$1' requires a value."
        ERR=1
        break
      fi
      zone_id="$2"
      shift 2
      ;;
    --zone-id=*)
      zone_id="${1#*=}"
      if [[ -z "${zone_id}" ]]; then
        err_msg="Option '--zone-id' requires a value."
        ERR=1
        break
      fi
      shift
      ;;
    --name)
      if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
        err_msg="Option '$1' requires a value."
        ERR=1
        break
      fi
      record_name+=("$2")
      shift 2
      ;;
    --name=*)
      if [[ -z "${1#*=}" ]]; then
        err_msg="Option '--name' requires a value."
        ERR=1
        break
      fi
      record_name+=("${1#*=}")
      shift
      ;;
    --token)
      if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
        err_msg="Option '$1' requires a value."
        ERR=1
        break
      fi
      token="$2"
      shift 2
      ;;
    --token=*)
      token="${1#*=}"
      if [[ -z "${token}" ]]; then
        err_msg="Option '--token' requires a value."
        ERR=1
        break
      fi
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
      err_msg="Unknown option: $1"
      HELP=1
      ERR=1
      break
      ;;
  esac
done

readonly account_id zone_id token

# Validate CLI inputs, check dependencies, and run DDNS updates for all record names.
# @param none (uses global options: zone_id, token, record_name, HELP, ERR)
# @return 0 on success, 1 on validation or update failure
main () {
  if [[ -n "${err_msg}" ]]; then
    printf "Error: %s\n" "${err_msg}" >&2
  fi

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
      printf "Error: Required command '%s' is not installed.\n" "${cmd}" >&2
      exit 1
    fi
  done

  if [[ -z "${zone_id}" ]]; then
    printf "Error: --zone-id is required.\n" >&2
    help >&2
    exit 1
  fi

  if [[ -z "${token}" ]]; then
    printf "Error: --token is required.\n" >&2
    help >&2
    exit 1
  fi

  if [[ "${#record_name[@]}" -eq 0 ]]; then
    printf "Error: At least one --name is required.\n" >&2
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

# Fetch and update all A and AAAA records for a given DNS name in Cloudflare.
# @param $1 string name - Fully qualified domain name to update
# @return 0 if all records updated, 1 if lookup or any update fails
update-ddns () {
  local name="${1}"
  local records

  if ! records=$(get_record "${name}"); then
    return 1
  fi

  if [[ -z "${records}" ]]; then
    printf "Error: No A or AAAA DNS records found for '%s'.\n" "${name}" >&2
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
        printf "Error: Unsupported record type '%s' for '%s'.\n" "${record_type}" "${name}" >&2
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
      printf "Error: HTTP request failed when updating %s record for '%s'.\n" "${record_type}" "${name}" >&2
      has_error=1
      continue
    fi

    if [[ "$(jq -r '.success' <<< "${update_resp}")" != "true" ]]; then
      local api_err
      api_err=$(jq -r '.errors | map(.message) | join("; ")' <<< "${update_resp}")
      printf "Error: Failed to update %s record for '%s': %s\n" "${record_type}" "${name}" "${api_err:-Unknown error}" >&2
      has_error=1
      continue
    fi

    printf "Updated %s (%s): %s -> %s\n" "${name}" "${record_type}" "${current_ip}" "${ipaddress}"
  done <<< "${records}"

  return "${has_error}"
}

# Retrieve existing A and AAAA DNS records for a hostname from the Cloudflare API.
# @param $1 string name - Fully qualified domain name to query
# @stdout Compact JSON objects ({id, type, name, content, proxied}), one per line
# @return 0 on success, 1 on HTTP or API error
get_record () {
  local name="${1}"
  local response

  if ! response=$(curl -sS -X GET "${api}/zones/${zone_id}/dns_records?name=${name}" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" 2>/dev/null); then
    printf "Error: HTTP request failed when fetching records for '%s'.\n" "${name}" >&2
    return 1
  fi

  if [[ "$(jq -r '.success' <<< "${response}")" != "true" ]]; then
    local api_err
    api_err=$(jq -r '.errors | map(.message) | join("; ")' <<< "${response}")
    printf "Error: Cloudflare API error fetching '%s': %s\n" "${name}" "${api_err:-Unknown error}" >&2
    return 1
  fi

  jq -c '.result[] | select(.type == "A" or .type == "AAAA") | {id, type, name, content, proxied}' <<< "${response}"
}

# Detect the current public IP address using Cloudflare's trace endpoint.
# @param $1 int version - IP protocol version (4 or 6)
# @stdout Public IPv4 or IPv6 address
# @return 0 on success, 1 if lookup fails or returns empty
ipv () {
  local version="${1}"
  local cf_dns="1.1.1.1"
  [[ "${version}" == "6" ]] && cf_dns="[2606:4700:4700::1111]"

  local ip
  if ! ip=$(curl -fsS -"${version}" --max-time 10 "https://${cf_dns}/cdn-cgi/trace" 2>/dev/null | awk -F= '/^ip=/{print $2}'); then
    printf "Error: Failed to fetch public IPv%s address.\n" "${version}" >&2
    return 1
  fi

  if [[ -z "${ip}" ]]; then
    printf "Error: Empty IPv%s address returned from trace.\n" "${version}" >&2
    return 1
  fi

  printf "%s\n" "${ip}"
}

# Print command usage and available options to stdout.
# @param none
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

main

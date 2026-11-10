#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# cloudflare-ddns.sh - Dynamic DNS updater for Cloudflare (A and AAAA records)
#
# Authors:
#   Laudivan Almeida <laudivan@live.com>
#   Completed with the assistance of Antigravity (Google DeepMind)
#
# License:
#   MIT License - https://opensource.org/licenses/MIT
# -----------------------------------------------------------------------------

set -o pipefail

readonly api="https://api.cloudflare.com/client/v4"
readonly long_opts="help,account-id:,zone-id:,name:,token:"

declare -a record_name=()
account_id=""
zone_id=""
token=""
HELP=0
ERR=0
err_msg=""

# Entry point: parse CLI options, validate inputs, and run DDNS updates.
# @param $@ string - Command-line arguments passed to the script
# @return 0 on success, 1 on validation or update failure
main () {
  parse_options "$@"

  if [[ -n "${err_msg}" ]]; then
    log_error "${err_msg}"
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
      log_error "Required command '${cmd}' is not installed."
      exit 1
    fi
  done

  if [[ -z "${zone_id}" ]]; then
    log_error "--zone-id is required."
    help >&2
    exit 1
  fi

  if [[ -z "${token}" ]]; then
    log_error "--token is required."
    help >&2
    exit 1
  fi

  if [[ "${#record_name[@]}" -eq 0 ]]; then
    log_error "At least one --name is required."
    help >&2
    exit 1
  fi

  local ipv4=""
  local ipv6=""
  ipv4=$(ipv 4 2>/dev/null) || true
  ipv6=$(ipv 6 2>/dev/null) || true

  if [[ -z "${ipv4}" && -z "${ipv6}" ]]; then
    log_error "Failed to detect both public IPv4 and IPv6 addresses."
    exit 1
  fi

  local exit_code=0
  local name rtype target_ip records record
  for name in "${record_name[@]}"; do
    local found_any=0
    for rtype in A AAAA; do
      if ! records=$(get_record \
        "${zone_id}" "${token}" "${name}" "${rtype}"); then
        exit_code=1
        continue
      fi

      [[ -z "${records}" ]] && continue
      found_any=1

      if [[ "${rtype}" == "A" ]]; then
        target_ip="${ipv4}"
      else
        target_ip="${ipv6}"
      fi

      if [[ -z "${target_ip}" ]]; then
        log_error "Public IP for ${rtype} not available for '${name}'."
        exit_code=1
        continue
      fi

      while IFS= read -r record; do
        [[ -z "${record}" ]] && continue

        local current_ip
        current_ip=$(jq -r '.content' <<< "${record}")

        if [[ "${current_ip}" == "${target_ip}" ]]; then
          continue
        fi

        if ! update-ddns \
          "${zone_id}" "${token}" "${record}" "${target_ip}"; then
          exit_code=1
        fi
      done <<< "${records}"
    done

    if [[ "${found_any}" -eq 0 ]]; then
      log_error "No A or AAAA DNS records found for '${name}'."
      exit_code=1
    fi
  done

  exit "${exit_code}"
}

# Log an informational message with a timestamp to stdout.
# @param $* string - Message to log
log_info () {
  printf "%s [INFO] %s\n" "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

# Log an error message with a timestamp to stderr.
# @param $* string - Error message to log
log_error () {
  printf "%s [ERROR] %s\n" "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >&2
}

# Update a single DNS record in Cloudflare with a new IP address.
# @param $1 string zone   - Cloudflare Zone ID
# @param $2 string secret - Cloudflare API Bearer Token
# @param $3 string record - Compact JSON object of the DNS record
# @param $4 string new_ip - Target IP address to set in the record
# @return 0 if updated successfully, 1 on HTTP or API error
update-ddns () {
  local zone="${1}"
  local secret="${2}"
  local record="${3}"
  local new_ip="${4}"

  local record_id record_type name current_ip payload update_resp
  record_id=$(jq -r '.id' <<< "${record}")
  record_type=$(jq -r '.type' <<< "${record}")
  name=$(jq -r '.name' <<< "${record}")
  current_ip=$(jq -r '.content' <<< "${record}")

  payload=$(jq -c --arg ip "${new_ip}" \
    'del(.id) | .content = $ip' <<< "${record}")

  if ! update_resp=$(curl -sS -X PUT \
    "${api}/zones/${zone}/dns_records/${record_id}" \
    -H "Authorization: Bearer ${secret}" \
    -H "Content-Type: application/json" \
    --data "${payload}" 2>/dev/null); then
    log_error "HTTP request failed updating ${record_type} for '${name}'."
    return 1
  fi

  if [[ "$(jq -r '.success' <<< "${update_resp}")" != "true" ]]; then
    local api_err
    api_err=$(jq -r '.errors | map(.message) | join("; ")' <<< "${update_resp}")
    log_error "Failed to update ${record_type} for '${name}':" \
      "${api_err:-Unknown error}"
    return 1
  fi

  log_info "Updated ${name} (${record_type}): ${current_ip} -> ${new_ip}"
  return 0
}

# Retrieve existing DNS records for a hostname and type from Cloudflare API.
# @param $1 string zone   - Cloudflare Zone ID
# @param $2 string secret - Cloudflare API Bearer Token
# @param $3 string name   - Fully qualified domain name to query
# @param $4 string rtype  - DNS record type (A or AAAA)
# @stdout Compact JSON objects ({id, type, name, content, proxied}), 1 per line
# @return 0 on success, 1 on invalid type, HTTP, or API error
get_record () {
  local zone="${1}"
  local secret="${2}"
  local name="${3}"
  local rtype="${4}"
  local response

  if [[ "${rtype}" != "A" && "${rtype}" != "AAAA" ]]; then
    log_error "Invalid record type '${rtype}' (expected A or AAAA)."
    return 1
  fi

  local url="${api}/zones/${zone}/dns_records?name=${name}&type=${rtype}"
  if ! response=$(curl -sS -X GET "${url}" \
    -H "Authorization: Bearer ${secret}" \
    -H "Content-Type: application/json" 2>/dev/null); then
    log_error "HTTP request failed fetching ${rtype} records for '${name}'."
    return 1
  fi

  if [[ "$(jq -r '.success' <<< "${response}")" != "true" ]]; then
    local api_err
    api_err=$(jq -r '.errors | map(.message) | join("; ")' <<< "${response}")
    log_error "Cloudflare API error fetching ${rtype} for '${name}':" \
      "${api_err:-Unknown error}"
    return 1
  fi

  jq -c '.result[] | {id, type, name, content, proxied}' <<< "${response}"
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
  local trace_url="https://${cf_dns}/cdn-cgi/trace"
  if ! ip=$(curl -fsS -${version} --max-time 10 "${trace_url}" 2>/dev/null \
    | awk -F= '/^ip=/{print $2}'); then
    log_error "Failed to fetch public IPv${version} address."
    return 1
  fi

  if [[ -z "${ip}" ]]; then
    log_error "Empty IPv${version} address returned from trace."
    return 1
  fi

  printf "%s\n" "${ip}"
}

# Parse command-line options defined in long_opts and populate globals.
# @param $@ string - Raw command-line arguments
# @return 0 on valid options, 1 on missing value or unknown option
parse_options () {
  if [[ $# -eq 0 ]]; then
    HELP=1
    ERR=1
    return 1
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
        err_msg="Unknown option: $1 (supported: --${long_opts//,/, --})"
        HELP=1
        ERR=1
        break
        ;;
    esac
  done

  readonly account_id zone_id token
  return "${ERR}"
}

# Print command usage and available options to stdout.
# @param none
help () {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Update Cloudflare DNS (A and AAAA) records with public IPv4/IPv6 addresses.

Options:
  --account-id <id>   Cloudflare Account ID
  --zone-id <id>      Cloudflare Zone ID (required)
  --token <token>     Cloudflare API Bearer Token (required)
  --name <hostname>   DNS record name to update (required, repeatable)
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

main "$@"

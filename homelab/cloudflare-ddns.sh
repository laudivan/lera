#!/usr/bin/env bash

readonly api="https://api.cloudflare.com/client/v4"

read PARSED< <(getopt --long 'help,account-id:,zone-id:,name:,token:' )

[ $? -ne 0 ] && readonly HELP=1

eval set -- "$PARSED"

while :; do
  case "$1" in
    --account-id)
      readonly account_id="$2"
      shift; shift
      ;;
    --zone-id)
      readonly zone_id="$2"
      shift; shift
      ;;
    --name)
      echo $1
      # record_name+=$2
      shift; shift
      ;;
    --token)
      readonly token="$2"
      shift; shift
      ;;
    --help)
      readonly HELP=1
      shift
      ;;
    --)
      shift
      break
      ;; 
    *)
      HELP=1
      ERR=1
      ;;
  esac
done

main () {
  [ HELP ] && help && exit 0

  #echo ${record_name[*]}
}

# @param string name
update-ddns () {
  local name = "${1}"

  read record_aux< <(get_record ${accound_id} ${zone_id} ${token} ${name})
  read record_id< <(echo ${record_aux} | jd '.id')
  read record_type< <(echo ${record_aux} | jd '.type')
  local ipversion
  read record< <(echo ${record_aux} | jd '.content |= sub("[^/]*$"; "\(${ipaddress})")')

  curl -s -X PUT "${api}/zones/${zone_id}/dns_records/${record_id}" \
    -H "Authorization: Bearer ${cloudflare_token}" \
    -H "Content-Type: application/json" \
    --data "${record}"
}

# @param string name
get_record () {
  local name = "${1}"
  
  curl -s -X GET "${api}/zones/${zone_id}/dns_records?type=${type}&name=${name}" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    | jq '.result[] | {id, type, name, content, proxied}'
}

# @param version
ipv () {
  local version = $1
  
  local cf_dns=$(("${version}" == 6 ? "[2606:4700:4700::1111]" : "1.1.1.1"))
  curl -s -4 "https://${cf_dns}/cdn-cgi/trace" | awk -F= '/^ip=/{print $2}'
}

help () {
  printf 'USE %s'
  return
}

main

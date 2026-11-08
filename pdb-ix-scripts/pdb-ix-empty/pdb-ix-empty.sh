#!/usr/bin/env bash
set -euo pipefail

# pdb-ix-empty
# List PeeringDB internet exchanges (ix) with no networks present (net_count = 0).
#
# Usage:
#   ./pdb-ix-empty.sh
#   COUNTRY=AU ./pdb-ix-empty.sh
#   COUNTRY=AU EMPTY_OF=net,fac ./pdb-ix-empty.sh
#   FORMAT=csv ./pdb-ix-empty.sh > empty-ixps.csv
#
# Requirements:
#   - curl, jq
#   - export PEERINGDB_API_KEY="..."

COUNTRY="${COUNTRY:-}"          # ISO 3166-1 alpha-2 code, e.g. AU (blank = all countries)
EMPTY_OF="${EMPTY_OF:-net}"     # which counters must be zero: net and/or fac
FORMAT="${FORMAT:-table}"       # table | csv | json
PDB_API="${PDB_API:-https://www.peeringdb.com/api}"
PDB_WEB="https://www.peeringdb.com"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

# --- Checks -----------------------------------------------------------------

command -v curl >/dev/null 2>&1 || die "curl is not installed (sudo apt install curl)"
command -v jq   >/dev/null 2>&1 || die "jq is not installed (sudo apt install jq)"

if [[ -z "${PEERINGDB_API_KEY:-}" ]]; then
  echo "ERROR: PEERINGDB_API_KEY is not set. Export your API key first." >&2
  echo 'Example: export PEERINGDB_API_KEY="YOUR_KEY_HERE"' >&2
  exit 1
fi

# Normalise inputs (case, whitespace, stray CRLF)
COUNTRY="$(printf '%s' "${COUNTRY}" | tr '[:lower:]' '[:upper:]' | tr -d ' \t\r\n')"
EMPTY_OF="$(printf '%s' "${EMPTY_OF}" | tr '[:upper:]' '[:lower:]' | tr -d ' \t\r\n')"
FORMAT="$(printf '%s' "${FORMAT}" | tr '[:upper:]' '[:lower:]' | tr -d ' \t\r\n')"

if [[ -n "${COUNTRY}" && ! "${COUNTRY}" =~ ^[A-Z]{2}$ ]]; then
  die "COUNTRY must be a two-letter country code such as AU (got '${COUNTRY}')"
fi

case "${FORMAT}" in
  table|csv|json) ;;
  *) die "FORMAT must be table, csv or json (got '${FORMAT}')" ;;
esac

# Map EMPTY_OF (net,fac) to PeeringDB counter fields
count_fields=()
IFS=',' read -r -a empty_parts <<< "${EMPTY_OF}"
for part in "${empty_parts[@]}"; do
  case "${part}" in
    net) count_fields+=("net_count") ;;
    fac) count_fields+=("fac_count") ;;
    "")  ;;
    *)   die "EMPTY_OF accepts net and/or fac, comma-separated (got '${part}')" ;;
  esac
done
[[ ${#count_fields[@]} -gt 0 ]] || die "EMPTY_OF must name at least one of net, fac"

count_fields_json="$(printf '%s\n' "${count_fields[@]}" | jq -R . | jq -sc 'unique')"
count_fields_label="$(printf '%s\n' "${count_fields[@]}" | sort -u | paste -sd, -)"

# --- Fetch (one request) ----------------------------------------------------

fields="id,name,org_id,org_name,city,country,region_continent,net_count,fac_count,ixf_net_count,updated"
url="${PDB_API}/ix?fields=${fields}"
[[ -n "${COUNTRY}" ]] && url+="&country=${COUNTRY}"

tmp_body="$(mktemp)"
trap 'rm -f "${tmp_body}"' EXIT

http_code="$(curl -sS -o "${tmp_body}" -w '%{http_code}' \
  --connect-timeout 15 --max-time 180 \
  -H "Authorization: Api-Key ${PEERINGDB_API_KEY}" \
  -H "User-Agent: peeringdb-templates/pdb-ix-empty" \
  "${url}")" || die "request to PeeringDB failed (network or DNS problem?)"

case "${http_code}" in
  200) ;;
  401|403)
    die "PeeringDB returned HTTP ${http_code}. Check that PEERINGDB_API_KEY is valid and not revoked." ;;
  429)
    die "PeeringDB rate limit hit (HTTP 429). Wait a few minutes and try again; avoid running this in a tight loop." ;;
  *)
    echo "ERROR: PeeringDB returned HTTP ${http_code}. Response starts with:" >&2
    head -c 300 "${tmp_body}" >&2
    echo >&2
    exit 1 ;;
esac

jq -e '.data | type == "array"' "${tmp_body}" >/dev/null 2>&1 \
  || die "unexpected response from PeeringDB (no .data array)"

# Guard against silently treating a missing counter as zero
jq -e --argjson keys "${count_fields_json}" '
  (.data | length) == 0
  or (.data[0] as $row | all($keys[]; . as $k | $row | has($k)))
' "${tmp_body}" >/dev/null \
  || die "PeeringDB did not return one of: ${count_fields_label}. The API may have changed."

# --- Filter -----------------------------------------------------------------

total="$(jq '.data | length' "${tmp_body}")"

empty_json="$(jq -c --argjson keys "${count_fields_json}" --arg web "${PDB_WEB}" '
  [ .data[]
    | . as $x
    | select(all($keys[]; ($x[.] // -1) == 0))
    | {
        id,
        name: ((.name // "") | gsub("[\t\r\n]"; " ")),
        org_id,
        org_name: ((.org_name // "") | gsub("[\t\r\n]"; " ")),
        city: (.city // ""),
        country: (.country // ""),
        region: (.region_continent // ""),
        net_count,
        fac_count,
        ixf_net_count,
        updated,
        url: "\($web)/ix/\(.id)"
      }
  ]
  | sort_by(.country, .city, .name)
' "${tmp_body}")"

empty_count="$(jq 'length' <<< "${empty_json}")"
ixf_count="$(jq '[.[] | select((.ixf_net_count // 0) > 0)] | length' <<< "${empty_json}")"

summary() {
  echo "Country: ${COUNTRY:-all}"
  echo "IXPs checked: ${total}"
  echo "Empty IXPs (${count_fields_label} all 0): ${empty_count}"
  if [[ "${ixf_count}" -gt 0 ]]; then
    echo "  of which list members in their IX-F export (ixf_net_count > 0): ${ixf_count}"
  fi
}

# --- Output -----------------------------------------------------------------

case "${FORMAT}" in
  json)
    summary >&2
    jq '.' <<< "${empty_json}"
    ;;

  csv)
    summary >&2
    jq -r '
      ["id","name","org_id","org_name","city","country","region","net_count","fac_count","ixf_net_count","updated","url"],
      (.[] | [.id, .name, .org_id, .org_name, .city, .country, .region,
              .net_count, .fac_count, .ixf_net_count, .updated, .url])
      | @csv
    ' <<< "${empty_json}"
    ;;

  table)
    summary
    echo ""
    if [[ "${empty_count}" -eq 0 ]]; then
      echo "No empty IXPs found."
      exit 0
    fi
    table="$(jq -r '
      (["ID","CC","City","IXP","Facs","IX-F nets","URL"] | @tsv),
      (.[] | [.id, .country, .city, .name, (.fac_count // ""), (.ixf_net_count // ""), .url] | @tsv)
    ' <<< "${empty_json}")"
    if command -v column >/dev/null 2>&1; then
      column -t -s $'\t' <<< "${table}"
    else
      printf '%s\n' "${table}"
    fi
    ;;
esac

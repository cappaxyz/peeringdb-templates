#!/usr/bin/env bash
set -euo pipefail

# pdb-ix-participants
# Summarise PeeringDB IX participants and attachments (netixlan) for a given IX ID.
#
# Usage:
#   IX_ID=35 ./pdb-ix-participants
#   IX_ID=35 SHOW_DETAILS=1 ./pdb-ix-participants
#   IX_ID=35 SHOW_DETAILS=1 DETAILS_STYLE=nice ./pdb-ix-participants
#
# Requirements:
#   - curl, jq
#   - export PEERINGDB_API_KEY="..."

IX_ID="${IX_ID:-35}"
SHOW_DETAILS="${SHOW_DETAILS:-0}"
DETAILS_STYLE="${DETAILS_STYLE:-nice}"  # simple | nice

if [[ -z "${PEERINGDB_API_KEY:-}" ]]; then
  echo "ERROR: PEERINGDB_API_KEY is not set. Export your API key first."
  echo 'Example: export PEERINGDB_API_KEY="YOUR_KEY_HERE"'
  exit 1
fi

auth_hdr=(-H "Authorization: Api-Key $PEERINGDB_API_KEY")

# 1) IXLAN(s) for the IX
ixlans=$(curl -s "${auth_hdr[@]}" \
  "https://www.peeringdb.com/api/ixlan?ix_id=${IX_ID}" \
  | jq -r '.data[].id')

if [[ -z "${ixlans}" ]]; then
  echo "IX ID: ${IX_ID}"
  echo "No IXLANs returned for this IX. Check the IX ID and your API key permissions."
  exit 0
fi

# 2) Pull all netixlan rows across all IXLANs (connections)
netixlan_json=$(
  for id in $ixlans; do
    curl -s "${auth_hdr[@]}" \
      "https://www.peeringdb.com/api/netixlan?ixlan_id=${id}" \
      | jq '.data[]'
  done | jq -s '{data: .}'
)

# Connections = total netixlan rows
connections=$(echo "$netixlan_json" | jq '.data | length')

# Total speed = sum of netixlan.speed (Mbps). Missing treated as 0.
total_speed_mbps=$(echo "$netixlan_json" | jq '[.data[].speed // 0] | add')

# Peers = unique networks present = unique net_id count
peer_net_ids=$(echo "$netixlan_json" | jq -r '[.data[].net_id] | unique')
peers=$(echo "$peer_net_ids" | jq 'length')

# Handle IX with no netixlan rows
if [[ "$peers" -eq 0 ]]; then
  echo "IX ID: ${IX_ID}"
  echo "Peers (unique networks / ASNs): 0"
  echo "Connections (netixlan rows): 0"
  echo "Total speed (sum of netixlan.speed, Mbps): 0"
  echo "Open peers (policy_general=Open): 0"
  echo "IPv6-enabled peers (%): 0"
  echo "ASNs:"
  echo ""
  exit 0
fi

# net_id list for bulk lookup
net_ids_csv=$(echo "$peer_net_ids" | jq -r 'join(",")')

# 3) Fetch network objects once (for ASNs + policy)
nets_json=$(curl -s "${auth_hdr[@]}" \
  "https://www.peeringdb.com/api/net?id__in=${net_ids_csv}")

# Peer ASNs (unique)
peer_asns=$(echo "$nets_json" | jq -r '[.data[].asn] | unique | sort')
peer_asn_count=$(echo "$peer_asns" | jq 'length')

# Open peers = networks with policy_general == "Open" (case-insensitive)
open_peers=$(echo "$nets_json" | jq '[.data[] | select((.policy_general // "") | ascii_downcase == "open")] | length')

# IPv6-enabled % (by peer/network) = unique net_id with any ipaddr6 set / unique net_id total
ipv6_pct=$(echo "$netixlan_json" | jq -r '
  def uniqnets: ([.data[].net_id] | unique);
  def v6uniqnets: ([.data[] | select(.ipaddr6 != null and .ipaddr6 != "") | .net_id] | unique);
  if (uniqnets|length)==0 then 0
  else ((v6uniqnets|length) / (uniqnets|length) * 100)
  end
')

# Output summary
echo "IX ID: ${IX_ID}"
echo "Peers (unique networks / ASNs): ${peer_asn_count}"
echo "Connections (netixlan rows): ${connections}"
echo "Total speed (sum of netixlan.speed, Mbps): ${total_speed_mbps}"
echo "Open peers (policy_general=Open): ${open_peers}"
echo "IPv6-enabled peers (%): ${ipv6_pct}"
echo "ASNs:"
echo "$peer_asns" | jq -r '.[]' | paste -sd, -
echo ""

# Optional output block
if [[ "${SHOW_DETAILS}" == "1" ]]; then
  # Normalise DETAILS_STYLE (lowercase, strip whitespace + CRLF)
  details_style_norm="$(printf '%s' "${DETAILS_STYLE}" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -d ' \t\r\n')"

  echo ""

  if [[ "${details_style_norm}" == "nice" ]]; then
    # “Nice” format: includes policy= prefix; header matches output
    echo -e "ASN\tNetwork\tpolicy"
    echo "$nets_json" | jq -r '
      .data
      | sort_by(.asn)
      | .[]
      | "\(.asn)\t\(.name)\tpolicy=\(.policy_general // "unknown")"
    '
  else
    # “Simple” format: raw policy value in third column
    echo -e "ASN\tNetwork\tpolicy_general"
    echo "$nets_json" | jq -r '
      .data
      | sort_by(.asn)
      | .[]
      | "\(.asn)\t\(.name)\t\(.policy_general // "unknown")"
    '
  fi
fi
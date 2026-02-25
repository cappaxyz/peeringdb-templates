# pdb-ix-participants

pdb-ix-participants is a small shell script that queries the PeeringDB REST API to produce a concise participant/attachment summary for a given Internet Exchange (IX), identified by IX ID.

Folder layout (as used here):

* peeringdb-templates/pdb-ix-scripts/pdb-ix-participants/pdb-ix-participants
* peeringdb-templates/pdb-ix-scripts/pdb-ix-participants/README.md

---

PURPOSE

Given an IX ID, the script aggregates data across all IXLANs belonging to that IX and reports:

* Peers: number of unique participating networks, expressed as unique ASNs (derived from unique net_id values observed in netixlan, resolved to net.asn)
* Peer ASNs: the list of participant ASNs
* Connections: total number of attachments/ports, defined as the total count of netixlan objects across the IX’s IXLAN(s)
* Total speed: sum of netixlan.speed (Mbps) across all netixlan rows (inventory/capacity indicator, not measured traffic)
* Open peers: count of networks whose policy_general is Open (self-declared in PeeringDB)
* IPv6-enabled peers (%): percentage of unique participating networks that have at least one netixlan record with a non-empty ipaddr6

---

DATA MODEL DEFINITIONS (AS IMPLEMENTED)

* Peers = unique networks present at the IX = unique net_id values across all netixlan rows for the IX (resolved to unique ASNs)
* Connections = attachments/ports = total netixlan row count across all IXLANs for the IX

---

REQUIREMENTS

* bash (or compatible shell)
* curl
* jq
* A PeeringDB API key with access to the relevant endpoints

---

AUTHENTICATION

The script expects your API key in an environment variable:

export PEERINGDB_API_KEY="YOUR_KEY_HERE"

It uses the HTTP header:

Authorization: Api-Key $PEERINGDB_API_KEY

Important note about root / sudo:

* If you run the script as root (or via sudo), your normal user environment variables may not be available.
  Options:

  * Run it as your normal user (recommended), or
  * Export PEERINGDB_API_KEY in the root shell, or
  * Use sudo -E to preserve environment variables (if allowed by sudoers).

---

INSTALLATION

From the pdb-ix-participants directory:

chmod +x ./pdb-ix-participants

Optional (confirm it is executable):

ls -l ./pdb-ix-participants

---

USAGE

Placeholders:

* Replace <IX_ID> with the IX ID you want to report on (example: 35).

1. Ensure your API key is set (in the same shell you will run the script from):

export PEERINGDB_API_KEY="YOUR_KEY_HERE"

2. Run the script (summary only):

IX_ID=<IX_ID> ./pdb-ix-participants

Example:

IX_ID=35 ./pdb-ix-participants

3. Show per-network details (adds an ASN/name/policy table):

IX_ID=<IX_ID> SHOW_DETAILS=1 ./pdb-ix-participants

Example:

IX_ID=35 SHOW_DETAILS=1 ./pdb-ix-participants

4. “Nice” details format (adds policy= prefix in the third column):

IX_ID=<IX_ID> SHOW_DETAILS=1 DETAILS_STYLE=nice ./pdb-ix-participants

Example:

IX_ID=35 SHOW_DETAILS=1 DETAILS_STYLE=nice ./pdb-ix-participants

5. Force “simple” details format explicitly (raw policy value in third column):

IX_ID=<IX_ID> SHOW_DETAILS=1 DETAILS_STYLE=simple ./pdb-ix-participants

Example:

IX_ID=35 SHOW_DETAILS=1 DETAILS_STYLE=simple ./pdb-ix-participants

Running as root (one-off, without exporting):

* You can set the API key just for the command:

  PEERINGDB_API_KEY="YOUR_KEY_HERE" IX_ID=<IX_ID> ./pdb-ix-participants

---

OUTPUT

Typical output shape:

IX ID: <IX_ID>
Peers (unique networks / ASNs): 123
Connections (netixlan rows): 190
Total speed (sum of netixlan.speed, Mbps): 1240000
Open peers (policy_general=Open): 78
IPv6-enabled peers (%): 91.0569
ASNs:
13335, 15169, 16509, ...

If SHOW_DETAILS=1 is set, a table is appended.

Simple details (DETAILS_STYLE=simple):

ASN    Network    policy_general
13335  Cloudflare Open
15169  Google     Selective
...

Nice details (DETAILS_STYLE=nice):

ASN    Network    policy
13335  Cloudflare policy=Open
15169  Google     policy=Selective
...

---

NOTES AND CAVEATS

* Connections are not physical cross-connects.
  PeeringDB does not model physical cabling; netixlan indicates logical presence (attachments/ports/VLAN presence) on an IXLAN.

* Total speed is “declared port speed”.
  netixlan.speed is an inventory/capacity attribute and may be missing, zero, stale, or represent logical rather than physical capacity. It is not throughput.

* “Open peers” is self-declared policy.
  policy_general=Open is the network’s stated peering policy and does not guarantee route-server presence or unconditional peering.

* Multiple IXLANs are aggregated.
  The script queries ixlan?ix_id=<IX_ID> and aggregates netixlan across all returned ixlan.id values.

---

TROUBLESHOOTING

API key not set:

* If you see: "ERROR: PEERINGDB_API_KEY is not set"
  Ensure you have exported it in the same shell session:
  export PEERINGDB_API_KEY="YOUR_KEY_HERE"
  If running as root, export it in the root shell as well, or run as your normal user.

Empty results:

* Confirm the IX exists: GET /api/ix?id=<IX_ID>
* Confirm it has at least one IXLAN: GET /api/ixlan?ix_id=<IX_ID>

401/403 errors:

* Ensure your API key is valid and has access.
* Ensure you are passing the header exactly as shown:
  -H "Authorization: Api-Key $PEERINGDB_API_KEY"

jq errors:

* Confirm jq is installed: jq --version

---

LICENCE

Template/internal use. Add a licence header if you intend to publish it.

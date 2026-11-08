# pdb-fac-empty

pdb-fac-empty is a small shell script that queries the PeeringDB REST API and lists "empty" facilities: facility (fac) objects with no networks, no internet exchanges and no carriers recorded against them.

Folder layout (as used here):

* peeringdb-templates/pdb-fac-scripts/pdb-fac-empty/pdb-fac-empty.sh
* peeringdb-templates/pdb-fac-scripts/pdb-fac-empty/README.md

---

PURPOSE

Find facility records that nothing references, for example to:

* Spot stale, duplicate or abandoned facility records worth reporting to PeeringDB or the facility owner
* Check your own organisation's facilities for records that need networks, exchanges or carriers attached
* Get a quick view of under-populated facilities in a given country

---

DATA MODEL DEFINITIONS (AS IMPLEMENTED)

* Facility = a PeeringDB fac object (status ok; PeeringDB only returns active objects by default)
* Empty (default) = net_count, ix_count and carrier_count are all 0
* net_count = networks with a netfac record at the facility
* ix_count = exchanges with an ixfac record at the facility
* carrier_count = carriers with an approved carrierfac record at the facility

The definition can be narrowed with EMPTY_OF (see USAGE). For example, EMPTY_OF=net lists facilities with no networks, regardless of exchanges or carriers.

---

REQUIREMENTS

* bash (or compatible shell)
* curl
* jq
* A PeeringDB API key

On Ubuntu:

sudo apt install curl jq

---

AUTHENTICATION

The script expects your API key in an environment variable:

export PEERINGDB_API_KEY="YOUR_KEY_HERE"

It uses the HTTP header:

Authorization: Api-Key $PEERINGDB_API_KEY

Never commit your API key to this repository.

---

INSTALLATION

From the pdb-fac-empty directory:

chmod +x ./pdb-fac-empty.sh

---

USAGE

Settings are passed as environment variables, in the same style as pdb-ix-participants:

* COUNTRY   Two-letter country code, e.g. AU. Blank (default) checks every country.
* EMPTY_OF  Which counters must be zero, comma-separated: net, ix, carrier. Default: net,ix,carrier
* FORMAT    table (default), csv or json

1. All empty facilities, worldwide:

./pdb-fac-empty.sh

2. Empty facilities in one country:

COUNTRY=AU ./pdb-fac-empty.sh

3. Facilities in a country with no networks (ignoring exchanges and carriers):

COUNTRY=AU EMPTY_OF=net ./pdb-fac-empty.sh

4. Save as CSV (the summary goes to the terminal, the data to the file):

COUNTRY=AU FORMAT=csv ./pdb-fac-empty.sh > au-empty-facilities.csv

5. JSON, for feeding into other tools:

COUNTRY=AU FORMAT=json ./pdb-fac-empty.sh | jq '.[].name'

---

OUTPUT

Table output (default):

Country: AU
Facilities checked: 412
Empty facilities (carrier_count,ix_count,net_count all 0): 37

ID     CC  City       Facility               Organisation       URL
12345  AU  Melbourne  Example DC MEL9        Example Pty Ltd    https://www.peeringdb.com/fac/12345
...

CSV and JSON outputs include: id, name, org_id, org_name, city, state, country, net_count, ix_count, carrier_count, updated, url

---

NOTES AND CAVEATS

* Empty in PeeringDB does not mean empty in reality.
  It means no network, exchange or carrier has recorded presence there. A busy building can look empty if its tenants have not updated PeeringDB.

* Counters are PeeringDB's own summary fields.
  net_count, ix_count and carrier_count are maintained by PeeringDB and can briefly lag behind recent changes.

* Carrier presence needs facility approval.
  A carrier that has requested presence but has not been approved by the facility does not count.

* One API request per run.
  The script fetches all facilities (optionally filtered by country) in a single request and filters locally with jq. Do not run it in a tight loop; PeeringDB rate-limits repeated large queries.

* Records with a missing counter are not treated as empty.
  If PeeringDB ever stops returning one of the counters, the script stops with an error rather than reporting every facility as empty.

---

TROUBLESHOOTING

API key not set:

* If you see: "ERROR: PEERINGDB_API_KEY is not set"
  Export it in the same shell session, or load it from your ~/.bashrc.

HTTP 401/403:

* The key is invalid or revoked. Create a new one in your PeeringDB profile.

HTTP 429:

* You have hit PeeringDB's rate limit. Wait a few minutes before retrying.

Table columns not aligned:

* The column command is missing. Install it with: sudo apt install bsdextrautils
  (the script falls back to tab-separated output without it)

---

LICENCE

Template/internal use. Add a licence header if you intend to publish it.


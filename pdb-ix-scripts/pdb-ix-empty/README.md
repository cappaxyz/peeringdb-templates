# pdb-ix-empty

pdb-ix-empty is a small shell script that queries the PeeringDB REST API and lists "empty" internet exchanges: IX objects with no networks present.

Folder layout (as used here):

* peeringdb-templates/pdb-ix-scripts/pdb-ix-empty/pdb-ix-empty.sh
* peeringdb-templates/pdb-ix-scripts/pdb-ix-empty/README.md

---

PURPOSE

Find exchange records with no participating networks, for example to:

* Spot defunct, duplicate or never-launched exchanges still listed in PeeringDB
* Find exchanges whose participants have not added their netixlan records
* Get a quick view of exchanges in a given country that show no members

---

DATA MODEL DEFINITIONS (AS IMPLEMENTED)

* IXP = a PeeringDB ix object (status ok; PeeringDB only returns active objects by default)
* Empty (default) = net_count is 0
* net_count = networks with a netixlan record (a connection) on any of the exchange's IXLANs
* fac_count = facilities where the exchange is present (ixfac records)
* ixf_net_count = networks listed in the exchange's IX-F member export, if it publishes one

The definition can be widened with EMPTY_OF (see USAGE). EMPTY_OF=net,fac lists exchanges with no networks and no facilities.

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

From the pdb-ix-empty directory:

chmod +x ./pdb-ix-empty.sh

---

USAGE

Settings are passed as environment variables, in the same style as pdb-ix-participants:

* COUNTRY   Two-letter country code, e.g. AU. Blank (default) checks every country.
* EMPTY_OF  Which counters must be zero, comma-separated: net, fac. Default: net
* FORMAT    table (default), csv or json

1. All exchanges with no networks, worldwide:

./pdb-ix-empty.sh

2. Exchanges with no networks in one country:

COUNTRY=AU ./pdb-ix-empty.sh

3. Exchanges with no networks and no facilities:

EMPTY_OF=net,fac ./pdb-ix-empty.sh

4. Save as CSV (the summary goes to the terminal, the data to the file):

FORMAT=csv ./pdb-ix-empty.sh > empty-ixps.csv

5. JSON, for feeding into other tools:

COUNTRY=AU FORMAT=json ./pdb-ix-empty.sh | jq '.[].name'

---

OUTPUT

Table output (default):

Country: AU
IXPs checked: 30
Empty IXPs (net_count all 0): 4
  of which list members in their IX-F export (ixf_net_count > 0): 1

ID    CC  City       IXP           Facs  IX-F nets  URL
1234  AU  Melbourne  Example-IX    2     14         https://www.peeringdb.com/ix/1234
...

The "of which" line only appears when at least one empty exchange has members in its IX-F export.

CSV and JSON outputs include: id, name, org_id, org_name, city, country, region, net_count, fac_count, ixf_net_count, updated, url

---

NOTES AND CAVEATS

* Empty in PeeringDB does not mean empty in reality.
  It means no network has added a netixlan record for the exchange. Members that do not maintain PeeringDB will not appear.

* Check the IX-F nets column before calling an exchange dead.
  An exchange with net_count 0 but ixf_net_count above 0 publishes a member list, so it has members; they have simply not recorded their connections in PeeringDB. Those exchanges are data-quality issues, not defunct exchanges.

* Counters are PeeringDB's own summary fields.
  net_count, fac_count and ixf_net_count are maintained by PeeringDB and can briefly lag behind recent changes. ixf_net_count is blank when PeeringDB returns no value.

* One API request per run.
  The script fetches all exchanges (optionally filtered by country) in a single request and filters locally with jq. Do not run it in a tight loop; PeeringDB rate-limits repeated large queries.

* Records with a missing counter are not treated as empty.
  If PeeringDB ever stops returning a counter used in EMPTY_OF, the script stops with an error rather than reporting every exchange as empty.

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

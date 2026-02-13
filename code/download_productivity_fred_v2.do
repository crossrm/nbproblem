********************************************************************************
* Download BLS Nonfarm Business Labor Productivity from FRED
* Series: OPHNFB (Output Per Hour, Nonfarm Business, Index 2017=100)
* Frequency: Quarterly, 1947Q1–present
*
* NOTE: freduse is broken in recent Stata versions due to a FRED URL redirect.
*       This script calls the FRED API directly via import delimited.
********************************************************************************

clear all
set more off

*--- 1. Set your FRED API key here ---*
* Get a free key at: https://fred.stlouisfed.org/docs/api/api_key.html
local api_key "fd6378d0053e7805a3faacbfa28e24ee"

*--- 2. Build the API URL and import ---*
* The FRED API returns JSON by default; we request a simple text format
* by pulling the series observations endpoint with file_type=json.
* However, the cleanest approach in Stata is to grab the downloadable
* CSV that FRED serves for any series page.

* Method A: Direct CSV from FRED website (no API key needed)
import delimited "https://fred.stlouisfed.org/graph/fredgraph.csv?bgcolor=%23e1e9f0&chart_type=line&drp=0&fo=open%20sans&graph_bgcolor=%23ffffff&id=OPHNFB&scale=left&cosd=1947-01-01&coed=2099-12-31&line_color=%234572a7&link_values=false&lw=2&ost=-99999&oet=99999&mma=0&fml=a&fq=Quarterly&fam=avg&fgst=lin&fgsnd=2020-02-01&line_index=1&transformation=lin&vintage_date=&revision_date=&nd=1947-01-01", clear

* If Method A fails, try Method B (requires API key):
* local url "https://api.stlouisfed.org/fred/series/observations?series_id=OPHNFB&api_key=`api_key'&file_type=json"
* See notes at the bottom of this file for a JSON-parsing approach.

** Save in case implementation can't download
cd_nb_source
save productivity_fred_source, replace
use productivity_fred_source, clear

*--- 3. Clean the imported data ---*
* The CSV from FRED has two columns: DATE and OPHNFB
* Rename for clarity
capture rename observation_date DATE
capture rename ophnfb OPHNFB
capture rename v1 DATE
capture rename v2 OPHNFB

* Convert string date to Stata date
gen daten = date(DATE, "YMD")
format daten %td

* Convert productivity to numeric (FRED sometimes has "." for missing)
capture destring OPHNFB, replace force
rename OPHNFB productivity_index
label variable productivity_index "Labor Productivity Index (2017=100)"

* Drop any header rows or missing observations
drop if missing(daten) | missing(productivity_index)
drop DATE

*--- 4. Generate quarterly date variable ---*
gen qdate = qofd(daten)
format qdate %tq

gen year = year(daten)
gen quarter = quarter(daten)

order qdate year quarter daten productivity_index
sort qdate

*--- 5. Set as time series and compute growth rates ---*
tsset qdate

* Quarter-on-quarter annualised growth (percent)
gen g_prod_qq = ((productivity_index / L.productivity_index)^4 - 1) * 100
label variable g_prod_qq "Productivity growth (q/q, annualised %)"

* Year-on-year growth
gen g_prod_yy = ((productivity_index / L4.productivity_index) - 1) * 100
label variable g_prod_yy "Productivity growth (y/y %)"

* Log level
gen ln_prod = ln(productivity_index)
label variable ln_prod "Log productivity index"

*--- 6. Summary ---*
summarize productivity_index g_prod_qq g_prod_yy, detail

list qdate productivity_index in 1/8, clean
list qdate productivity_index in -4/l, clean

*--- 7. Quick plot ---*
tsline productivity_index, ///
    title("U.S. Nonfarm Business Labor Productivity") ///
    subtitle("Output per hour, Index 2017=100") ///
    ytitle("Index") xtitle("") ///
    note("Source: BLS via FRED (series OPHNFB)") ///
    scheme(s2color)

	
	di as txt _n "Done! Dataset saved as productivity_fred.dta"
	di as txt "Observations: " _N
	di as txt "Date range: " %tq qdate[1] " to " %tq qdate[_N]

*--- 8. Save ---*
keep year quarter productivity_index
cd_nb_stage
save "productivity_fred.dta", replace
use productivity_fred, clear


********************************************************************************
* DOWNLOADING ADDITIONAL SERIES
********************************************************************************
* To download other series, repeat the import with a different series ID.
* Just swap OPHNFB in the URL for the series you want. For example:
*
*   OPHPBS       = Private business sector output per hour
*   PRS85006092  = Nonfarm business unit labor costs (index)
*   PRS85006112  = Nonfarm business real compensation per hour
*   MFPNFBS      = Multifactor productivity (annual, 1987=100)
*
* Example:
*   import delimited "https://fred.stlouisfed.org/graph/fredgraph.csv?id=OPHPBS&cosd=1947-01-01&coed=2099-12-31&fq=Quarterly&transformation=lin", clear
*
* For multiple series in one dataset, download each into a tempfile,
* then merge on qdate.

********************************************************************************
* ALTERNATIVE: FRED API WITH JSON (if the CSV method stops working)
********************************************************************************
* Stata 17+ can parse JSON with jsonio (from SSC) or manually.
* Here's a sketch using the API:
*
*   local api_key "YOUR_API_KEY_HERE"
*   local url "https://api.stlouisfed.org/fred/series/observations?series_id=OPHNFB&api_key=`api_key'&file_type=json&observation_start=1947-01-01"
*   
*   * Install jsonio if needed: ssc install jsonio
*   jsonio kv, file("`url'") elem("observations")
*   
*   * Then parse the key-value pairs into a usable dataset.
*   * This is more involved but doesn't depend on the CSV endpoint.

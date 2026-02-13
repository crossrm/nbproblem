********************************************************************************
* Download BLS Nonfarm Business Labor Productivity from FRED
* Series: OPHNFB (Output Per Hour, Nonfarm Business, Index 2017=100)
* Frequency: Quarterly, 1947Q1–present
********************************************************************************

clear all
set more off

*--- 1. Install freduse if needed (only run once) ---*
* ssc install freduse, replace

*--- 2. Set your FRED API key ---*
* You need a free API key from https://fred.stlouisfed.org/docs/api/api_key.html
* Uncomment and insert your key below:
 set fredkey "fd6378d0053e7805a3faacbfa28e24ee", permanently

*--- 3. Download the series ---*
freduse OPHNFB, clear

*--- 4. Basic cleaning ---*
* Rename for clarity
rename OPHNFB productivity_index
label variable productivity_index "Labor Productivity Index (2017=100)"
label variable daten "Date"

* Generate quarterly date variable
gen qdate = qofd(daten)
format qdate %tq

* Generate year and quarter
gen year = year(daten)
gen quarter = quarter(daten)

* Sort
order qdate year quarter daten productivity_index
sort qdate

*--- 5. Compute growth rates ---*
tsset qdate

* Quarter-on-quarter annualised growth (percent, annualised)
gen g_prod_qq = ((productivity_index / L.productivity_index)^4 - 1) * 100
label variable g_prod_qq "Productivity growth (q/q, annualised %)"

* Year-on-year growth
gen g_prod_yy = ((productivity_index / L4.productivity_index) - 1) * 100
label variable g_prod_yy "Productivity growth (y/y %)"

* Log level (useful for regressions)
gen ln_prod = ln(productivity_index)
label variable ln_prod "Log productivity index"

*--- 6. Quick summary ---*
summarize productivity_index g_prod_qq g_prod_yy, detail

*--- 7. Quick plot ---*
tsline productivity_index, ///
    title("U.S. Nonfarm Business Labor Productivity") ///
    subtitle("Output per hour, Index 2017=100") ///
    ytitle("Index") xtitle("") ///
    note("Source: BLS via FRED (series OPHNFB)") ///
    scheme(s2color)

*--- 8. Save ---*
save "productivity_fred.dta", replace

*--- Optional: also download related series ---*
* Uncomment below to pull additional productivity series in one call:
*
* freduse OPHNFB OPHPBS PRS85006092 PRS85006112, clear
*
* OPHNFB  = Nonfarm business output per hour (headline)
* OPHPBS  = Private business sector output per hour
* PRS85006092 = Nonfarm business unit labor costs
* PRS85006112 = Nonfarm business real compensation per hour

di as txt "Done! Dataset saved as productivity_fred.dta"
di as txt "Observations: " _N
di as txt "Date range: " %tq qdate[1] " to " %tq qdate[_N]

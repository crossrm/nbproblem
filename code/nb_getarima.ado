********************************************************
** nb_getarima
** from: https://www.statalist.org/forums/forum/general-stata-discussion/general/1724684-command-arimasoc-is-unrecognized
*********************************************************
capture program 	drop 	nb_getarima
program 			define 	nb_getarima

	
	** Read inputs
	local depvar 				= "`1'"
	local ar_up 				= "`2'"
	local ma_up 				= "`3'"
	local first_year 			= "`4'"
				
	** List inputs
	while "`1'" != "" {
		
		di `"`1'"'
		mac shift

	} //End while
	di "Done with list."

	global F %6.2f
	global G %5.0f

		di "Model" _col(15) "LL" _col(25) "df" _col(35) "AIC" _col(45) $F "BIC"
		
	forv ar = 0/`ar_up' {
		forv ma = 0/`ma_up' {
			qui arima `depvar' if `first_year' >= 1947, arima(`ar',0,`ma')
			qui estat ic
			di "ARMA(`ar',`ma')" $F _col(15) r(S)[1,3] _col(25) $G r(S)[1,4] _col(35) $F r(S)[1,5] _col(45) $F r(S)[1,6]
		}    
	}

end

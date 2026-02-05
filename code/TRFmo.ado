***********************************************************
***********************************************************
** N-body Total Return Forecast (TRF)
** Written: 
**		robin m cross, 1.19.26

** Updated: 

***********************************************************
***********************************************************
capture program 	drop 	TRFmo
program 			define 	TRFmo, rclass

	** Read inputs
	local targetvar 			= "`1'"
	local months_future		 	= "`2'"		
	local months_past			= "`3'"
	local cpi_year				= "`4'"
	local cpi_month				= "`5'"
	local min_n					= "`6'"
	local seed					= "`7'"
	//local smoothing				= "`8'"
			
		********************************
		** List inputs
		********************************
		while "`1'" != "" {
			
			di `"`1'"'
			mac shift
			
		} //End while
		di "Done with list."
				
	********************************
	** OOS
	********************************
	set seed	`seed'
	gen randsample			= runiform()
	sort randsample
	gen ob					= _n
	qui sum ob
	local holdout			= 0.50
	local upper				= ceil(r(max) * `holdout')
	gen incl 				= (ob <= `upper')  //Jolt > 4
		di "Upper is `upper', holdout is `holdout'."
		* sum ob randsample incl if n >= `min_n'
		tab incl //if year >= 1900
	replace incl			= (incl==1 ) //& year >= 1900)
	
	** Clean up
	drop randsample ob
						
	********************************
	** Reproduce Target (stock/bond/house) CAPE - Stock 28.99 R2
	********************************
	
	** Time locals - convert to months
	//local months_future = `months_future'*12
	//local months_past = `months_past'*12
	
	** Prep
	order n year month p_`targetvar' dividend earnings cpi r_bond
		*sum n year month p_`targetvar' dividend earnings cpi r_bond
								
	** Gen real total return price 
	tsset n
	quietly gen trtnp_`targetvar'			= p_`targetvar'
	
	* Shiller (cumulative) Total return price equation - see ie_data.xls column J (before inflation adjustment)
	replace trtnp_`targetvar'				= L.trtnp_`targetvar' * (p_`targetvar' + (dividend/12))/L.p_`targetvar' if n>1
	
	* Real price adjustment - will use Dec 2024, ie_data uses 2/25
	qui sum cpi if year==`cpi_year' & month==`cpi_month'
	local curr_cpi				= r(mean)
		di "Local curr_cpi: `curr_cpi'."
	quietly gen trtnp_`targetvar'r			= trtnp_`targetvar' * `curr_cpi' / cpi
	quietly gen dividendr					= dividend * `curr_cpi' / cpi
	quietly gen earningsr					= earnings * `curr_cpi' / cpi
	quietly gen p_`targetvar'r				= p_`targetvar' * `curr_cpi' / cpi
		*di "Start CAPE: `targetvar'."
	
	** Cyclically adjusted CAPE - past earnings
	* Current earnings if past months are zero
	if `months_past'== 0 {
	
		** If not smoothing -- Inflation rate over most recent period
		quietly gen ma_earningsr 			= earningsr
	
	} //end if
	else {
		
		** If not smoothing -- Inflation rate over earnings smoothing period
		quietly tssmooth ma ma_earningsr 	= earningsr, window(`months_past')
	
	} //end if
	di "Done with smoothed earnings."
	quietly replace ma_earningsr			= . if n<=`months_past'
	quietly gen ca_cape						= p_`targetvar'r / ma_earningsr
		*di "Start Excess: `months_past'."
	
	** Excess cape - see Shiller ie_data "Q" - past inflation
	* Most recent if past months are zero
	if `months_past'== 0 {
	
		** If not smoothing -- Inflation rate over most recent period
		quietly gen ex_cape						= 1/ca_cape - (r_bond/100 - ((cpi / L1.cpi)^(1/10)-1))
	
	} //end if
	else {
		
		** If smoothing -- Inflation rate over earnings smoothing period
		quietly gen ex_cape						= 1/ca_cape - (r_bond/100 - ((cpi / L`months_past'.cpi)^(1/10)-1))
		
	} //end if
	di "Done with ex_cape."
	
	** Real total bond returns - no large lags - 1200 is from the 10-year bond (12 mo x 10 yrs )
	quietly gen mo_bond						= (r_bond/F.r_bond + r_bond/1200 + ((1+F.r_bond/1200)^(-119))*(1-r_bond/F.r_bond))
	quietly gen trtnp_bondr					= 1
	quietly replace trtnp_bondr				= L.trtnp_bondr * L.mo_bond * L.cpi / cpi if n>1
		
	** Future target and bond returns - future years
	quietly gen rtns_`targetvar'r			= (F`months_future'.trtnp_`targetvar'r / trtnp_`targetvar'r)^(1/10)-1
	quietly gen rtns_bondr					= (F`months_future'.trtnp_bondr / trtnp_bondr)^(1/10)-1
	quietly gen ex_return					= rtns_`targetvar'r - rtns_bondr
	
		order n year month p_`targetvar'* dividend* earnings* cpi r_bond trtnp_* mo_* ma_* ca_*  ex_* rtns*
		
	** Temp save
	cd_nb_stage
	save temp_trf, replace
	
	** Confirm reg (R-squared 28.99 1380 obs)
	//reg ex_return ex_cape 
		*sum ex_return ex_cape incl if (incl)
	** Sa
	keep if n >= `min_n'
	reg ex_return ex_cape if (incl)
	
	** Record beta
		*display _b[ex_cape]
	scalar beta 							= _b[ex_cape]
	
		scalar list beta 
			
	** Fit
	fit_nb ex_return
	
	** Reload
	cd_nb_stage
	use temp_trf, clear
	
	** Clean up
	drop incl trtnp_* dividendr earningsr ma_* ca_* ex_* mo_* rtns_* p_`targetvar'r	
	
	** Return values (rclass program)
	return scalar r2_0 		= r2_0
	return scalar r2_1 		= r2_1
	return scalar beta		= beta
	
end
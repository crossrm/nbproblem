***********************************************************
***********************************************************
** N-body Total Return Forecast (TRF)
** Written: 
**		robin m cross, 1.19.26

** Updated: 

***********************************************************
***********************************************************
capture program 	drop 	TRF
program 			define 	TRF

	** Read inputs
	local targetvar 			= "`1'"
	local years_future		 	= "`2'"		
	local years_past			= "`3'"
	local cpi_year				= "`4'"
	local cpi_month				= "`5'"
	local min_n					= "`6'"
	local seed					= "`7'"
			
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
	local years_future = `years_future'*12
	local years_past = `years_past'*12
	
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
	quietly tssmooth ma ma_earningsr 		= earningsr, window(`years_past')
	quietly replace ma_earningsr			= . if n<=`years_past'
	quietly gen ca_cape						= p_`targetvar'r / ma_earningsr
		*di "Start Excess: `years_past'."
	
	** Excess cape - see Shiller ie_data "Q" - past inflation
	quietly gen ex_cape						= 1/ca_cape - (r_bond/100 - ((cpi / L`years_past'.cpi)^(1/`years_past')-1))
	
	** Real total bond returns - no large lags - 1200 is from the 10-year bond (12 mo x 10 yrs )
	quietly gen mo_bond						= (r_bond/F.r_bond + r_bond/1200 + ((1+F.r_bond/1200)^(-119))*(1-r_bond/F.r_bond))
	quietly gen trtnp_bondr					= 1
	quietly replace trtnp_bondr				= L.trtnp_bondr * L.mo_bond * L.cpi / cpi if n>1
		
	** Future target and bond returns - future years
	quietly gen rtns_`targetvar'r			= (F`years_future'.trtnp_`targetvar'r / trtnp_`targetvar'r)^(1/`years_future')-1
	quietly gen rtns_bondr					= (F`years_future'.trtnp_bondr / trtnp_bondr)^(1/`years_future')-1
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
	fit_nb ex_return
	
	** Reload
	cd_nb_stage
	use temp_trf, clear
	
	** Clean up
	drop incl trtnp_* dividendr earningsr ma_* ca_* ex_* mo_* rtns_* p_`targetvar'r	
	
end
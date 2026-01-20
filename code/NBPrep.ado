***********************************************************
***********************************************************
** N-body prep
** Written: 
**		robin m cross, 3.7.25

** Updated: 

***********************************************************
***********************************************************
capture program 	drop 	NBPrep
program 			define 	NBPrep

	***********************************************************
		** Load and prep 
		***********************************************************
		scalar load = 1 
		if load == 1 {
			
			****************
			** Economic stats
			****************
			scalar econ = 1
			if econ == 1 {
					
				*******************
				** CPI
				*******************
				scalar infl = 1
				if infl == 1 {
					
					** Prep cpi historical	
					cd_nb_source
					import excel "rent_cpi_gdp_pop_source3.12.25.xlsx", sheet("CPIHistAnnual") cellrange(A1:B226) firstrow clear
					
					** Clean and prep
					destring *, replace
					gen month								= 12
					rename cpi cpi_hist
					
					** Save for join
					cd_nb_stage
					save cpi_hist, replace
						
					** Prep cpi monthly
					cd_nb_source
					import excel "rent_cpi_gdp_pop_source3.12.25.xlsx", sheet("CPIMonthly") cellrange(B1:D1429) firstrow clear
					
					** Clean up
					renvars *, lower
					drop if period == "S01"
					drop if period == "S02"
					destring *, replace
					rename period month
					rename value cpi
					
					** Add historical annual
					cd_nb_stage
					joinby year month using cpi_hist, unmatched(both)
						tab _merge
						drop _merge
					
					** Fill missing years
					** Scale
					sort year month
					gen double ratio				= cpi_hist / cpi
					replace cpi 			= cpi_hist / 2.97 if cpi ==.	// 1913 ratio
					
					** Calc inflation
					sort year month
					gen obs 				= _n
					sort obs
					tsset obs
					gen double inflation_mo		= ( cpi - L12.cpi ) / L12.cpi
					gen double inflation_ann		= ( cpi - L1.cpi ) / L1.cpi
					gen double inflation 			= .
					replace inflation 		= inflation_ann if year <= 1912
					replace inflation 		= inflation_mo if inflation == .
					replace inflation 		= inflation * 100
					rename inflation r_price
					
					** Save
					keep year month cpi r_price
					cd_nb_stage
					save cpi_monthly, replace
						
				} //end if
				di "Done with cpi."
						
				*******************
				** Pop + Rent + GDP
				*******************
				scalar pop = 1
				if pop == 1 {
					
					** Prep pop monthly
					cd_nb_source
					import excel "rent_cpi_gdp_pop_source3.12.25.xlsx", sheet("POPmonthly1959") cellrange(B1:D794) firstrow clear
					rename POPTHM pop_monthly
					** Save for join
					cd_nb_stage
					save pop_monthly, replace
						
					** Prep rent monthly
					cd_nb_source
					import excel "rent_cpi_gdp_pop_source3.12.25.xlsx", sheet("rent_index") cellrange(B1:D1324) firstrow clear
					** Adjust for December 2024 SFR rental Rate (Yardi SFR December 2024)
					sum rent_index if year==2024 & month==12
					local MFI		= r(mean)
					replace rent_index 				= rent_index / `MFI' * 1742
					** Save for join
					cd_nb_stage
					save rent_index, replace
					use rent_index, clear
					
					** Prep gdp annual
					cd_nb_source
					import excel "rent_cpi_gdp_pop_source3.12.25.xlsx", sheet("GDPannual1947") cellrange(B1:C79) firstrow clear
					** Adjust for December 2024 multi-family rental Rate (Yardi MultiFamily December 2024)
					** Save for join
					cd_nb_stage
					save gdp_data, replace
						
				} //end if
				di "Done with pop, rent, and GDP."		
												
			} //end if
			di "Done with Econ stats data."
			
			****************
			** Jorda - returns on everything
			****************
			scalar jorda = 1
			if jorda == 1 {
					
				** Load main and save
				cd_nb_jorda
				use rore_public_main, clear

				** Keep
				keep if iso=="USA"
				order	year housing_rent_yd bond_rate
				keep 	year housing_rent_yd bond_rate
				rename housing_rent_yd r_house
				rename bond_rate r_bond
				
				** Save for join
				cd_nb_stage
				save jorda_main, replace
				use jorda_main, clear
							
				****************************
				** Load supplement and join
				****************************
				scalar sup = 1
				if sup == 1 {
						
					** Load jorda supplement
					cd_nb_jorda
					use rore_public_supplement, clear

					** Keep
					keep if iso=="USA"
					keep year pop cpi gdp
					
					** Join
					cd_nb_stage
					joinby year using jorda_main, unmatched(master)
						tabulate _merge
						drop _merge
						
					** Rename
					//rename housing_rent_yd r_house
					//rename bond_rate r_bond
					//rename inflation r_infl
					
					** Gen population growth rate
					//tsset year
					//gen double r_pop		= (pop - l.pop) / l.pop
				
					** Inflation adjust
					//gen double rr_bond		= r_bond - r_infl
					
					** Drop 
					//drop country
					
				} //end if
				di "Done with sup data."
				
				** Save for monthly-fill-in join
				cd_nb_stage
				save jorda_monthly_join, replace
							
				** Save for annual-only join
				keep year r_house 
				gen month				= 12
				order year month r_house
				cd_nb_stage
				save jorda_annual_join, replace
							
			} //end if
			di "Done with Jorda data."
			
			***************
			** Kuvshinov - 1899-2016 - equity market cap
			** Siblis 2017-2024
			***************
			scalar kuv = 1
			if kuv == 1 {
				
				** Load
				cd_nb_source
				use Kuvshinov2022_BBdatasetR1, clear
				
				** Select
				keep if iso == "USA"
				keep year mcap
				keep if mcap!=.
				
				** Save
				cd_nb_stage
				save Kuv_data, replace
			
				** Open Sib data
				cd_nb_source
				import excel "MarketCap_WB1975_Sib2016.xlsx", sheet("Siblisresearch") firstrow clear
				keep Year mcap
				renvars *, lower
				order year mcap
				rename mcap mcapsib
				
				** Join and merge
				cd_nb_stage
				joinby year using Kuv_data, unmatched(both)
					tab _merge
					drop _merge

				** Merge
				replace mcap 				= mcap * 1000 //convert to millions
				replace mcapsib				= mcap if mcap!=.
				drop mcap
				rename mcapsib mcap
				replace mcap 				= mcap / 1000 //convert back to billions
				
				** Save
				cd_nb_stage
				save equity_cap_ann, replace
			
			} //end if
			di "Done with Kuvshinov data."
			
			***************
			** Treasury - debt outstanding 
			***************
			scalar treas = 1
			if treas == 1 {
				
				** Open Treas outstanding data
				cd_nb_source
				import excel "TreasuryDebt", sheet("Debt") firstrow clear
				keep year DebtOut
				renvars *, lower
				gen month					= 9
				order year month debtout
				destring *, replace
				replace debtout				= debtout / 1000000		//report in millions
								
				** Save
				cd_nb_stage
				save debt_out_ann, replace
				use debt_out_ann, clear
				
				** Save first run join
				replace month 				= 12
				** Save
				cd_nb_stage
				save debt_out, replace
				use debt_out, clear
						
				** Treasuries impute
				** Gen full history monthly panel 
				** Only enable this on the 2nd run of the program - depends on a file saved below
				//scalar treasmo = 1 // Now set by calling file
				if treasmo == 1 {
						
					** Load monthly
					cd_nb_source
					import excel "MonthlyTreasuryDebt", sheet(monthly) firstrow clear
					
					** Clean for join
					keep if SecurityTypeDescription == "Total Public Debt Outstanding"
					renvars *, lower
					rename totalpublicdebtoutstandingi mdebtout
					keep recorddate mdebtout year month
					
					** Save 
					cd_nb_stage
					save debt_out_mo, replace
					use debt_out_mo, clear
				
					** Months
					clear
					set obs 12
					gen month 								= _n
					gen join_one							= 1
					cd_nb_stage
					save join_months, replace
					** Years
					clear
					local span 	= 2025 - 1790 + 1
					set obs `span'
					gen year			=  _n + 1790 - 1
					duplicates drop
					gen join_one							= 1
					cd_nb_stage
					joinby join_one using join_months, unmatched(master)
						tab _merge
						drop _merge
					drop join_one
					order year month
					sort year month
					
					** Save monthly panel
					cd_nb_stage
					save monthly_panel, replace
					use monthly_panel, clear
									
					** Join annual
					cd_nb_stage
					joinby year month using debt_out_ann, unmatched(both)
						tabulate _merge
						drop _merge
					
					** Join monthly
					cd_nb_stage
					joinby year month using debt_out_mo, unmatched(both)
						tabulate _merge
						drop _merge
					
					** Look
					scalar look = 0
					if look == 1 {
						
						sort year
						egen double avg					= mean(mdebtout), by(year)
						replace avg					= round(avg)
						gsort -year -month
						gen double diffmoavg			= debtout - avg
						gen double diff_dec			= debtout - mdebtout
						sum diff* if debtout ~= .
						drop diff* avg
						
					} //end if
					di "Done with look treas."
					
					** Save intermediate
					cd_nb_stage
					save treas_progress, replace	
					
					************************************
					** Covariates to impute missing months
					************************************
					** Import control
					cd_nb_source
					import excel "PartyControl.xlsx", sheet("control") cellrange(A1:D170) firstrow clear
					renvars *, lower
					** Save for join
					cd_nb_stage
					save control, replace
					
					** Import corporate rates
					cd_nb_source
					import excel "AAA.xlsx", sheet("Monthly") cellrange(A1:F1280) firstrow clear
					renvars *, lower
					keep aaa-day
					** Save for join
					cd_nb_stage
					save corporates, replace
					
					** Import conflicts
					cd_nb_source
					import excel "conflicts.xlsx", sheet("conflicts") cellrange(A1:E2014) firstrow clear
					renvars *, lower
					keep year-conflicts
					** Save for join
					cd_nb_stage
					save conflicts, replace
					
					************************************
					** Impute missing months - treasury
					************************************
					** Save intermediate
					cd_nb_stage
					use treas_progress, clear
									
					gsort -year -month
					drop recorddate
					
					** Gen september ending debt covariate
					gen fiscalyear								= year
					replace fiscalyear							= fiscalyear - 1 if month < 10
					gen double double debout_zero				= debtout * 1000				// multiply to preserve accuracy of egen sum function below
					replace debout_zero							= 0 if debtout ==.
					sort fiscalyear year month
					by fiscalyear: egen double ending_debt		= sum(debout_zero)
					replace ending_debt							= ending_debt / 1000			// divide to return to correct units 
					drop debout_zero
					** Gen starting debt covariate
					sort fiscalyear year month
					by fiscalyear: gen fiscalmonth				= _n
					** Correct first year
					replace fiscalmonth							= fiscalmonth + 3 if fiscalyear == 1789
					sort fiscalyear fiscalmonth
					gen obs										= _n
					sort obs
					tsset obs
					gen double starting_debt					= L12.ending_debt
					** Correct 2nd year
					replace starting_debt						= L3.ending_debt if fiscalyear == 1790 & fiscalmonth < 4
					** Growth covariates
					gen double debt_growth						= ending_debt - starting_debt
					gen double debt_growth_mo					= debt_growth / 12
					sort fiscalyear
					by fiscalyear: gen double debt_cumul		= sum(debt_growth_mo) 
					gen double debt_linear						= starting_debt + debt_cumul
					
					** Clean up
					drop if starting_debt == 0 
					drop if starting_debt == . 
					drop if mdebtout == . & year > 2020
									
					** Reg
					reg mdebtout starting_debt ending_debt debt_linear i.fiscalmonth if ending_debt > 0 & fiscalmonth ~= 12
				
					** Monthly Change (dep var)
					sort obs
					tsset obs
					gen double change							= mdebtout - L.mdebtout 
						*scatter change obs if change ~=.
					gen double changep							= change / starting_debt
					gen double end_diff							= ending_debt - debt_linear
					
						sum if fiscalyear == 2002
				
					** Approximations
					set seed	1015115							// 101 1011 1015 10151 101511 1015112(55 test) 1015115(55) / 1014115(55) incl Dec
					gen randsample			= runiform()
					sort randsample
					gen ob					= _n
					sum ob
					local holdout			= 0.55
					local upper				= ceil(r(max) * `holdout')
					gen incl 				= (ob <= `upper')
						di "Upper is `upper', holdout is `holdout'."
						sum ob randsample incl if mdebtout ~= .  & ending_debt > 0 //& fiscalmonth ~= 12
						tab incl if mdebtout ~= .  & ending_debt > 0 //& fiscalmonth ~= 12
					replace incl			= (incl==1 & mdebtout ~= . & ending_debt > 0 ) //& fiscalmonth ~= 12)
					drop ob
					
						** Reg
						reg change 	starting_debt ending_debt debt_linear i.fiscalmonth c.obs##c.obs if (incl) & ending_debt > 0 //& fiscalmonth ~= 12
						fit_nb change 
						reg changep starting_debt debt_linear  if (incl) & ending_debt > 0 //& fiscalmonth ~= 12
						fit_nb changep 
					
					** More covars
					** Corporates
					cd_nb_stage
					joinby year month using corporates, unmatched(master)
						tab _merge
						drop _merge
					drop day
					** Conflicts
					cd_nb_stage
					joinby year month using conflicts, unmatched(master)
						tab _merge
						drop _merge
					drop day
					replace conflicts				= (conflicts>0)
					** Control
					cd_nb_stage
					joinby year using control, unmatched(master)
						tab _merge
						drop _merge
					** CPI GDP Pop - from file saved below
					cd_nb_stage
					joinby year month using treas_covariates, unmatched(master)
						tab _merge
						drop _merge
					
						** Look
						sum change* starting_debt ending_debt debt_linear i.fiscalmonth c.obs##c.obs aaa baa conflicts house* senat* presid* cpi r_price* pop gdp if (incl) & ending_debt > 0 & fiscalmonth ~= 12
						order year month change* starting_debt ending_debt debt_linear obs aaa baa conflicts house* senat* presid* cpi r_price* pop gdp
						corr change* starting_debt ending_debt debt_linear obs aaa baa conflicts house* senat* presid* cpi r_price* pop gdp if (incl) & ending_debt > 0 & fiscalmonth ~= 12
						sort year month 
						** Reg
						reg change 	starting_debt ending_debt debt_linear i.fiscalmonth c.obs##c.obs aaa baa conflicts house* senat* presid* cpi r_price* pop gdp if (incl) & ending_debt > 0 & fiscalmonth ~= 12
						fit_nb change 
						reg changep starting_debt 			  debt_linear i.fiscalmonth 			 aaa baa conflicts house* senat* presid* cpi r_price pop gdp if (incl) & ending_debt > 0 & fiscalmonth ~= 12
						fit_nb changep 
					
					** Save Turing Bot
					cd_nb_stage
					savesome change* starting_debt ending_debt debt_linear obs aaa baa conflicts house* senat* presid* cpi r_price* pop gdp if (incl) & ending_debt > 0 & fiscalmonth ~= 12 & change~=. using turing_treas, replace
					//use turing_treas, clear
					
						** Interactive models
						** First look - 0.0046
						reg change 	starting_debt ending_debt debt_linear i.fiscalmonth c.obs##c.obs aaa baa conflicts house* senat* presid* cpi r_price* pop gdp if (incl) & ending_debt > 0 //& fiscalmonth ~= 12
						fit_nb change 
						** Linear - 0.036 / 0.102 / 0.1793 / 0.1204
						reg change 	gdp r_priceR baa presidency housemaj r_price debt_linear if (incl) & ending_debt > 0 & fiscalmonth ~= 12
						fit_nb change 
						** Partial interactions - 0.10	/ 0.1713 / 0.1711 / 0.2980 / 0.2977
						reg change 	gdp r_priceR c.gdp#c.baa##c.presidency##c.housemaj##c.r_price debt_linear presidency r_price if (incl) & ending_debt > 0 // & fiscalmonth ~= 12
						fit_nb change	
						** Partial interactions II - 0.119 / 0.172 / 0.1678	/ 0.2520 / 0.2936
						reg change 	gdp r_priceR c.gdp#c.baa##c.presidency##c.housemaj##c.r_price conflicts#c.debt_linear#c.gdp#housemaj  if (incl) & ending_debt > 0 // & fiscalmonth ~= 12
						fit_nb change	
						** Partial interactions III - 0.094	/ 0.1175 / 0.1597 / 0.1080 / 0.1700
						reg change gdp r_priceR c.gdp#c.baa##c.presidency##c.housemaj#c.r_price#c.r_priceR conflicts#c.debt_linear#c.gdp#housemaj  if (incl) & ending_debt > 0 // & fiscalmonth ~= 12
						fit_nb change	
						** Partial interactions IV - 0.1382 / 0.1581 / 0.2240 / 0.2977 / 0.2679 / 0.1846 / 0.2040 / 0.2404
						reg change 	gdp r_priceR c.baa#c.aaa##c.aaa c.gdp#c.baa##presidency##housemaj##c.r_price conflicts#c.debt_linear#c.gdp#housemaj  if (incl) & ending_debt > 0 // & fiscalmonth ~= 12
						fit_nb change	
						** Partial interactions V - 0.1875 / 0.1344 / 0.1985 / 0.2983 / 0.2411 / 0.3057 / 0.2109 / 0.2407
						reg change 	c.gdp#c.r_priceR#c.baa c.baa#c.aaa##c.aaa##c.aaa#c.pop c.gdp#c.baa##presidency##housemaj##c.r_price#conflicts#c.debt_linear#c.gdp   if (incl) & ending_debt > 0 // & fiscalmonth ~= 12
						fit_nb change	
												
							sum change changep starting_debt ending_debt mdebtout debt_linear gdp r_priceR baa aaa pop presidency housemaj r_price conflicts  if (incl) & ending_debt > 0 // & fiscalmonth ~= 12
						
					** Save intermediate
					cd_nb_stage
					save treas_progress2, replace
					use treas_progress2, clear
														
					** Impute
					drop if ending_debt == 0
					drop if aaa==.
					drop incl changep
					reg change 	c.gdp#c.r_priceR c.baa#c.aaa##c.aaa#c.pop c.gdp#c.baa##presidency##housemaj##c.r_price#conflicts#c.debt_linear#c.gdp   //if ending_debt > 0 // & fiscalmonth ~= 12
					predict double yhat, xb
					
					** Correct for beginning and ending (scale) and replace missing
						order obs fiscal* yhat change starting_debt ending_debt mdebtout debtout debt_linear gdp r_priceR baa aaa pop presidency housemaj r_price conflicts  
						gsort -obs
					sort fiscalyear fiscalmonth
					by fiscalyear: egen double sum_change_delta		= sum(change)
					by fiscalyear: egen double yhat_delta			= sum(yhat)
					gen double annual_delta							= ending_debt - starting_debt	
					
					drop if yhat ==.
				
					** Scale 
						sum yhat *delta
					replace yhat									= yhat * annual_delta / yhat_delta
					sort fiscalyear fiscalmonth
					by fiscalyear: egen double yhat2_delta			= sum(yhat)
						sum yhat *delta
					
					** Generate mdebtout
					gen double mdebtout2							= mdebtout
					replace mdebtout2								= debtout if mdebtout == . & debtout ~= . 
					** Loop fill forward
					sort obs
					tsset obs
					foreach num of numlist 1/11 {
						
						replace mdebtout2							= L1.mdebtout2 + yhat if mdebtout2 == . & fiscalmonth == `num'
						
					} //end loop
					di "Done with fill change loopf."
					** Loop fill backwards
					sort obs
					tsset obs
					foreach num of numlist 11/1 {
						
						replace mdebtout2							= F1.mdebtout2 - yhat if mdebtout2 == . & fiscalmonth == `num'
						
					} //end loop
					di "Done with fill change loopb."
										
						order obs year month fiscal* yhat change *_delta starting_debt ending_debt mdebtout* debtout 	
						gsort -obs 
						
					** Save covariates for stock capitalization seasonality
					cd_nb_stage
					savesome obs year month yhat change starting_d* ending_debt gdp-cpi using equity_covars, replace
					
					** Keep treas
					sort year month
					order year month *debtout*
					keep year month mdebtout2
					rename mdebtout2 debtout
					
					** Save treas
					cd_nb_stage
					save debt_out, replace
					use equity_covars, clear
			
				} //end if
				di "Done with monthly treasury impute."
				
				** Stock capitalization impute
				** Gen full history monthly panel 
				** Only enable this on the 2nd run of the program - depends on a file saved below
				//scalar treasmo = 1 // Now set by calling file
				if treasmo == 1 {
						
					** Load monthly
					cd_nb_source
					import excel "Wilshire5000Monthly", sheet(Wilshire5000) firstrow clear
					
					** Clean for join
					renvars *, lower
					keep year monthclose adjclose
					rename adjclose mocap
					rename monthclose month
					** Adjust for 1st-of-month data convention - move to EOM
					replace year							= year - 1 if month==12
					
					** Save 
					cd_nb_stage
					save equity_mo, replace
					use equity_mo, clear
				
					** Load monthly panel
					cd_nb_stage
					use monthly_panel, clear
									
					** Join annual
					cd_nb_stage
					joinby year using equity_cap_ann, unmatched(both)
						tabulate _merge
						drop _merge
					
					** Join monthly
					cd_nb_stage
					joinby year month using equity_mo, unmatched(both)
						tabulate _merge
						drop _merge
						
					** Drop
					drop if mcap ==.
					
					** Look
					scalar look = 0
					if look == 1 {
						
						sort year
						egen double avg				= mean(mdebtout), by(year)
						replace avg					= round(avg)
						gsort -year -month
						gen double diffmoavg		= debtout - avg
						gen double diff_dec			= debtout - mdebtout
						sum diff* if debtout ~= .
						drop diff* avg
						
					} //end if
					di "Done with look treas."
					
					** Save intermediate
					cd_nb_stage
					save equity_progress, replace	
					use equity_progress, clear
						
					************************************
					** Impute missing months - stock capitalization
					************************************
					gsort -year -month
					
					** Gen ending (annual) debt covariate
					gen ending_cap								= mcap
					** Gen starting debt covariate
					sort year month
					gen obs										= _n
					sort obs
					tsset obs
					gen double starting_cap						= L12.ending_cap
					** Growth covariates
					gen double cap_growth						= ending_cap - starting_cap
					gen double cap_growth_mo					= cap_growth / 12
					sort year
					by year: gen double cap_cumul				= sum(cap_growth_mo) 
					gen double cap_linear						= starting_cap + cap_cumul
					
					** Clean up
					drop if starting_cap == 0 
					drop if starting_cap == . 
									
						** Reg
						reg mocap starting_cap ending_cap cap_linear i.month 
						
					** Monthly Change (dep var)
					sort obs
					tsset obs
					gen double change							= mocap - L.mocap 
						*scatter change obs if change ~=.
					gen double changep							= change / starting_cap
					gen double end_diff							= ending_cap - cap_linear
					
						sum if year == 2002
				
					** Approximations
					set seed	101							// 101 1011 1015 10151 101511 1015112(55 test) 1015115(55) / 1014115(55) incl Dec
					gen randsample			= runiform()
					sort randsample
					gen ob					= _n
					sum ob
					local holdout			= 0.55
					local upper				= ceil(r(max) * `holdout')
					gen incl 				= (ob <= `upper')
						di "Upper is `upper', holdout is `holdout'."
						sum ob randsample incl if mocap ~= .  & ending_cap > 0 //& month ~= 12
						tab incl if mocap ~= .  & ending_cap > 0 //& month ~= 12
					replace incl			= (incl==1 & mocap ~= . & ending_cap > 0 ) //& month ~= 12)
					drop ob
					
						** Reg
						reg change 	starting_cap ending_cap cap_linear i.month c.obs##c.obs if (incl) // & ending_cap > 0 //& month ~= 12
						fit_nb change 
						reg changep starting_cap cap_linear i.month if(incl) // & ending_cap > 0 //& month ~= 12
						fit_nb changep 
					
					************************************
					** Covariates to impute missing months
					** Stock cap
					************************************
					** Join monthly
					cd_nb_stage
					joinby year month using equity_covars, unmatched(both)
						tabulate _merge
						drop _merge
					drop if cpi==.
					rename yhat debt_yhat
						gsort -year -month
													
						** Look
						sum change* starting_cap ending_cap cap_linear i.month c.obs##c.obs aaa baa conflicts house* senat* presid* cpi r_price* pop gdp if(incl) // & ending_cap > 0 & month ~= 12
						order year month change* starting_cap ending_cap cap_linear obs aaa baa conflicts house* senat* presid* cpi r_price* pop gdp
						corr change* starting_cap ending_cap cap_linear obs aaa baa conflicts house* senat* presid* cpi r_price* pop gdp debt_yhat if(incl) // & ending_cap > 0 & month ~= 12
						sort year month 
						** Reg
						reg change 	starting_cap ending_cap cap_linear i.month c.obs##c.obs aaa baa conflicts house* senat* presid* cpi r_price* pop gdp if(incl) // & ending_cap > 0 & month ~= 12
						fit_nb change 
						reg changep starting_cap 			  cap_linear i.month 			 aaa baa conflicts house* senat* presid* cpi r_price pop gdp if(incl) // & ending_cap > 0 & month ~= 12
						fit_nb changep 
					
					** Save Turing Bot
					cd_nb_stage
					savesome change* starting_cap ending_cap cap_linear obs aaa baa conflicts house* senat* presid* cpi r_price* pop gdp if(incl) & change~=. using turing_equity, replace // & ending_cap > 0 & month ~= 12 
					//use turing_equity, clear
					
						** Interactive models
						** First look - 0.0046
						reg change 	starting_cap ending_cap cap_linear i.month c.obs##c.obs aaa baa conflicts house* senat* presid* cpi r_price* pop gdp if(incl) // & ending_cap > 0 //& month ~= 12
						fit_nb change 
						** Linear - 0.036 / 0.102 / 0.1793 / 0.1204
						reg change 	gdp r_priceR baa presidency housemaj r_price cap_linear if(incl) // & ending_cap > 0 & month ~= 12
						fit_nb change 
						** Partial interactions - 0.10	/ 0.1713 / 0.1711 / 0.2980 / 0.2977
						reg change 	gdp r_priceR c.gdp#c.baa##c.presidency##c.housemaj##c.r_price cap_linear presidency r_price if(incl) // & ending_cap > 0 // & month ~= 12
						fit_nb change	
						** Partial interactions II - 0.119 / 0.172 / 0.1678	/ 0.2520 / 0.2936
						reg change 	gdp r_priceR c.gdp#c.baa##c.presidency##c.housemaj##c.r_price conflicts#c.cap_linear#c.gdp#housemaj  if(incl) // & ending_cap > 0 // & month ~= 12
						fit_nb change	
						** Partial interactions III - 0.094	/ 0.1175 / 0.1597 / 0.1080 / 0.1700
						reg change gdp r_priceR c.gdp#c.baa##c.presidency##c.housemaj#c.r_price#c.r_priceR conflicts#c.cap_linear#c.gdp#housemaj  if(incl) // & ending_cap > 0 // & month ~= 12
						fit_nb change	
						** Partial interactions IV - 0.1382 / 0.1581 / 0.2240 / 0.2977 / 0.2679 / 0.1846 / 0.2040 / 0.2404
						reg change 	gdp r_priceR c.baa#c.aaa##c.aaa c.gdp#c.baa##presidency##housemaj##c.r_price conflicts#c.cap_linear#c.gdp#housemaj  if(incl) // & ending_cap > 0 // & month ~= 12
						fit_nb change	
						** Partial interactions V - 0.1875 / 0.1344 / 0.1985 / 0.2983 / 0.2411 / 0.3057 / 0.2109 / 0.2407
						reg change 	c.gdp#c.r_priceR#c.baa c.baa#c.aaa##c.aaa##c.aaa#c.pop c.gdp#c.baa##presidency##housemaj##c.r_price#conflicts#c.cap_linear#c.gdp   if(incl) // & ending_cap > 0 // & month ~= 12
						fit_nb change	
						** Partial interactions VI - 0.11
						reg change 	c.gdp##c.gdp#c.r_priceR#c.baa#c.baa c.baa#c.baa##c.aaa##c.aaa##c.aaa#c.pop#c.pop ///
							c.gdp#c.baa##presidency##housemaj##c.r_price#c.r_price##conflicts#c.cap_linear#c.gdp#c.debt_yhat ///
							c.debt_yhat##c.debt_yhat##c.debt_yhat i.month if(incl) // & ending_cap > 0 // & month ~= 12
						fit_nb change	
						** Partial interactions VII - 0.1270
						reg change 	c.gdp##c.gdp#c.r_priceR#c.baa#c.baa c.baa#c.baa##c.aaa##c.aaa##c.aaa#c.pop#c.pop ///
							c.gdp#c.baa##presidency##housemaj##c.r_price#c.r_price##conflicts#c.cap_linear#c.gdp#c.debt_yhat ///
							c.debt_yhat##c.debt_yhat##c.debt_yhat if(incl) // & ending_cap > 0 // & month ~= 12
						fit_nb change	
												
							sum change changep starting_cap ending_cap mocap cap_linear gdp r_priceR baa aaa pop presidency housemaj r_price conflicts debt_yhat if (incl) // & ending_cap > 0 // & month ~= 12
						
					** Save intermediate
					cd_nb_stage
					save equity_progress2, replace
					use equity_progress2, clear
														
					** Impute
					drop if ending_cap == 0
					drop if aaa==.
					drop incl changep
					reg change 	c.gdp##c.gdp#c.r_priceR#c.baa#c.baa c.baa#c.baa##c.aaa##c.aaa##c.aaa#c.pop#c.pop ///
							c.gdp#c.baa##presidency##housemaj##c.r_price#c.r_price##conflicts#c.cap_linear#c.gdp#c.debt_yhat ///
							c.debt_yhat##c.debt_yhat##c.debt_yhat 
					predict double yhat, xb
					
					** Dev stop
					if treasmo == 1111 {
						
						asdf_fix2
					
					} //end if
					di "Done with dev stop."
												
					
					** Correct for beginning and ending (scale) and replace missing
						order obs year month yhat change starting_cap ending_cap mocap cap_linear gdp r_priceR baa aaa pop presidency housemaj r_price conflicts  
						gsort -obs
					sort year month
					by year: egen double sum_change_delta		= sum(change)
					by year: egen double yhat_delta				= sum(yhat)
					gen double annual_delta						= ending_cap - starting_cap	
					drop if yhat ==.
					
						sum 	year month change yhat starting_cap ending_cap mocap debt_yhat sum_change* yhat_delta annual_delta cap_linear gdp r_priceR baa aaa pop presidency housemaj r_price conflicts 
						order 	year month change yhat starting_cap ending_cap mocap debt_yhat sum_change* yhat_delta annual_delta cap_linear gdp r_priceR baa aaa pop presidency housemaj r_price conflicts 
						gsort -obs
				
					** Scale so yhat cumulative change matches annual change
						sum yhat *delta
					replace yhat								= yhat * annual_delta / yhat_delta
					sort year month
					by year: egen double yhat2_delta			= sum(yhat)
						sum yhat *delta
						order year month change yhat *_delta
											
						sum 	year month change yhat starting_cap ending_cap mcap mocap* debt_yhat sum_change* yhat*_delta annual_delta cap_linear gdp r_priceR baa aaa pop presidency housemaj r_price conflicts 
						order 	year month change yhat starting_cap ending_cap mcap mocap* debt_yhat sum_change* yhat*_delta annual_delta cap_linear gdp r_priceR baa aaa pop presidency housemaj r_price conflicts 
						gsort -obs

					** Generate monthly cap
					gen double mocap2							= mocap
					replace mocap2								= mcap if mocap == . & mcap ~= . & month==12
					** Loop fill forward
					sort obs
					tsset obs
					foreach num of numlist 1/11 {
						
						replace mocap2							= L1.mocap2 + yhat if mocap2 == . & month == `num'
						
					} //end loop
					di "Done with fill change loopf."
					** Loop fill backwards
					sort obs
					tsset obs
					foreach num of numlist 11/1 {
						
						replace mocap2							= F1.mocap2 - yhat if mocap2 == . & month == `num'
						
					} //end loop
					di "Done with fill change loopb."
													
					** Save covariates for stock capitalization seasonality
					if treasmo == 0 {
						
						order obs year month * yhat change *_delta starting_cap ending_cap mocap* 	
						gsort -obs 
						cd_nb_stage
						savesome obs year month yhat change starting_d* ending_cap gdp-cpi using stock_covars, replace
						
					} //end if
					di "Done with first round save."
					
					** Keep equity
					sort year month
					order year month mocap*
					keep year month mocap2
					rename mocap2 mcap
					
					** Save equity
					cd_nb_stage
					save cap_out, replace
					use cap_out, clear
			
				} //end if
				di "Done with monthly equity impute."
				
			} //end if
			di "Done with equity data."
			
			****************
			** Shiller - bonds, equities, housing prices
			****************
			scalar shiller = 1
			if shiller == 1 {
					
				** Prep Shiller equity/bond data
				cd_nb_shiller
				import excel "ie_data.xls", sheet("Data") cellrange(A8:G2485) firstrow clear
				renvars *, lower
				
				** Rename
				gen year 					= floor(date)
				gen month 					= (date - year) * 100
				
				** Drop
				drop if date==.
				drop date
				gen n 						= _n
				duplicates drop year month, force
				drop n
				drop if e==.
				destring *, replace

				** Gen r_stock
				local payout_rate_early		= 0.625
				local payout_rate_mid		= 0.825
				local payout_rate_late		= 1.000
				gen double r_stock					= e / p
				replace r_stock				= r_stock * `payout_rate_early' if year <= 1983
				replace r_stock				= r_stock * `payout_rate_mid' 	if year > 1983 & year <= 1993  //cite Plowback Capex (finario.com)
				replace r_stock				= r_stock * `payout_rate_late' 	if year > 1993
				
				rename rategs10 r_bond
				replace r_stock 			= r_stock * 100
				
				** Other stats
				rename d dividend
				rename e earnings
				rename p snp500
				
				** r_price
				sort year month 
				gen n1						= _n
				sort n1
				tsset n1
				gen double cpi_lag1			= L12.cpi 
				gen double r_price			= (cpi - cpi_lag1) / cpi_lag1 //* 12
				replace r_price				= r_price * 100
					sum r_price
					
				** Rogoff r_price - Long-Run Trends, Rogoff et al., AER 2024 - t-7 to t-1, 33, 23, 16, 11, 8, 3
				gen double r_priceR				= L1.r_price * 0.33 + L1.r_price * 0.23 + L1.r_price * 0.16 + L1.r_price * 0.11 + L1.r_price * 0.08 + L1.r_price * 0.03  
					reg r_price r_priceR
					
				** Keep and save
				order 	year month dividend earnings snp500 cpi r_stock r_bond r_price*
				keep 	year month dividend earnings snp500 cpi r_stock r_bond r_price*
				
				cd_nb_stage
				save shiller_data, replace
				use shiller_data, clear
				
				** Prep Shiller housing price index (2000 January == 100)
				cd_nb_shiller
				import excel "Fig3-1 (1).xls", sheet("Data") cellrange(H7:J999) firstrow clear
				
				** Clean up
				renvars *, lower
				rename j source
				rename fromfig21revised2011xls house_price
				drop if date==.
				** Dates
				gen year = floor(date)
				gen month = date - year
				replace month 				= month * 12 + 0.5 if month !=0
				replace month 				= 12 if month==0
				gen check 					= 1/0.04166667
				drop check
				
				** Make nominal -- multiply by 2000 mean house price $119,600 (US 2000 Census)
				replace house_price			= house_price * 119600 / 100
				
				** Order and save
				order year month house_price source 
				keep year month house_price 
				cd_nb_stage
				save shiller_housing, replace
				use shiller_housing, clear
	
			} //end if
			di "Done with Jorda data."
			
			****************
			** Moura - housing units
			****************
			scalar units = 1
			if units == 1 {
					
				** Prep Moura units data
				** Updated by Cross 3.10.25
				** 2024 available September 2025
				cd_nb_source
				import excel "moura120years2015updated2024.xlsx", sheet("Completed") firstrow clear
				renvars *, lower
						
				** Gen month
				gen month 				= 12
				rename total house_units
				gen ones				= 1
				
				** Gen growth
				sort year
				tsset year
				gen double growth						=  house_units - L1.house_units
				
				** Order and save
				order 	year month house_units growth source 
				keep 	year month house_units growth
				cd_nb_stage
				save moura_housing, replace
				
				** Gen housing unit seasonality from FRED completions
				cd_nb_source
				import excel "UScompletionsFRED2024.xlsx", sheet("Monthly") firstrow clear
				renvars *, lower
				
				** Create seasonal weights - all years
				//gen desc_yr 							= 3000 - year
				//gen desc_mo								= 13 - month							
				
				sort year month
				by year: egen double annual_tot 				= sum(completions)
				gen double season_wts							= completions / annual_tot 
				by year: gen double cumul_wts					= sum(season_wts)
				replace season_wts						= cumul_wts
				drop cumul_wts
				
				** Check
				tab season_wts if month == 12
							
				** Order and save
				order year month completions season_wts
				keep  year month completions season_wts
				sort year month
				replace completions 					= completions / 1000
				cd_nb_stage
				save completions_housing, replace
				
				** Gen seasonality weights (for earlier years)
				sort month
				by month: egen double seasonal_wts				= sum(completions) 
				egen double allyears_compl						= sum(completions)
				replace seasonal_wts					= seasonal_wts / allyears_compl
				keep month seasonal_wts
				duplicates drop
				sort month
				gen double cumul_wts					= sum(seasonal_wts)
				
				** Order and save
				rename cumul_wts season_wts_fill
				order month season_wts_fill
				keep  month season_wts_fill
				cd_nb_stage
				save completions_seasonal_wts, replace
			
				** Generate full-history monthly housing file
				** Months
				clear
				set obs 12
				gen month 								= _n
				gen join_one							= 1
				cd_nb_stage
				save join_months, replace
				** Years
				cd_nb_stage
				use moura_housing, clear
				keep year
				duplicates drop
				gen join_one							= 1
				cd_nb_stage
				joinby join_one using join_months, unmatched(master)
					tab _merge
					drop _merge
				drop join_one
				order year month
				sort year month
				
				** Save monthly panel
				cd_nb_stage
				save monthly_panel, replace
				use monthly_panel, clear
				
				** Join annual units (repeat across months, then adjust)
				cd_nb_stage
				joinby year using moura_housing, unmatched(master)
					tab _merge
					drop _merge
				gen moura_h_orig			= (month==12 & growth ~= .)
				
				** Join seasonal factors - for 1968+
				cd_nb_stage
				joinby year month using completions_housing, unmatched(master)
					tab _merge
					drop _merge
					
				** Join seasonal factors - for pre 1968
				cd_nb_stage
				joinby month using completions_seasonal_wts, unmatched(master)
					tab _merge
					drop _merge
					
				** Select weights
				replace season_wts 					= season_wts_fill if season_wts == .
				drop completions season_wts_fill
				
				** Adjust annual units for seasonal completions
				** units are December units, less incomplete portion of year's projects
				replace season_wts					= 1 - season_wts
				gen double incompletes						= growth * season_wts
				replace house_units					= house_units - incompletes 
				
				** Save
				order year month moura_h_orig house_units
				keep  year month moura_h_orig house_units
				cd_nb_stage
				save housing_units, replace
				
				** Join housing returns
				cd_nb_stage
				joinby year month using shiller_housing, unmatch(master)
					tab _merge
					drop _merge
				gen shill_h_orig				= (month==12 & house_price ~=.)
						
				** Make w_house here
				** Sort and fill and divide and drop
				** Keep house price for r_house at last join!
				** Check the old FRED monthly rents...
				
				** Calc gain
				sort year month 
				gen obs								= _n
				tsset obs
				gen double last_price						= L12.house_price
				gen double gain							= house_price - last_price
				
				** Fill gain
				sort year
				by year: egen double fill_price			= sum(house_price)
				sort obs
				gen double rev_fill_price					= L12.fill_price
				sort year
				by year: egen double fill_gain				= sum(gain)
				gen double monthly_fill					= fill_gain / 12 * month if house_price == .
				replace house_price					= rev_fill_price + monthly_fill if house_price == .
				replace house_price					= . if house_price==0
				gen double w_house							= house_price * house_units / 1000000000 //billions of dollars
				gen w_price							= 1 //numeraire 
				
				** Add master time variable t
				sort year month
				gen t								= _n
				
				** Save
				order 	year month t *_orig house_price house_units w_house w_price
				keep	year month t *_orig house_price house_units w_house w_price
				cd_nb_stage
				save housing_data, replace
										
			} //end if
			di "Done with Moura data."
			
			****************
			** Join all
			****************
			scalar all = 1
			if all == 1 {
				
				** Start with housing units (most complete monthly)
				cd_nb_stage
				use housing_data, clear
				
				** Join monthly equity market cap w_equity
				** Second run treasmo == 1
				if treasmo == 1 {
					
						** Display
						scalar list treasmo
					
					cd_nb_stage
					joinby year month using cap_out, unmatched(master)
						tab _merge
						drop _merge
					gen equ_cap_orig			= (month==12 & mcap~=.)
					
				} //end if
				** First run treasmo == 0
				else {
					
					cd_nb_stage
					joinby year using equity_cap_ann, unmatched(master)
						tab _merge
						drop _merge
					gen equ_cap_orig			= (month==12 & mcap~=.)
					
				} //end if
				di "Done with if treasmo join annual."
										
				** Naming (billions)
				rename mcap w_stock
											
				** Join debt outstanding w_debt
				cd_nb_stage
				joinby year month using debt_out, unmatched(master)
					tab _merge
					drop _merge
				gen debt_orig				= (month==12 & debtout~=.)
												
				** Naming - billions
				rename debtout w_bond
				replace w_bond				= w_bond / 1000 // convert from millions to billions
				
				** Join stock bond returns
				cd_nb_stage
				joinby year month using shiller_data, unmatched(both)
					tab _merge
					drop _merge
					
				** Join cpi
				//joinby year month using cpi_monthly, unmatched(both)
				//	tab _merge
				//	drop _merge
					
				** Join pop
				joinby year month using pop_monthly, unmatched(both)
					tab _merge
					drop _merge
				gen pop_orig				= (pop_monthly ~=.)
					
				** Join GDP annual 1947
				joinby year using gdp_data, unmatched(both)
					tab _merge
					drop _merge
				gen gdp_orig				= (month==12 & GDP ~=.)
				
				** Join jorda stats -- fill monthly house price imputed
				rename r_bond r_bond_shill
				cd_nb_stage
				joinby year using jorda_monthly_join, unmatched(both)
					tab _merge
					drop _merge
				replace month 				= 12 if month==. & year ==1870
				gen jorda_orig				= (month==12 & r_house~=.)
					
				** POP
				replace pop					= pop_monthly if pop_monthly ~=.
				drop pop_monthly
				replace gdp 				= GDP if gdp == .
				drop GDP
				
				** Select
				drop r_bond
				rename r_bond_shill r_bond
				
				** Join Jorda house annual-only (drop existing house)
				drop r_house
				cd_nb_stage
				joinby year month using jorda_annual_join, unmatched(both)
					tab _merge
					drop _merge
				
				** Join monthly rent index
				cd_nb_stage
				joinby year month using rent_index, unmatched(both)
					tab _merge
					drop _merge
				gen rent_cpi_orig			= (rent_index ~=. )
					
				** Order
				order year month t *_orig cpi r_price gdp pop w_stock w_bond w_house w_price r_stock r_bond r_house house_price house_units 
				** House price inclusion (later change to net rent inclusion)
				gen h_include 				= (house_price ~=.) 
				
				** Update t
				sort year month
				replace t					= _n
				
				** Save
				cd_nb_stage
				save all_join_temp, replace
				use all_join_temp, clear
				
				******************************
				** Monthly variation in rent
				******************************
				scalar implied = 1
				if implied == 1 {
					
					** load
					cd_nb_stage
					use all_join_temp, clear
					
					** Drop missing data for sums
					keep if house_price ~=.
					sort year month t
										
					** Look at implied net rent 
					order month year, last
					gen double implied_rent				= house_price * r_house / 12
					
					** Interpolate model 1 -- 1947 onward -- monthly implied housing variability
					sort year month
					replace t							= _n
					
					** Note non-annual and non-monthly rent_index periods			
					** Drop frozen rent_index data (late WWII)	
					gen period							= "monthly"
					replace period						= "annual" 			if year <= 1918
					replace period						= "semiannual" 		if year >=1919 & year <= 1920
					replace period						= "semiannual" 		if t <= 523 & year >=1925
					replace period						= "intermittent" 	if t >= 362 & t <= 369 
					replace period						= "quarterly" 		if t >= 370 & t <= 406 
					replace period						= "quarterly" 		if t >= 380 & t <= 384 
						replace rent_index				= .				 	if t >= 380 & t <= 384
					replace period						= "intermittent" 	if t >= 407 & t <= 420 
						replace rent_index				= .				 	if t >= 407 & t <= 420 
					replace period						= "intermittent" 	if t >= 524 & t <= 549 
					replace period						= "quarterly"	 	if t >= 550 & t <= 571 
					replace period						= "intermittent" 	if t >= 572 & t <= 602
						replace rent_index				= .					if t >= 572 & t <= 602
					replace period						= "intermittent" 	if t == 604 | t == 606 | t==607 | t==612 | t==615 | t==617 
						replace rent_index				= .					if t == 604 | t == 606 | t==607 | t==612 | t==615 | t==617 
					replace period						= "intermittent" 	if t >= 621 & t <= 626
						replace rent_index				= .					if t >= 621 & t <= 626
					replace period						= "intermittent" 	if t >= 628 & t <= 643
						replace rent_index				= .					if t >= 628 & t <= 643
					replace period						= "intermittent" 	if t >= 645 & t <= 660
						replace rent_index				= .					if t >= 645 & t <= 660
					replace period						= "quarterly"	 	if t >= 657 & t <= 667 
					replace period						= "intermittent" 	if t >= 668 & t <= 674 
						replace rent_index				= .					if t >= 668 & t <= 674 
					replace period						= "intermittent" 	if t == 676 | t == 678 | t==679  
						replace rent_index				= .					if t == 676 | t == 678 | t==679   
					
						** Dev temp
						order year month r_house house_price house_units t period rent_index implied_rent			
						//drop if year <= 1917
					
					** Net rent monthly index or implied available
					gen net_orig 						= (rent_index~=. | implied_rent ~=.)
					gen net_include						= t >= 680								//From July, 1947						
					
					** Forecast implied rent from Jorda r_house
					reg implied_rent rent_index c.t#c.house_price house_price c.house_price#c.house_units //c.t##c.t rent_index //cpi //gdp pop //##c.rent_index##c.rent_index dividend r_priceR cpi gdp pop 
					predict index_hat, xb 
					
					** Interpolate model 2 -- Pre 1949 - missing rent_index entries
					reg rent_index house_price c.t#c.house_price house_units c.t#c.house_units c.t##c.t##c.t 
					predict index_hat2, xb
					replace index_hat					= index_hat2 if year < 1949
					drop index_hat2
					
						** Dev temp
						//sort index_hat year month
						order year month r_house house_price house_units t period rent_index implied_rent index_*			
						//drop if year <= 1917
					
					** Annual interpolation
					scalar annuall	= 1
					if annuall == 1 {

							** Dev save
							cd_nb_stage 
							save temp_interpol8, replace
							
							use temp_interpol8, clear
													
						** Calc implied rent inflation -- annual (pre 1919)
						sort t
						tsset t
						gen double implied_gain				= (implied_rent - L12.implied_rent) 
						gen double implied_infl				= implied_gain / L12.implied_rent
						gen double index_infl				= (index_hat - L1.index_hat) / L1.index_hat
						
							** Dev temp
							order year month r_house house_price house_units rent_index implied_rent index_hat* h_include index_infl implied_infl cpi pop gdp
							//keep if year >= 1909
							
							
						** Compare annual indexed inflation to implied inflation and correct
						sort year
						by year: egen double index_ann		= sum(index_infl)
						by year: egen double implied_ann	= sum(implied_infl)
						drop implied_infl
						
						** Scale index inflation
						gen double index_corr				= index_infl / index_ann * implied_ann
						by year: egen double check_impl		= sum(index_corr)
						
							** Dev temp
							order year month r_house house_price house_units rent_index implied_rent index_hat* index_ann implied_ann index_corr check_impl index_infl index_ann implied_ann h_include 
							//drop if year < 1906
						
						drop implied_ann index_ann index_infl
						
						** Accumulate and fill - not monthly 
						by year: gen double cumul_index		= sum(index_corr)
						gen double cumul_corr				= cumul_index / check_impl
						by year: egen double gain			= sum(implied_gain)
						
							** Dev temp
							order year month r_house house_price house_units rent_index implied_rent index_hat* index_corr cumul_index cumul_corr implied_gain gain h_include 
							//drop if year < 1929
						
						drop check_impl implied_gain cumul_index index_corr
										
						** Match December Entries (for annual index period) 
						** Gen implied_rent 2, fix to match december entries
						sort t
						gen double LY_implied_rent			= L12.implied_rent
						sort year
						by year: egen double implied_rent2	= sum(LY_implied_rent)
						drop LY_implied_rent
						replace implied_rent2				= implied_rent2 + gain * cumul_corr // last year rent, plus the monthly portion of the annual gain
						replace implied_rent2				= implied_rent if implied_rent~=. & implied_rent2==. //fill Dec 1890
													
						** Dev temp
						order year month r_house house_price house_units t rent_index implied_rent* gain index_hat* cumul_corr h_include 
					
					** Clean up
					drop gain cumul_corr
					
					} //end if
					di "Done with annual interpol calc."
																
					** Semi-annual interpolation
					scalar siannuall	= 1
					if siannuall == 1 {

							** Dev save
							cd_nb_stage 
							save temp_interpol9, replace
							
							use temp_interpol9, clear
							
						** Add June rent_index levels (mean adjusted) to implied_rent	
						sort t
						tsset t
						gen mean_index						= (L6.implied_rent + F6.implied_rent) / (L6.rent_index + F6.rent_index) 
						replace implied_rent 				= rent_index * mean_index if period == "semiannual" & month == 6
						
							** Dev temp
							order year month r_house house_price house_units t period rent_index implied_rent mean_index implied_rent2 index_hat* h_include 
						
						
						** Calc implied rent inflation -- semiannual
						gen double implied_gain				= (implied_rent - L6.implied_rent) 
						gen double implied_infl				= implied_gain / L6.implied_rent
						gen double index_infl				= (index_hat - L1.index_hat) / L1.index_hat
					
							** Dev temp
							order year month r_house house_price house_units t period rent_index implied_rent mean_index implied_rent2 index_hat*   implied_gain implied_infl index_infl h_include 
									
						** Compare annual indexed inflation to implied inflation and correct
						gen semiyear							= year + 0.5 * (month >= 7 & month <= 12) //(month >= 1 & month <= 6)
						order semiyear
						sort semiyear t
						by semiyear: egen double index_ann		= sum(index_infl)
						by semiyear: egen double implied_ann	= sum(implied_infl)
						drop implied_infl
						
						** Scale index inflation
						gen double index_corr					= index_infl / index_ann * implied_ann
						by semiyear: egen double check_impl		= sum(index_corr)
						
							** Dev temp
							order year month r_house house_price house_units t period rent_index implied_rent mean_index implied_rent2 index_hat*   implied_gain index_infl    index_ann implied_ann index_corr check_impl h_include 
							//drop if year < 1918
						
						drop implied_ann index_ann index_infl
						
						** Accumulate and fill - not monthly 
						by semiyear: gen double cumul_index		= sum(index_corr)
						gen double cumul_corr					= cumul_index / check_impl
						by semiyear: egen double gain			= sum(implied_gain)
						
							** Dev temp
							order semiyear year month r_house house_price house_units t period rent_index implied_rent mean_index implied_rent2 index_hat*   implied_gain index_corr check_impl h_include 
							//drop if year < 1906
						
						drop check_impl implied_gain cumul_index index_corr
										
						** Match June Entries (for semiannual index period) 
						** Gen implied_rent 3
						sort t
						gen double L6_implied_rent			= L6.implied_rent
						sort semiyear t
						by semiyear: egen double implied_rent3	= sum(L6_implied_rent)
						replace implied_rent3				= implied_rent3 + gain * cumul_corr // last year rent, plus the monthly portion of the annual gain
						** Fill semi-annual section					
						replace implied_rent2				= implied_rent3 if implied_rent3~=. & period=="semiannual"
						
							** Dev temp
							order semiyear year month r_house house_price house_units t period rent_index implied_rent mean_index implied_rent2 index_hat* L6*  implied_rent3 h_include 
							//drop if year < 1906
						
						drop L6_implied_rent implied_rent3 mean_index semiyear cumul_corr gain
						
					} //end if
					di "Done with semiannual interpol calc."
				
					** Quarterly interpolation
					scalar quarter	= 1
					if quarter == 1 {

							** Dev save
							cd_nb_stage 
							save temp_interpol10, replace
							
							use temp_interpol10, clear
								
						** Add Quarterly rent_index levels (mean adjusted) to implied_rent	
						sort t
						tsset t
						gen mean_index						= .
						replace mean_index					= (L3.implied_rent + F9.implied_rent) / (L3.rent_index + F9.rent_index) if period == "quarterly" & month == 3 
						replace mean_index					= (L6.implied_rent + F6.implied_rent) / (L6.rent_index + F6.rent_index) if period == "quarterly" & month == 6 
						replace mean_index					= (L9.implied_rent + F3.implied_rent) / (L9.rent_index + F3.rent_index) if period == "quarterly" & month == 9 

						replace implied_rent 				= rent_index * mean_index if period == "quarterly" & implied_rent==. & mean_index~=. & (month == 3 | month == 6 | month == 9 )
						
							** Dev temp
							order year month r_house house_price house_units t period rent_index implied_rent mean_index implied_rent2 index_hat* h_include 
							//drop if year < 1920
						
						** Calc implied rent inflation -- semiannual
						gen double implied_gain				= (implied_rent - L3.implied_rent) 
						gen double implied_infl				= implied_gain / L3.implied_rent
						gen double index_infl				= (index_hat - L1.index_hat) / L1.index_hat
					
							** Dev temp
							order year month r_house house_price house_units t period rent_index implied_rent mean_index implied_rent2 index_hat*   implied_gain implied_infl index_infl h_include 
									
						** Compare annual indexed inflation to implied inflation and correct
						gen day								= 1
						gen dt								= mdy(month, day, year)
						gen quarter							= quarter(dt)
							order dt quarter
						drop day dt
						gen qyear							= year + 0.1 * quarter
							order qyear
						drop quarter
						sort qyear t
						by qyear: egen double index_ann		= sum(index_infl)
						by qyear: egen double implied_ann	= sum(implied_infl)
						drop implied_infl
						
						** Scale index inflation
						gen double index_corr				= index_infl / index_ann * implied_ann
						by qyear: egen double check_impl	= sum(index_corr)
						
							** Dev temp
							order year month r_house house_price house_units t period rent_index implied_rent mean_index implied_rent2 index_hat*   implied_gain index_infl    index_ann implied_ann index_corr check_impl h_include 
							//drop if year < 1918
						
						drop implied_ann index_ann index_infl
						
						** Accumulate and fill - not monthly 
						by qyear: gen double cumul_index	= sum(index_corr)
						gen double cumul_corr				= cumul_index / check_impl
						by qyear: egen double gain			= sum(implied_gain)
						
							** Dev temp
							order qyear year month r_house house_price house_units t period rent_index implied_rent mean_index implied_rent2 index_hat*  cumul_index implied_gain index_corr check_impl h_include 
							//drop if year < 1906
						
						drop check_impl implied_gain cumul_index index_corr
										
						** Match Quarterly Entries  
						** Gen implied_rent 4
						sort t
						gen double L3_implied_rent			= L3.implied_rent
						sort qyear t
						by qyear: egen double implied_rent4	= sum(L3_implied_rent)
						replace implied_rent4				= implied_rent4 + gain * cumul_corr // last year rent, plus the monthly portion of the annual gain
												
						** Fill semi-annual section					
						replace implied_rent2				= implied_rent4 if implied_rent4~=. & period=="quarterly"
						
							** Dev temp
							order qyear year month r_house house_price house_units t period rent_index implied_rent* mean_index index_hat* L3* gain cumul_corr h_include 
							//drop if year < 1906
						
						drop L3_implied_rent implied_rent4 mean_index
						
					} //end if
					di "Done with semiannual interpol calc."
				
						** Mark intermediate months with missing index values
						gen missing							= 0
						replace missing						= 1 if rent_index == .
						sort year
						by year: egen dropit				= sum(missing)
						//drop if index_hat==. & r_house == .
						//drop if dropit > 0   & r_house == .
						drop dropit missing
						
					** Fill monthly r_house
					gen double implied_rate 			= implied_rent2 * 12 / house_price
					replace r_house 					= implied_rate if r_house==. & implied_rate ~= .
					drop implied_rate
					rename implied_rent2 net_rent 
					
					** Fill later-years r_house > 2015
					sum implied_rent if year == 2015 & month ==12
					local impl = r(mean)
					sum index_hat  if year == 2015 & month ==12
					local ind = r(mean)
						di "Scaling `ind' to `impl'."
					gen double implied_rent5 			= index_hat / `ind' * `impl'
					replace r_house 					= implied_rent5 * 12 / house_price if r_house == . & implied_rent5 ~=.
					replace net_rent					= implied_rent5 if net_rent==. & implied_rent5 ~=.
					replace net_rent 					= net_rent * 12
					
						** Dev temp
						order qyear year month r_house house_price house_units t period net_rent rent_index implied_rent* index_hat*  gain cumul_corr h_include 
					
						** Audit r_house
						gen test_r_house				= net_rent * 12 / house_price
						order r_house test_r_house
						sum year month *r_house if r_house ~= test_r_house
						drop test_r_house
					
					drop implied_rent* index_* 
					
					** Back-interpolate gross_rent
					//gen gross_rent 						= rent_index
					//reg gross_rent c.t##c.house_units##c.net_rent //##c.t##c.house_units##c.house_units dividend r_priceR cpi gdp pop net_rent 
					//predict gross_hat, xb
					** Anchor to net rent and rent index here -- see New r_house code
					
					** Order and save house CAPE data
					order year month house_price net_rent
					cd_nb_stage
					savesome year month house_price net_rent using housing_CAPE_data, replace
					
					** Order and keep for join
					order	year month r_house net_*
					keep 	year month r_house net_* 
					
					** Save for join
					cd_nb_stage
					save r_house_join, replace
					use r_house_join, clear
					
					** Load and join
					cd_nb_stage
					use all_join_temp, clear
					drop r_house 
					
					** Join
					cd_nb_stage
					joinby year month using r_house_join, unmatched(master)
						tab _merge
						drop _merge
						
					** Update h_include
					replace h_include 			= 0 if r_house ==.
					
					** Order
					order year month t w_* r_* house_* *_rent
					order *_include *_orig, last
					
					** Rename gross_rent -- If you need to interpolate, back-interpolate from net_rent above
					rename rent_index gross_rent
					replace gross_rent					= gross_rent * 12
															
				} //end if
				di "Done with monthly variation."
				
				** Percentage units
				replace r_house					= r_house * 100
				
				** Save
				cd_nb_stage
				save analysis_data, replace
				use analysis_data, replace
				
				** Save CPI, GDP, POP for Covariate run - 2nd run
				cd_nb_stage
				savesome year month cpi gdp pop r_price r_priceR using treas_covariates, replace
				use treas_covariates, clear
				
				** Housing CAPE prep
				** Inputs to housing_ie_data "Data" tab paste
				** Load and paste into xls
				cd_nb_stage
				use housing_CAPE_data, clear //Paste into excel sheet 
				
				** Prep Shiller CAPE comparison 
				** Stocks
				cd_nb_shiller
				import excel "ie_data.xls", sheet("regData") cellrange(A8:c1739) firstrow clear
				renvars *, lower
					sum
				** Save
				cd_nb_stage
				save stock_CAPE_reg, replace
					
					** Preliminary look at Shiller-prepared data (R-squared 28.99 1380 obs)
					reg returns yield if date >=1900 & date<=2015
					sum * if date >=1900 & date<=2015
					** Compare housing time period
					reg returns yield if date>=1947.07 & date<2014
					sum * if date>=1900.12 & date<2014
					
				** Houses -- after paste above
				cd_nb_shiller
				import excel "house_ie_data.xls", sheet("regData") cellrange(A8:c1616) firstrow clear
				renvars *, lower
					sum
				** Save
				cd_nb_stage
				save house_CAPE_reg, replace
				
					** Preliminary look at Shiller-prepared data (R-squared 23.96 obs 1357)
					reg returns yield if date>=1900.12 & date<2014
					sum * if date>=1900.12 & date<2014
					
					reg returns yield if date>=1947.07 & date<2014
					sum * if date>=1947.07 & date<2014
					sum * if returns~=.
												
			} //end if
			di "Done with join for analysis."
					
		} //End if
		di "Done with load."

end
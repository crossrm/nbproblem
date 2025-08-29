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
					gen ratio				= cpi_hist / cpi
					replace cpi 			= cpi_hist / 2.97 if cpi ==.	// 1913 ratio
					
					** Calc inflation
					sort year month
					gen obs 				= _n
					sort obs
					tsset obs
					gen inflation_mo		= ( cpi - L12.cpi ) / L12.cpi
					gen inflation_ann		= ( cpi - L1.cpi ) / L1.cpi
					gen inflation 			= .
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
					//gen r_pop		= (pop - l.pop) / l.pop
				
					** Inflation adjust
					//gen rr_bond		= r_bond - r_infl
					
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
				save equity_cap, replace
			
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
					clear all
					set obs 12
					gen month 								= _n
					gen join_one							= 1
					cd_nb_stage
					save join_months, replace
					** Years
					clear all
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
						egen avg					= mean(mdebtout), by(year)
						replace avg					= round(avg)
						gsort -year -month
						gen diffmoavg			= debtout - avg
						gen diff_dec			= debtout - mdebtout
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
					** Impute missing months
					************************************
					** Save intermediate
					cd_nb_stage
					use treas_progress, clear
									
					gsort -year -month
					drop recorddate
					
					** Gen september ending debt covariate
					gen fiscalyear								= year
					replace fiscalyear							= fiscalyear - 1 if month < 10
					gen double debout_zero						= debtout * 1000				// multiply to preserve accuracy of egen sum function below
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
						reg change 	c.gdp#c.r_priceR c.baa#c.aaa##c.aaa#c.pop c.gdp#c.baa##presidency##housemaj##c.r_price#conflicts#c.debt_linear#c.gdp   if (incl) & ending_debt > 0 // & fiscalmonth ~= 12
						fit_nb change	
						
						sum change changep starting_debt ending_debt mdebtout debt_linear gdp r_priceR baa aaa pop presidency housemaj r_price conflicts  if (incl) & ending_debt > 0 // & fiscalmonth ~= 12
						
					** Save intermediate
					cd_nb_stage
					save treas_progress2, replace
					use treas_progress2, clear
					
									
					** Impute
					drop if ending_debt == 0
					drop incl changep
					reg change 	c.gdp#c.r_priceR c.baa#c.aaa##c.aaa#c.pop c.gdp#c.baa##presidency##housemaj##c.r_price#conflicts#c.debt_linear#c.gdp   //if ending_debt > 0 // & fiscalmonth ~= 12
					reg change obs
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
					
					** Keep
					sort year month
					order year month *debtout*
					keep year month mdebtout2
					rename mdebtout2 debtout
					
					** Save
					cd_nb_stage
					save debt_out, replace
			
				} //end if
				di "Done with monthly treasury impute."
				
			} //end if
			di "Done with treas data."
			
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
				gen r_stock					= e / p
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
				gen cpi_lag1				= L12.cpi 
				gen r_price					= (cpi - cpi_lag1) / cpi_lag1 //* 12
				replace r_price				= r_price * 100
					sum r_price
					
				** Rogoff r_price - Long-Run Trends, Rogoff et al., AER 2024 - t-7 to t-1, 33, 23, 16, 11, 8, 3
				gen r_priceR				= L1.r_price * 0.33 + L1.r_price * 0.23 + L1.r_price * 0.16 + L1.r_price * 0.11 + L1.r_price * 0.08 + L1.r_price * 0.03  
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
				gen growth						=  house_units - L1.house_units
				
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
				by year: egen annual_tot 				= sum(completions)
				gen season_wts							= completions / annual_tot 
				by year: gen cumul_wts					= sum(season_wts)
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
				by month: egen seasonal_wts				= sum(completions) 
				egen allyears_compl						= sum(completions)
				replace seasonal_wts					= seasonal_wts / allyears_compl
				keep month seasonal_wts
				duplicates drop
				sort month
				gen cumul_wts					= sum(seasonal_wts)
				
				** Order and save
				rename cumul_wts season_wts_fill
				order month season_wts_fill
				keep  month season_wts_fill
				cd_nb_stage
				save completions_seasonal_wts, replace
			
				** Generate full-history monthly housing file
				** Months
				clear all
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
				gen incompletes						= growth * season_wts
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
				gen last_price						= L12.house_price
				gen gain							= house_price - last_price
				
				** Fill gain
				sort year
				by year: egen fill_price			= sum(house_price)
				sort obs
				gen rev_fill_price					= L12.fill_price
				sort year
				by year: egen fill_gain				= sum(gain)
				gen monthly_fill					= fill_gain / 12 * month if house_price == .
				replace house_price					= rev_fill_price + monthly_fill if house_price == .
				replace house_price					= . if house_price==0
				gen w_house							= house_price * house_units / 1000000000 //billions of dollars
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
				
				** Join equity market cap w_equity
				cd_nb_stage
				joinby year using equity_cap, unmatched(master)
					tab _merge
					drop _merge
				gen equ_cap_orig			= (month==12 & mcap~=.)
				
				** Naming (billions)
				rename mcap w_stock
							
				** Join debt outstanding w_debt
				cd_nb_stage
				joinby year month using debt_out, unmatched(master)
					tab _merge
					drop _merge
				gen debt_orig				= (month==12 & debtout~=.)
				
				asdf_monthly 
				
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
								
					** Look at implied net rent 
					order month year, last
					gen implied_rent			= house_price * r_house / 12
					
					** Interpolate monthly implied inflation
					sort year month
					replace t					= _n
					** Forecast
					reg implied_rent t c.rent_index##c.rent_index 
					predict index_hat, xb 
					** Calc implied inflation
					sort t
					tsset t
					gen implied_gain			= (implied_rent - L12.implied_rent) 
					gen implied_infl			= implied_gain / L12.implied_rent
					gen index_infl				= (index_hat - L1.index_hat) / L1.index_hat
					
					** Compare annual indexed inflation to implied inflation and correct
					sort year
					by year: egen index_ann		= sum(index_infl)
					by year: egen implied_ann	= sum(implied_infl)
					drop implied_infl
					
					** Scale index inflation
					gen index_corr				= index_infl / index_ann * implied_ann
					by year: egen check_impl	= sum(index_corr)
					drop implied_ann index_ann index_infl
					
					** Accumulate and fill
					by year: gen cumul_index	= sum(index_corr)
					gen cumul_corr				= cumul_index / check_impl
					by year: egen gain			= sum(implied_gain)
					drop check_impl implied_gain cumul_index index_corr
					
					** New r_house 
					sort t
					gen LY_implied_rent			= L12.implied_rent
					sort year
					by year: egen implied_rent2	= sum(LY_implied_rent)
					drop LY_implied_rent
					replace implied_rent2		= implied_rent2 + gain * cumul_corr // last year rent, plus the monthly portion of the annual gain
					drop gain cumul_corr
					
					** Drop intermediate months with missing index values
					gen missing					= 0
					replace missing				= 1 if rent_index == .
					sort year
					by year: egen dropit		= sum(missing)
					drop if index_hat==. & r_house == .
					drop if dropit > 0   & r_house == .
					drop dropit missing
					
					** Fill monthly r_house
					gen implied_rate 			= implied_rent2 * 12 / house_price
					replace r_house 			= implied_rate if r_house==. & implied_rate ~= .
					drop implied_rent2 implied_rate
					
					** Fill later-years r_house > 2015
					sum implied_rent if year == 2015 & month ==12
					local impl = r(mean)
					sum index_hat  if year == 2015 & month ==12
					local ind = r(mean)
						di "Scaling `ind' to `impl'."
					gen implied_rent3 			= index_hat / `ind' * `impl'
					replace r_house 			= implied_rent3 * 12 / house_price if r_house == . & implied_rent3 ~=.
					rename implied_rent3 net_rent
					drop implied_rent* index_* rent_index
					
					** Order and keep
					order	year month r_house net_rent
					keep 	year month r_house net_rent
					
					** Save for join
					cd_nb_stage
					save r_house_join, replace
					
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
					order h_incl *_orig, last
					
					** Rename
					rename rent_index gross_rent
										
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
				
			} //end if
			di "Done with join for analysis."
					
		} //End if
		di "Done with load."

end
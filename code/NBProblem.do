***********************************************************
***********************************************************
** N-body problem

** Goal: 	Replicate results in "Conservation of capital"

** Inputs:	User settings (see options below)			
**			returns - rore_public_main.dta from Jorda et al. 2017 "Rate of return on everything" QJE 
**			returns - rore_public_supplement.dta, ibid up
**			bonds and equity - https://shillerdata.com/
** 			housing - Moura MC, Smith SJ, Belzer DB. 120 Years of U.S. Residential Housing Stock and Floor Space. PLoS One. 2015 Aug 11;10(8):e0134135. doi: 10.1371/journal.pone.0134135. PMID: 26263391; PMCID: PMC4532357.
**			market cap - Kuvshinov 2022 - The big bang - https://doi.org/10.1016/j.jfineco.2021.09.008
**			market cap - Siblis data https://siblisresearch.com/data/us-stock-market-value/
**			treasuries - Treasury debt outstanding - https://fiscaldata.treasury.gov/datasets/historical-debt-outstanding/historical-debt-outstanding
** Outputs: 
**		Jobs program

** Written: 
**		robin m cross, 3.7.25

** Updated: 

***********************************************************
***********************************************************

***********************************************************
** Data prep, general settings, initial installations
***********************************************************
scalar prep = 1
if prep == 1 {

	***********************************************************
	** Install packages (if needed set inst scalar to 1)
	***********************************************************
	scalar inst = 0
	if inst == 1 {
		
		** Stats command
		ssc install univar
		
		** Margins plot option 1 -- color
		ssc install g538schemes, replace all
		ssc install hettreatreg, all
		
		** Margins plot option 2 -- article
		scalar article_format = 1
		if article_format == 1 {

			capture noisily net install http://www.stata-journal.com/software/sj18-3/gr0073/
			ssc install grstyle, replace
			ssc install palettes, replace
			ssc install colrspace, replace

		} //End if
		di "Done with graph install."

	} //End if
	di "Done with packages install."

	***********************************************************
	** General settings
	***********************************************************
	scalar set = 1 
	if set == 1 {
		
		clear all
		clear matrix
		set matsize 11000, permanently
		set maxvar 32767, permanently
		*set niceness 6
		set max_memory 80g
		set segmentsize 96m  //for large memory computers
		set min_memory 0
		set more off, permanently
		set scrollbufsize 300000
		
		** Margins plot fomat - Figure 2 Income
		scalar article_format = 1
		if article_format == 1 {

			*Graph Settings
			grstyle clear
			set scheme s2color
			grstyle init
			grstyle set plain, box nogrid
			grstyle color background white
			grstyle set color Set1
			grstyle init
	*		grstyle set plain, nogrid noextend
			grstyle yesno draw_major_hgrid yes //no
			grstyle yesno draw_major_ygrid yes //no
			grstyle color major_grid gs8
			grstyle linepattern major_grid dot
			//grstyle set legend 4, box inside
			grstyle color ci_area gs12%50
			//grstyle set nogrid		
			* Style 2
			//grstyle set legend 2
			grstyle set graphsize 10cm 13cm
			grstyle set size 12pt: heading
			grstyle set size 10pt: subheading axis_title
			grstyle set size 8pt: tick_label key_label
			grstyle set symbolsize 1 2 3 4 5, pt
			grstyle set linewidth 0: pmark
			//grstyle set linewidth 1pt: axisline tick major_grid legend xyline
			grstyle set linewidth 2.5pt: plineplot
			grstyle set margin .5cm: twoway               // margin of plot region
			grstyle set margin ".5 1 .75 .25", cm: graph  // margin of graph region
			* Style 3
			grstyle init
			grstyle set plain
			grstyle set color Set1, opacity(50)
			grstyle set symbolsize large
			grstyle set symbol T T
			grstyle anglestyle p2symbol 180
						
		} //End if
		di "Done with graph settings."
		
	} //End if
	di "Done with general settings."

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
			
			** Open Treas data
			cd_nb_source
			import excel "TreasuryDebt", sheet("Debt") firstrow clear
			keep year DebtOut
			renvars *, lower
			order year debtout
			destring *, replace
			
			** Save
			cd_nb_stage
			save debt_out, replace
		
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
				
			** Keep and save
			order 	year month dividend earnings snp500 cpi r_stock r_bond r_price
			keep 	year month dividend earnings snp500 cpi r_stock r_bond r_price
			cd_nb_stage
			save shiller_data, replace
			
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
			
			** Add master time variable t
			sort year month
			gen t								= _n
			
			** Save
			order 	year month t *_orig house_price house_units w_house
			keep	year month t *_orig house_price house_units w_house
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
			joinby year using debt_out, unmatched(master)
				tab _merge
				drop _merge
			gen debt_orig				= (month==12 & debtout~=.)
			
			** Naming - billions
			rename debtout w_bond
			replace w_bond				= w_bond / 1000000000 // convert to billions
			
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
			order year month t *_orig cpi r_price gdp pop w_stock w_bond w_house r_stock r_bond r_house house_price house_units 
			gen h_include 				= (house_price ~=.) 
			
			** Update t
			sort year month
			replace t					= _n
			
			** Save
			cd_nb_stage
			save all_join_temp, replace
			
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
			
		} //end if
		di "Done with join for analysis."
				
	} //End if
	di "Done with load."

} //end if
di "Done with load and prep."


***********************************************************
** Analysis
***********************************************************
scalar runit = 1
if runit == 1 {


	***********************************************************
	** ARIMA
	***********************************************************
	scalar arim = 1 
	if arim == 1 {
		
		** Load main 
		cd_nb_stage
		use analysis_data, clear
			
			** Summary stats
			gen div_shr			= dividend / earnings
			sum year div_* dividend earnings w_stock if year <= 1983 
			sum year div_* dividend earnings w_stock if year > 1983 
			
			
			** Set view periods
			keep if year >= 1890
			gen period 			= 1
			replace period		= 2 if year >= 1930
			replace period		= 3 if year >= 1970
			replace period		= 4 if year >= 2000
			//replace period		= 5 if year >= 2001
			//replace period		= 6 if year >= 2019
			
			** Gen dates
			gen dt 					=	mdy(month,1,year)
			
			replace dt				= dt + 25566
			replace dt 				= dt / 365.25 + 1890
			summarize

			** Graphs settings
			* Style 3
			grstyle init
			grstyle set plain
			grstyle set color Set1, opacity(50)
			grstyle set symbolsize tiny
			grstyle set symbol T T
			grstyle anglestyle p2symbol 180 
			grstyle set grid
			** Additionals
			
			** Real bond rate
			gen rr_bond					= r_bond - r_price
			
			** ARIMA
			tsset t
			** Stock
			** Look
			sum year month t r_stock 										if year >= 1947
			nb_getarima r_stock 2 5 1947					// nb_getarima depvar AR MA first_year
			arima r_stock if year >= 1947, arima(1,1,1)		// AR, Difference, MA
			arima D.r_stock if year >= 1947, ar(1) ma(1)
			** Correlogram
			ac  D.r_stock if year >= 1947, ylabels(-.4(.2).6) name(ac_stock, replace)
			//graph save ac_stock, replace
			pac D.r_stock if year >= 1947, ylabels(-.4(.2).6) name(pac_stock, replace)
			//graph save pac_stock, replace
			graph combine ac_stock pac_stock, rows(2) cols(1)
			** First specification -- 1,3,5,12 interchangeable
			arima D.r_stock if year >= 1947, ar(1 3 12) ma(5)
			arima D.r_stock if year >= 1947, ar(3 12) ma(1 5)
			arima D.r_stock if year >= 1947, ar(3) ma(1 5 12)
		
			** Stock with controls
		
			** Bond
			** Look
			arima rr_bond if year >= 1947, arima(1,1,1)
			** Correlogram
			ac  D.rr_bond if year >= 1947, ylabels(-.4(.2).6) name(ac_bond, replace)
			//graph save ac_bond, replace
			pac D.rr_bond if year >= 1947, ylabels(-.4(.2).6) name(pac_bond, replace)
			//graph save pac_bond, replace
			graph combine ac_bond pac_bond, rows(2) cols(1)
			** First specifications - 1,4,12 interchangeable
			arima D.rr_bond if year >= 1947, ar(4) ma(1 12)
			arima D.rr_bond if year >= 1947, ar(1 4) ma(12)
			arima D.rr_bond if year >= 1947, ar(12) ma(1 4)
		
			** House
			** Look
			arima r_house if year >= 1947, arima(1,1,1)
			** Correlogram
			ac  D.r_house if year >= 1947, ylabels(-.4(.2).6) name(ac_house, replace)
			//graph save ac_house, replace
			pac D.r_house if year >= 1947, ylabels(-.4(.2).6) name(pac_house, replace)
			//graph save pac_house, replace
			graph combine ac_house pac_house, rows(2) cols(1)
			** First specifications 
			//arima D.r_house if year >= 1947, ar(1 2 6 12 18 24 30 35) ma(1 2 10 15)
			arima D.r_house if year >= 1947, ar(1 2 12 35) ma(1 2 10)
			
			** House with controls
			reg r_house rr_bond r_stock if year >= 1947
			arima D.r_house if year >= 1947, ar(1) ma(1)
			arima D.r_house rr_bond r_stock if year >= 1947, ar(1) ma(1)
			
		
			
		
		
			*********************
			** GRAPH
			*********************
			scalar graf = 1
			if graf == 1 {
				
				** Annual
				** Save and combine
				cd_nb_stage
				foreach n of numlist 1/4 {
					
						di "Saving period `n'. Names list is now: `names'."
						
					twoway connected r_stock rr_bond r_house year if period == `n' & month==12, name(period_`n', replace) legend(off) yscale(range(0)) ylabel(-6(2)10) cmissing(n)
					graph save period_`n', replace 
					//graph export period_`n'.png, replace
					local names = "`names'" + "period_`n'.gph "
					
				} //end loop
				di "Done with scatter loop."
				graph combine `names', rows(2) cols(2) 
							
				** Monthly
				** Save and combine
				cd_nb_stage
				foreach n of numlist 1/4 {
					
						di "Saving period `n'. Names list is now: `names'."
						
					twoway connected r_stock rr_bond r_house dt if period == `n', name(period_`n', replace) legend(off) yscale(range(0)) ylabel(-6(2)10) cmissing(n) xlabel()
					graph save period_`n', replace 
					//graph export period_`n'.png, replace
					local names2 = "`names2'" + "period_`n'.gph "
					
				} //end loop
				di "Done with scatter loop."
				graph combine `names2', rows(2) cols(2) 
		
			} //end if
			di "Done with graphs."
						
	} //End if
	di "Done with ARIMA and Graph."

} //end if
di "Done with analysis."

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
			grstyle yesno draw_major_hgrid no //yes
			grstyle yesno draw_major_ygrid no //yes
			grstyle color major_grid gs8
			grstyle linepattern major_grid dot
			grstyle set legend 4, box inside
			grstyle color ci_area gs12%50
			grstyle set nogrid		
			
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
		** Jorda - returns on everything
		****************
		scalar jorda = 1
		if jorda == 1 {
				
			** Load main and save
			cd_nb_jorda
			use rore_public_main, clear

			** Keep
			keep if iso=="USA"
			keep country year housing_rent_yd bond_rate
			cd_nb_stage
			save jorda_main, replace
			
			** Load supplement and join
			cd_nb_jorda
			use rore_public_supplement, clear

			** Keep
			keep if iso=="USA"
			keep country year pop gdp cpi inflation 
			
			** Join
			cd_nb_stage
			joinby country year using jorda_main, unmatched(master)
				tabulate _merge
				drop _merge
				
			** Rename
			rename housing_rent_yd r_house
			rename bond_rate r_bond
			rename inflation r_infl
			
			** Gen population growth rate
			tsset year
			gen r_pop		= (pop - l.pop) / l.pop
		
			** Inflation adjust
			gen rr_bond		= r_bond - r_infl
			
			** Drop 
			drop country
			
			** Stage
			cd_nb_stage
			save jorda_data, replace
			
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

			** Rename
			gen r_stock					= e / p * 0.5
			rename rategs10 r_bond
			replace r_stock 			= r_stock * 100
			** Keep and save
			order year month r_stock r_bond
			keep year month r_stock r_bond
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
			order year month house_units growth source 
			keep year  month house_units	growth
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
			order year month house_units
			keep  year month house_units
			cd_nb_stage
			save housing_units, replace
			
			** Join housing returns
			cd_nb_stage
			joinby year month using shiller_housing, unmatch(master)
				tab _merge
				drop _merge
					
			** Make w_house here
			** Sort and fill and divide and drop
			** Keep house price for r_house at last join!
			** Check the old FRED monthly rents...
			asdf
			
			** Save
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
			
			** Naming (billions)
			rename mcap w_eq
						
			** Join debt outstanding w_debt
			cd_nb_stage
			joinby year using debt_out, unmatched(master)
				tab _merge
				drop _merge
			
			** Naming - billions
			rename debtout w_bond
			replace w_bond				= w_bond / 1000000000 // convert to billions
			
			** Join stock bond returns
			cd_nb_stage
			joinby year month using shiller_data, unmatched(both)
				tab _merge
				drop _merge
				
			** Join house price imputed
			rename r_bond r_bond_shill
			cd_nb_stage
			joinby year using jorda_data, unmatched(both)
				tab _merge
				drop _merge
			
			** Select
			drop r_bond
			rename r_bond_shill r_bond
			
			here_go back and fill in r_house
			** Need pop, gdp, cpi (monthly), rent (monthly), 
			
			
			
			
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
	** Visualize
	***********************************************************
	scalar look = 1 
	if look == 1 {
		
		** Load main 
		cd_nb_stage
		use jorda_data, clear
			
			** Graphs
			graph twoway scatter r_house rr_bond r_pop year if year>= 1900 & year<=1950
			graph twoway scatter r_house r_bond r_pop year if year>= 1950 & year<=2015
			graph twoway scatter r_house r_bond r_pop year if year>= 1987 & year<=2015
			
		
		
		
		
		
	} //End if
	di "Done with look."

} //end if
di "Done with analysis."

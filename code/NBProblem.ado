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
capture program 	drop 	NBProblem
program 			define 	NBProblem

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
			*ssc install xtmixediou
			
			** Margins plot option 2 -- article
			scalar article_format = 1
			if article_format == 1 {

				capture noisily net install http://www.stata-journal.com/software/sj18-3/gr0073/
				ssc install grstyle, replace
				ssc install palettes, replace
				ssc install colrspace, replace
		
			} //End if
			di "Done with graph install."

			** Range join for MFP productivity - not used
			* Install rangejoin if not already present
			//ssc install rangejoin
			//ssc install rangestat
			
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
							
			} //End if
			di "Done with graph settings."
			
		} //End if
		di "Done with general settings."

		***********************************************************
		** Load and prep 
		***********************************************************
		scalar load	= 1
		if load == 1 {
			
			** Download data
			download_prod_fred
			
			** Run twice 	- first annual treasury data
			** 				- second to prep monthly treasuries
			scalar treasmo = 0
			NBPrep
			scalar treasmo = 1
			NBPrep
			
		} //end if
		di "Done with load and prep."

	} //end if
	di "Done with load and prep."

	***********************************************************
	** Analysis & Figures
	***********************************************************
	scalar runit = 1
	if runit == 1 {

		*********************
		** ANALYSIS
		*********************
		scalar arim = 1 
		if arim == 1 {
			
			***************
			** Save annual and monthly
			***************
			scalar annual = 1
			if annual == 1 {
				
				** Load main 
				clear all
				cd_nb_stage
				use analysis_data, clear
				
				** Summary stats
				gen double div_shr			= dividend / earnings
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
									
				** Temp save
				cd_nb_stage
				save temp_save, replace
									
				*******************************
				** Calc Price, quantity, new issue
				** Rocket accretion / ablation
				*******************************
				scalar issue = 1
				if issue == 1 {
					
					** Reload
					cd_nb_stage
					use temp_save, clear
												
					** Bond
					** Rogoff
					** Real bond rate - Rogoff
					gen double rr_bond					= r_bond - r_priceR
					
					** Rename prices
					rename snp500 p_stock
					rename house_price p_house
					
					** Generate quantities
					rename house_units q_house	
					replace q_house 			= q_house / 1000 /1000 			//Billions of units (houses)
					gen double q_stock					= w_stock / p_stock				//billions of (effective) shares
														
					****************
					** Bond accretion
					** Bond monthly doesn't work, due to annual market cap data (replace with monthly bond market cap estimates)
					****************
					** Gen bond price and quantity
					** Use simple PV approach for change in quantity - Notes 4.18.25 p3, updated and corrected 5.28.25 p1
					**Set initial price (each period) at $1000 par value
					gen double q_bond 					= w_bond / 1000	* 1000		//millions of "bonds" - $1000 face value each, or billions of dollars
					** Gen bond - current period issuance - PV method
					** Annual data market capitalization size, monthly rates - Use average current and previous year rate 
					gen double r_current				= r_bond
					gen double q_current				= q_bond
					sort t
					tsset t
					gen double r_prior					= L12.r_current
					gen double q_prior					= L12.q_current				//millions of "bonds" - $1000 face value each, or billions of dollars
					gen double coupon_prior			= r_prior * 10
					gen double coupon_priorm			= L.r_current * 10
					gen double rate_current			= r_current / 100
					** Current value of PRIOR cash flows (prior coupon (r * 10, valued at current rate r)
					** 9 years (of original 10) remaining, but use 10 for price effect, net of duration
					gen double v_cfl					= coupon_prior  * (1- (1+rate_current )^-10) / rate_current 	//per $1000 bond
					gen double v_cflm					= coupon_priorm * (1- (1+rate_current )^-10) / rate_current 	//per $1000 bond
					** Value of return of Face value ($1000) (valued at current rate)
					gen double v_future				= 1000 * (1+rate_current )^-10								//per $1000 bond
					** Gen current price of prior year bonds
					gen double v_total 				= v_cfl + v_future											//per prior year $1000 bond
					gen double v_totalm 				= v_cflm + v_future											//per prior year $1000 bond
					** Current value of all prior period bonds
					gen double v_current				= v_total * q_prior / 1000									//billions of dollars - millions of bonds ($1000 face value)
					gen double v_currentm				= v_totalm * L.q_current / 1000								//billions of dollars - millions of bonds ($1000 face value)
					** New issue - total current value (q_bond * 1000), less value of prior issue
					gen double new_issue				= q_bond - v_current 										//billions of dollars - millions of bonds ($1000 face value)
					gen double new_issue_m				= (q_bond- L.q_bond)										//billions of dollars - millions of bonds ($1000 face value)			
										
					** For accretion
					** Gen current price of prior year bonds
					gen double p_current				= v_total													//per prior year $1000 bond
					gen double p_currentm				= v_totalm													//per prior year $1000 bond
					
					** Change in value of prior year outstanding
					** Capital accretion - Bennet quantity indicator - Cross Fare 2009
					** Decompose accretion - Notes 5.16.25 p.2 
					gen double p_prior					= 1000
					gen double acc_sup_bond			= new_issue 	* (p_current + p_prior) / 2 				//billions of dollars - millions of bonds ($1000 face value)				
					gen double acc_sup_bondm			= new_issue_m 	* (p_currentm + p_prior) / 2				//billions of dollars - millions of bonds ($1000 face value)	
					** Use new issue (q' - q) from line 979 above, but reverse sign (q' + q)
					** Correct 5.29.25 expressed in millions of dollars. 	
					gen double acc_dem_bond			= (p_current - p_prior) 	* (q_bond + v_current) / 2 		// $0.584 x 3460 bonds (in millions of bonds (billions of dollars)) 
					gen double acc_dem_bondm			= (p_currentm - p_prior)	* (q_bond + v_currentm) / 2 	// $0.584 x 3460 bonds (in millions of bonds (billions of dollars)) 
					
					** Order
						order *bond* v_* coupon* rate* *current *prior new*				
					order year month t w_* r_* p_* q_* *_current *_prior new_issue* acc_*
				
					** Clean up bonds
					drop *_prior *_current v_* coupon* rate* *prior 
					rename new_issue  ni_bondy
					rename new_issue_m ni_bondm
						
						sum year month t w_* r_* p_* q_* ni* acc_*
						
						di "Done with bond acc section."
						
					****************
					** Stock accretion
					****************					
					gen double p_current				= p_stock					// Index value (dollars)
					sort t
					tsset t
					gen double p_prior					= L12.p_stock				// dollars
					gen double q_prior					= L12.q_stock				// billions of shares (units)
					gen double new_issue				= q_stock - q_prior 		// directly calculable by S&P share-weighting // billions of shares (units)
					gen double new_issue_m				= (q_stock - L.q_stock)		// billions of shares (units)			
					** Decompose accretion - Notes 5.16.25 p.2 
					gen double acc_sup_stock			= new_issue 	* (p_current + p_prior) / 2 					// quantity change * avg price -- billions of dollars
					gen double acc_sup_stockm			= new_issue_m 	* (p_stock + L.p_stock) / 2						// quantity change * avg price -- billions of dollars
					gen double acc_dem_stock			= (p_current - p_prior) 	*  (q_stock + q_prior) / 2 			// price change * avg qty 	   -- billions of dollars
					gen double acc_dem_stockm			= (p_current - L.p_current) *  (q_stock + L.q_stock) / 2 	// price change * avg qty 	   -- billions of dollars
					
					rename new_issue 	ni_stocky
					rename new_issue_m	ni_stockm
					
					order year month t w_* r_* p_* q_* *_current *_prior acc_* ni_* 
						
					drop *_prior *_current
					
						di "Done with stock acc section."
					
					****************
					** House accretion
					****************	
					gen double p_current				= p_house
					sort t
					tsset t
					gen double p_prior					= L12.p_house				// Dollars
					gen double q_prior					= L12.q_house				// Billions of units (houses) [millions 7.1.25]
					gen double new_issue				= q_house - q_prior 		//directly calculable by S&P share-weighting
					gen double new_issue_m				= (q_house - L.q_house)					
					** Decompose accretion - Notes 5.16.25 p.2 
					gen double acc_sup_house				= new_issue 	* (p_current + p_prior) / 2 			
					gen double acc_sup_housem				= new_issue_m 	* (p_house + L.p_house) / 2
					* Use new issue, but reverse sign for average quantity (q' + q)/2
					gen double acc_dem_house				= (p_current - p_prior) 	* (q_house + q_prior)	/ 2 
					gen double acc_dem_housem				= (p_current - p_prior) 	* (q_house + L.q_house)	/ 2 
					
					rename new_issue 	ni_housey
					rename new_issue_m	ni_housem
					
					****************
					** Price accretion
					****************	
					gen double acc_dem_price 				= 1
					gen double acc_sup_price				= 1
										
					order year month t w_* r_* p_* q_* *_current *_prior acc_* ni_* 
					drop *_prior *_current			
					
				} //end if
				di "Done with new issue."

				** Save monthly 
				cd_nb_stage
				save monthly_data, replace
				use monthly_data, clear
				
				** Look
				sort year month
				tab year
				
				** Save annual
				** Drop months
				keep if month==12
					
				** Save 
				cd_nb_stage
				save annual_data, replace
			
			} //end if
			di "Done with save annual and monthly."
			
			**********************************************
			** Monthly analysis
			**********************************************
			scalar mos = 1
			if mos == 1 {
				
				***************
				** More PREP monthly
				***************
				scalar mprep				= 1
				if mprep == 1 {
						
					** Reload
					cd_nb_stage
					use monthly_data, clear
					
					***************
					** Analysis unit conversion
					** ni_* are billions count (units)
					** acc_* are billion dollars 
					** p_* are dollars
					** r_* are percentage points
					** w_* is market cap in billions of dollars
					***************
					replace q_bond				= q_bond / 1000						// Billions of bonds ($1000 face value each) - trillions of dollars
					replace ni_bondm			= ni_bondy / 1000					// Billions of bonds ($1000 face value each) - trillions of dollars
					drop p_currentm
					rename ni_*y ni_*
					
					** Replace annual with monthly loop
					global assets "stock bond house"
					foreach asset of global assets {
							
						** Rename acc vars to match
						
						foreach var of varlist acc_*_`asset' ni_`asset' {
							
								di "  ++ Beginning variable: `var'."
								
							** Drop and replace var with monthly
							drop `var'
							rename `var'm `var'
													
						} //end loop
						di "Done with replace monthly loop."
						
					} //end loop
					di "Done with globals loop."
									
						sum year month t w_* r_* p_* q_* acc_* ni_* if year>=1948
					
					****************
					** Look at net accretions over time
					****************
								
					** Net accretions
					gen double net_sup_acc 				= acc_sup_bond + acc_sup_stock + acc_sup_house
					gen double net_dem_acc 				= acc_dem_bond + acc_dem_stock + acc_dem_house
					gen double net_acc					= net_sup_acc + net_dem_acc
					
					** Per capita -- $ per person -- ( pop is in 000s , dollar figures are in billions)
					foreach var of varlist net_* acc_* w_* {
						
						gen double cap_`var'			= `var' / (pop * 1000) * 1000000 
						
					} //end loop
					di "Done with per cap vars."
					
					** Summary stats	
					sum year month t pop w_* r_* p_* q_* net_* acc_* cap_* ni_* if year>=1981
									
					** TSSET
					sort year month
					gen n 						= _n
					tsset n
										
					** Save
					cd_nb_stage
					save monthly_temp, replace
				
				} //end if
				di "Done with monthly prep."
										
				******************************
				** N-Body - Combined
				** 1. Rocket
				** 2. 3-Body
				******************************
				scalar nb 					= 1
				if nb == 1 {
				
					** Reload
					cd_nb_stage
					use monthly_temp, clear
					
					**************************
					** Prep Relative distances
					**************************
					global nam "stock bond house price"
					** Stats loop
					** Primary
					foreach pri of global nam {

							di "Primary velocity and accel: `pri'."
							
						******************
						** Variables
						** 5.30.25
						******************						
						
						** Velocity
						gen double v_`pri'				= r_`pri' - L.r_`pri' 
						gen double lag_v_`pri'			= L.v_`pri'
						
						** Acceleration
						gen double a_`pri'				= v_`pri' - L.v_`pri' 
						gen double lag_a_`pri'			= L.a_`pri'
						
						** Jolt (Jerk)
						gen double j_`pri'				= a_`pri' - L.a_`pri' 
						gen double lag_j_`pri'			= L.j_`pri'
						
						** Mass
						gen double m_`pri'				= w_`pri'
						gen double lag_m_`pri'			= L.m_`pri'
						
						** Accretion
						gen double acd_`pri'			= acc_dem_`pri'
						gen double acs_`pri'			= acc_sup_`pri'
						
						** Lagged accretion -- 8.4.25 RC
						gen double lag_acd_`pri'			= L.acc_dem_`pri'
						gen double lag_acs_`pri'			= L.acc_sup_`pri'
						
						** Mass difference and ratio
						** Acceleration
						gen double m_diff_`pri'			= lag_m_`pri' - m_`pri'	
						gen double m_dot_`pri'			= 1 + m_diff_`pri' /  m_`pri'
						** Velocity -- 7.1.25
						gen double m_dot2_`pri'			= 1 + 2 * m_diff_`pri' /  m_`pri'
						** Rate -- added 7.1.25
						gen double lag_r_`pri'			= L.r_`pri'
						gen double lag2_r_`pri'			= L2.r_`pri'
						gen double m_dot3_`pri'			= m_dot_`pri'	 / m_dot2_`pri'	
						gen double m_dot3plus_`pri'		= 1 + m_dot3_`pri'	

						** Composit mass terms for regression
						** Acceleration
						gen double acc_ddot_`pri'		= acd_`pri' / m_`pri' / m_dot_`pri'						//added mass divisor 7.1.25
						gen double acc_sdot_`pri'		= acs_`pri' / m_`pri' / m_dot_`pri'						//added mass divisor 7.1.25
						gen double lag_v_dot_`pri'		= lag_v_`pri' * m_diff_`pri' / m_`pri' / m_dot_`pri'	//added mass divisor 7.1.25
						gen double v_dot_`pri'			= v_`pri' * m_diff_`pri' / m_`pri' / m_dot_`pri'		//added mass divisor 7.1.25
						** Velocity -- added 7.1.25
						gen double acc_ddot2_`pri'		= acd_`pri' / m_`pri' / m_dot2_`pri'					//added mass divisor 7.1.25
						gen double acc_sdot2_`pri'		= acs_`pri' / m_`pri' / m_dot2_`pri'					//added mass divisor 7.1.25
						gen double lag_v_dot2_`pri'		= lag_v_`pri' * m_diff_`pri' / m_`pri' / m_dot2_`pri'	//added mass divisor 7.1.25
						** Rate -- added 7.1.25
						gen double lag_r_dot_`pri'		= lag_r_`pri' * m_dot3plus_`pri'
						gen double lag2_r_dot_`pri'		= lag2_r_`pri' * m_dot3_`pri'
												
					} //end loop
					di "Done with relative distance loop."
					
					foreach pri of global nam {

						** Secondary terms
						foreach sec of global nam  {
							
								di "Starting primary: `pri' and secondary: `sec' section."
							
							******************
							** Two-asset Secondary variables
							******************
							
							** Distance
							gen double d_`sec'_`pri'				= r_`sec' - r_`pri' 
							gen double lag_d_`sec'_`pri'			= L.d_`sec'_`pri'
														
							** Normed distance
							gen double n_`sec'_`pri'				= abs(d_`sec'_`pri')^3
							gen double lag_n_`sec'_`pri'			= L.n_`sec'_`pri'
							
							** Grav terms for regression
							** Acceleration
							gen double grav_term_`sec'_`pri'			= lag_m_`sec' / m_dot_`pri' * lag_d_`sec'_`pri' / lag_n_`sec'_`pri'
							** Velocity
							gen double grav_term2_`sec'_`pri'			= lag_m_`sec' / m_dot2_`pri' * lag_d_`sec'_`pri' / lag_n_`sec'_`pri'
														
						} //end loop
						di "Done with seconary loop for primary: `pri' and sec: `sec'."
						
						** Delete diagonal elements
						drop *_`pri'_`pri'
						
					} //end loop
					di "Done with primary loop: `pri'."
										
					** Drop
					drop r_priceR
					drop m_price
					//drop *_price*
										
						** Order
						order *, alpha
						order *stock* *bond* *house* *price*
						order n t year month dt period r_* v_* a_* j_* m_* acc_* d_* n_* grav_* lag_*
					
						** Look
						sort year month
						scatter r_house r_stock year
						sum month year r_* v_* if r_stock < -10
						sum *_house
					
					** Drop outliers
					** Outliers (data errors)
					*drop if v_house < -0.3
					*drop if a_house < -0.3 | a_house > 0.3
					*drop if j_house < -0.3 | j_house > 0.3
					
					** Include valid monthly
					sort n
					gen incl			= sum(net_include)
						order incl
						
					** Save
					cd_nb_stage
					save arima_data, replace
					use arima_data, clear
														
					////////////
					** Acceleration+ (Velocity of r is (intrinsic) real-acceleration of housing wealth)
					** General rocket + gravity
					////////////
					scalar gen_accel = 1111
					if gen_accel == 1 {
						
						** Load
						cd_nb_stage
						use arima_data, clear
												
						***********
						** House
						***********
					
						** Unconditional ARIMA 
						** r needs incl > 1
						** lag r needs incl > 2
						** v needs incl > 2 + lag
						** a needs incl > 3 + lag
						** j needs incl > 4 + lag
						** lag j needs incl > 5 + lag
						arima j_house if incl > 7, ar(1 2 3) ma() 					
						estat aroots
						arima a_house if incl > 5, ar(1 2) ma() technique(bhhh)
						estat aroots
						arima v_house if incl > 4, ar(1 2) ma() technique(bhhh)
						estat aroots
						arima r_house if incl > 2, ar(1) ma(1) technique(bhhh)
						estat aroots
						** Correlogram
						ac  v_house if incl > 12, ylabels(-.4(.2).6) name(ac_house, replace)
						//graph save ac_house, replace
						pac v_house if incl > 12, ylabels(-.4(.2).6) name(pac_house, replace)
						//graph save pac_house, replace
						graph combine ac_house pac_house, rows(2) cols(1)
						
						** Informed unconditional ARIMA
						arima v_house if incl > 14, ar(1 2 12) ma() technique(bhhh)
						estat aroots
						arima v_house if incl > 14, ar(1 2 10) ma(12) technique(bhhh)
						estat aroots
												
						** Initial reg
						reg v_house grav_term2_stock_house grav_term2_bond_house  ///
							acc_ddot2_house acc_sdot2_house lag_v_dot2_house if incl > 2
							
						** Initial arima
						predict e_house, xb
						replace e_house 				= a_house - e_house		//Convert to error
						** Correlogram
						ac  e_house if incl > 12, ylabels(-.4(.2).6) name(ac_house, replace)
						//graph save ac_house, replace
						pac e_house if incl > 12, ylabels(-.4(.2).6) name(pac_house, replace)
						//graph save pac_house, replace
						graph combine ac_house pac_house, rows(2) cols(1)
						drop e_*
						
						** Conditional ARIMA - does not converge
						arima v_house v_house grav_term2_stock_house grav_term2_bond_house  ///
							acc_ddot2_house acc_sdot2_house lag_v_dot2_house if incl > 14, ar(1 2 12) ma() technique(bhhh)
						estat aroots
						
						** Reload
						cd_nb_stage
						use arima_data, clear
						//drop *_price
							
							** Look
							sort year month
							tab year
							by year: sum r_house j_house m_house r_stock j_stock m_stock
							sum lag_r_* lag_v_* lag_j_* lag_m_* lag_acd_* lag_acs_*
							sum year r_* a_* v_* m_*
												
						** Keep complete data only for balanced OOS testing
						** Drop missing jolt observations (4-months) for balanced OOS run
						global assets "stock bond house"
						global letters "r v a j"
						pause on
						
						foreach asset of global assets {
							
							foreach let of global letters {
														
								reg `let'_`asset' lag_r_* lag_v_* lag_j_* lag_m_* lag_acd_* lag_acs_* if incl > 4
								predict yhat, xb
								gen complete_data	= (yhat~=.)
									sum year yhat complete* 
									*tab year complete_data 
								drop if yhat==.
								drop if `let'_house == .
								drop yhat complete_data
								
								** Look
								*scatter `let'_`asset' year //if  `let'_`asset' < 0.05 &  `let'_`asset' > -0.05
								
								*pause

							} //end loop
							di "Done with letter loop."
							
						} //end loop
						di "Done with asset loop."
																		
						** OOS
						rename incl include
						keep if include > 6		//can use jolt on v if incl > 6
						set seed	101
						gen randsample			= runiform()
						sort randsample
						gen ob					= _n
						sum ob
						local holdout			= 0.50
						local upper				= ceil(r(max) * `holdout')
						gen incl 				= (ob <= `upper')  //Jolt > 4
							di "Upper is `upper', holdout is `holdout'."
							sum ob randsample incl //if year >= 1900
							tab incl //if year >= 1900
						replace incl			= (incl==1 ) //& year >= 1900)

						** Initial rocket-grav reg
						reg v_house grav_term2_stock_house grav_term2_bond_house  ///
							acc_ddot2_house acc_sdot2_house lag_v_dot2_house if (incl)
						fit_nb a_house

						*************************************
						** Approximations
						drop *diff*
						**************************************
						*drop incl 
						*rename include incl
					
						** Order vars for regressions 
						order *stock *bond *house
						order *_r_* *_v_* *_a_* *_j_*
						rename *_r_dot_* *_rdot_*
						rename *_v_dot_* *_vdot_*
						rename *_v_dot2_* *_vdot2_*
						order *_dot*, last
						
						** PCA R Data Output
						cd_nb_stage
						outsheet lag_r_* lag_v_* lag_a_* lag_j_* lag_m_* lag_acd_* lag_acs_* lag_rdot_* lag_vdot_* lag_vdot2_* using NB_R_PCA_vOutput.csv, replace comma
						
						** Prep turingbot
						gen rat_rdot_r_bond_house 					= lag_rdot_bond / lag_rdot_house
						gen rat_rdot_r_stock_house 					= lag_rdot_stock / lag_rdot_house
						gen rat_rdot_m_house_house 					= lag_m_house / lag_rdot_house
						//gen rat_j_rdot_price_bond 				= lag_j_price / lag_rdot_bond
						//gen rat_j_r_price_house 					= lag_j_price / lag_r_house
						gen rat_acd_m_bond_bond 					= lag_acd_bond / lag_m_bond
						gen rat_acs_m_house_bond 					= lag_acs_house / lag_m_bond
						gen rat_acd_m_house_bond 					= lag_acd_house / lag_m_bond
						gen rat_a_rdot_house_bond 					= lag_a_house / lag_rdot_bond
						
						** Save for turingbot
						cd_nb_stage
						save tempm, replace
						use tempm, clear
						** Keep
						keep if include>0
						** Save turingbot
						drop lag_m_price lag_a*_price *vdot*_price *_r_price
						order year month *stock* *bond* *house*
						sort year month
						order year month a_house lag_r_* lag_v_* lag_a_* lag_j_* lag_m_* lag_acd_* lag_acs_* lag_rdot_* lag_vdot_* lag_vdot2_* rat_* 
						keep  v_house lag_r_* lag_v_* lag_a_* lag_j_* lag_m_* lag_acd_* lag_acs_* lag_rdot_* lag_vdot_* lag_vdot2_* rat_*
						** Scale up loop
						foreach var of varlist v_house lag_r_* lag_v_* lag_a_* lag_j_* lag_m_* lag_acd_* lag_acs_* lag_rdot_* lag_vdot_* lag_vdot2_* rat_* {
							
						replace `var' 				= `var' * 100
						
						} //end loop
						di "Done with rescale loop."
						
						** Save
						cd_nb_stage
						savesome * using turingbot_vdatam , replace
						use turingbot_vdatam, clear
						
						** Reload
						cd_nb_stage
						use tempm, clear
						
							** Look
							sort year month
							order year month m_* 
							order year month *_bond
							order year month *_stock
							drop lag_m_price lag_a*_price *vdot*_price *_r_price
							
							** Look
							scatter r_house r_stock year
							sort year
							by year: sum r_*
							
							** Linear 56.76%
							reg v_house lag_r_* lag_v_* lag_a_* lag_j_* lag_m_* lag_acd_* lag_acs_* if (incl) 
							fit_nb v_house 
							
							** 51.12%
							reg j_house lag_r_* lag_v_* lag_a_* lag_j_* lag_m_* lag_acd_* lag_acs_* if (incl)
							fit_nb j_house
						
							** Turing test
							** Bot 68.22% -- 73.02% seed 1011
							reg v_house lag_r_house lag_v_house lag_rdot_house rat_* if (incl==0)
							reg v_house lag_r_house lag_v_house lag_rdot_house rat_* if (incl)
								tab incl
							fit_nb v_house
							** ACD 69.96% -- 74.32% seed 1011 -- 1% loss!
							reg v_house lag_r_house lag_v_house lag_a_house lag_j_house lag_rdot_house rat_* lag_ac*_house lag_ac*_stock lag_m_bond if (incl)
							fit_nb v_house
							** ACD 69.96% -- 74.32% seed 1011 : 1% loss! -- 75.23% seed 101 : 0% loss!
							reg v_house lag_r_house lag_v_house lag_a_house lag_j_house lag_rdot_house rat_* lag_ac*_house lag_acd_stock lag_m_bond if (incl)
							fit_nb v_house
							** ACD 69.96% -- 74.32% seed 1011 : 1% loss! -- 78.60% seed 101 : 0% loss!
							reg v_house lag_r_house lag_v_house lag_j_house lag_rdot_house rat_* lag_acd_stock lag_m_bond if (incl)
							fit_nb v_house
														
							** Initial arima
							predict e_house, xb
							replace e_house 				= a_house - e_house		//Convert to error
							** Correlogram
							ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
							//graph save ac_house, replace
							pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
							//graph save pac_house, replace
							graph combine ac_house pac_house, rows(2) cols(1)
							drop e_*
							
							** Conditional ARIMA
							*arima v_house lag_r_house lag_v_house lag_j_house lag_rdot_house rat_* lag_acd_stock lag_m_bond if (incl) & include>6 , ar(1) ma(3) technique(bhhh)
							*estat aroots
							*arima v_house lag_r_house lag_v_house lag_j_house lag_rdot_house rat_* lag_acd_stock lag_m_bond  , ar(12) ma() technique(bhhh)
							*estat aroots
													
						** PCA R Data Output
						cd_nb_stage
						outsheet lag_r_house lag_v_house lag_j_house lag_rdot_house rat_* lag_acd_stock lag_m_bond using NB_R_PCA_Output.csv, replace comma
							
							** Explore correlations from PCA
							reg lag_r_house lag_rdot_house		//dropping one looses ~24% explanatory value
							
							** Base -- 76.67% seed 101
							reg v_house lag_r_house lag_v_house lag_j_house lag_rdot_house rat_* lag_acd_stock lag_m_bond if (incl)
							fit_nb v_house
							** Less dot -- 52.34% seed 101
							reg v_house lag_v_house lag_j_house lag_rdot_house rat_* lag_acd_stock lag_m_bond if (incl)
							fit_nb v_house
						
						** Generate Expansions
						global nams "stock bond house"
						global namsac "acs acd"
						pause on
					
						** 2nd order  
						** Rate loop -- a housing is non-linear in lagged r housing
						foreach nam of global nams {
							
							reg v_house c.lag_r_`nam'#c.lag_r_`nam' lag_r_* lag_v_* lag_a_* lag_j_* lag_m_* lag_acd_* lag_acs_* if (incl)
							** Plot
							sum lag_r_`nam'
							quietly margins , at(lag_r_`nam' = (4 (0.1) 8) ) 			
							marginsplot, recast(line) recastci(rarea)
							
							* Fit
							fit_nb v_house
							
							//pause
							
						} //end loop
						di "Done with loop expansion check r."
										
						** Mass loop -- linear
						foreach nam of global nams {
							
							reg v_house c.lag_m_`nam'#c.lag_m_`nam' lag_r_* lag_v_* lag_a_* lag_j_* lag_m_* lag_acd_* lag_acs_* if (incl)
							** Plot
							qui margins , at(lag_m_`nam' = (1 (1000) 50000) ) 			
							marginsplot, recast(line) recastci(rarea)
							
							* Fit
							fit_nb v_house
							
							sum lag_m_`nam'
							
							//pause
							
						} //end loop
						di "Done with loop expansion check m."
							
						** Acc loop
						** acs_house (U)
						foreach nam of global nams {
							
							foreach nac of global namsac {
									
									di "Beginnin nam: `nam', nac: `nac'."
								
								reg a_house c.lag_`nac'_`nam'#c.lag_`nac'_`nam' lag_r_* lag_v_* lag_a_* lag_j_* lag_m_* lag_acd_* lag_acs_* if (incl)
								
								** Plot
								quietly margins , at(lag_`nac'_`nam' = (-10000 (1000) 50000) ) 			
								marginsplot, recast(line) recastci(rarea)
								
								* Fit
								fit_nb a_house
								
								sum lag_`nac'_`nam'
								
								//pause
							
							} //end loop ac
							di "Done with AC loop."
							
						} //end loop
						di "Done with loop expansion check acs."
											
							** 2nd order OOS
							reg v_house c.lag_acs_house#c.lag_acs_house lag_r_* lag_v_* lag_a_* lag_j_* lag_m_* lag_acd_* lag_acs_* if (incl)
							fit_nb v_house
							
							** Simple
							** Distance
							reg v_house lag_d_stock_house c.lag_d_bond_house##c.lag_d_bond_house##c.lag_d_bond_house if (incl)
							fit_nb v_house
							** Velocity
							reg v_house lag_v_house if (incl)
							fit_nb v_house
							reg v_house c.lag_v_house##c.lag_v_house if (incl)
							fit_nb v_house
						
					} //end if
					di "Done with Acceleration+."
			
				} //end if
				di "Done with NB combined."	
															
				******************************
				** CAPE and SUR
				******************************
				scalar cape					= 1
				if cape == 1 {
			
					********************************
					** SUR -- Acceleration
					********************************
					** Reload
					cd_nb_stage
					use arima_data, clear
					
					** Initial reg
					reg a_stock grav_term_bond_stock grav_term_house_stock  	///
						acc_ddot_stock acc_sdot_stock lag_v_dot_stock if year >= 1981
					reg a_bond grav_term_stock_bond grav_term_house_bond  		///
						acc_ddot_bond acc_sdot_bond lag_v_dot_bond if year >= 1981	
					reg a_house grav_term_stock_house grav_term_bond_house  	///
						acc_ddot_house acc_sdot_house lag_v_dot_house if year >= 1981
					** SUR
					sureg (a_stock grav_term_bond_stock grav_term_house_stock  	///
						acc_ddot_stock acc_sdot_stock lag_v_dot_stock) 			///
						(a_bond grav_term_stock_bond grav_term_house_bond  		///
						acc_ddot_bond acc_sdot_bond lag_v_dot_bond) 			///
						(a_house grav_term_stock_house grav_term_bond_house 	///
						acc_ddot_house acc_sdot_house lag_v_dot_house) if year >= 1981
										
					********************************
					** Excess Housing CAPE Index 
					** Shiller-prepared data - 17%
					********************************
					cd_nb_stage
					use house_CAPE_reg, clear
					scatter yield returns date
					reg returns yield if date >= 1891.01 & date <= 2014.12 //, vce(rubust)
					
					** Stock CAPE
					local scape = 1
					if `scape' == 1 {
						
						********************************
						** Excess Stock CAPE
						** Shiller-prepared data - 23.5%
						********************************
						use stock_CAPE_reg, clear
							sum *
						scatter yield returns date
						reg returns yield if date >= 1891.01 & date <= 2014.12 //, vce(rubust)
						
						********************************
						** Reproduce Stock CAPE - 28.99 R2
						********************************
						** Reload
						cd_nb_stage
						use arima_data, clear
						
						** Prep for OOS
						rename incl include
						*keep if include > 6		//can use jolt on v if incl > 6

						** Total return forecast
						** TRR "stock" years_future years_past cpi_year cpi_month minimum_n seed
						TRF "stock" 9 3 2024 12 1 101
							
						********************************
						** Gridsearch Years Stock CAPE - R-squared 
						********************************
						matrix table_oos = 	J(10, 35, .)
						matrix table_is = 	table_oos
							matrix list table_oos
							matrix list table_is
							
						** Lookback Loop
						foreach pasty of numlist 1/10 {
							** Lookforward Loop
							foreach futury of numlist 5/35 {
								
								** TRR "stock" years_future years_past cpi_year cpi_month min_n 
								TRF "stock" `futury' `pasty' 2024 12 1 101
								
								matrix table_oos[`pasty',`futury'] 	= r2_0
								matrix table_is[`pasty',`futury']	= r2_1
									
							} //end floop
							di "Done with future loop."
							
						} //end past loop
						di "Done with loops."
						
						matrix list table_oos
						matrix list table_is	
						
						** Save matrix
						clear
						svmat double table_oos, names(futy)
						gen lookback				= _n
						order lookback
						** Save data
						cd_nb_results
						save Stock_CAPE_OOS, replace
						** Save matrix
						clear
						svmat double table_is, names(futy)
						gen lookback				= _n
						order lookback
						** Save data
						cd_nb_results
						save Stock_CAPE_IS, replace
						
						********************************
						** Gridsearch Months Stock CAPE - R-squared 
						********************************
						local gridd = 1
						if `gridd' == 1 {
								
							** Count var
							local counnt 		= 1
							
							** Crude MC search by incrementing seed	
							foreach seed of numlist 1/2 {
								
								
								** Reload
								cd_nb_stage
								use arima_data, clear
								
								** Prep for OOS
								rename incl include
													
								matrix table_oos	 	= 	J(1000, 1000, .)
								matrix table_is 		= 	table_oos
								matrix table_is_beta 	= 	table_oos
								matrix table_is_dw		= 	table_oos
									*matrix list table_oos
									*matrix list table_is
									
								** Check observations
								TRFmox "stock" 120 120 2024 12 1 101 // 276 monthly obs
									scalar list r2_0 r2_1 beta dw	
									
								asdf_combined
								
								TRFmo "stock" 500 600 2024 12 1 101 // 276 monthly obs
									scalar list r2_0 r2_1 beta dw	
								
								
								
								** Lookback Loop
								foreach pasty of numlist 12(60)72 {
									** Lookforward Loop
									foreach futury of numlist 12(60)732 {
										
										** TRR "stock" years_future years_past cpi_year cpi_month min_n 
										TRFmo "stock" `futury' `pasty' 2024 12 1 `seed' //11111
										
										matrix table_oos[`pasty',`futury'] 		= r2_0
										matrix table_is[`pasty',`futury']		= r2_1
										matrix table_is_beta[`pasty',`futury'] 	= beta
										matrix table_is_dw[`pasty',`futury']	= dw
											
									} //end floop
									di "Done with future loop."
									
								} //end past loop
								di "Done with loops."
								
								*matrix list table_oos
								*matrix list table_is	
								
								** Save matrix
								clear
								svmat double table_oos, names(futm)
								gen lookback				= _n
								order lookback
								*drop futm1-futm72					
								** Save data
								cd_nb_stage
								*save Stock_Month_CAPE_OOS, replace
								*use Stock_Month_CAPE_OOS, clear
								
								** Reshape
								rename lookback pastm
								reshape long futm, i(pastm) j(future_month)
								rename futm R2
								drop if R2==.
								
								** Save and Append
								cd_nb_stage
								*save Stock_Month_CAPE_OOS_Long, replace
								** Append
								if `counnt' > 1 {
								
									** Append
									gen seed			= `seed'
									cd_nb_stage
									append using join_master_OOS.dta
									
									** Save
									cd_nb_stage
									save join_master_OOS, replace
																								
								} //end if
								else {
									
									** Save
									gen seed			= `seed'
									cd_nb_stage
									save join_master_OOS, replace
									
								} //end else
								di "Done with save and join."
								
								** Plot
								*twoway contour R2 pastm future_month, levels(30)  zlabel(, format(%9.2f))
								
								** Save matrix
								clear
								svmat double table_is, names(futm)
								gen lookback				= _n
								order lookback
								*drop futm1-futm72					
								** Save data
								cd_nb_stage
								*save Stock_Month_CAPE_IS, replace
								*use Stock_Month_CAPE_IS, clear
								
								** Reshape
								rename lookback pastm
								reshape long futm, i(pastm) j(future_month)
								rename futm R2
								drop if R2==.
								
								** Save and Append
								cd_nb_stage
								*save Stock_Month_CAPE_IS_Long, replace
								** Append
								if `counnt' > 1 {
								
									** Append
									gen seed			= `seed'
									cd_nb_stage
									append using join_master_IS.dta
									
									** Save
									cd_nb_stage
									save join_master_IS, replace
																		
								} //end if
								else {
									
									** Save
									gen seed			= `seed'
									cd_nb_stage
									save join_master_IS, replace
									
								} //end else
								di "Done with save and join."
								
								** Advance count
								local counnt 			= `counnt' + 1
																
							} //end loop
							di "Done with MC loop."

							** Record Stats
							matrix table_oos_R 		= 	J(1000, 1000, .)
							matrix table_is_R 		= 	table_oos
							matrix table_oos_Sig 	= 	table_oos
							matrix table_is_Sig		= 	table_oos
							** Beta and DW
							matrix table_is_beta	= 	table_oos
							matrix table_is_dw		= 	table_oos
							
							** Plot and Save IS
							local IS = 1
							if `IS' == 1 {
							
								** Load
								cd_nb_stage
								use join_master_IS, clear
							
								** Stats Loop
								foreach pasty of numlist 12(60)732 {
									** Lookforward Loop
									foreach futury of numlist 12(60)732 {
										
										** Summary
										sum R2 if pastm == `pasty' & future_month == `futury'
										
										matrix table_is_R[`pasty',`futury'] 	= r(mean)
										matrix table_is_Sig[`pasty',`futury']	= r(sd)
										matrix table_is_beta[`pasty',`futury'] 	= beta
										matrix table_is_dw[`pasty',`futury']	= dw
										
											display "The mean is: " r(mean)
											display "The standard deviation is: " r(sd)
														
									} //end floop
									di "Done with future loop."
									
								} //end past loop
								di "Done with loops."
						
									summarize pastm
									display "The mean is: " r(mean)
									display "The standard deviation is: " r(sd)
									
								** Save IS R matrix
								clear
								svmat double table_is_R, names(futm)
								gen lookback				= _n
								order lookback
								** Reshape
								rename lookback pastm
								reshape long futm, i(pastm) j(future_month)
								rename futm R2
								drop if R2==.
								** Plot R2
								twoway contour R2 pastm future_month, levels(30) zlabel(, format(%9.2f))
								** Save plot
								cd_nb_results
								graph export "contour_plot_IS_R2.png", width(3000)  replace

								** Save IS Sig matrix
								clear
								svmat double table_is_Sig, names(futm)
								gen lookback				= _n
								order lookback
								** Reshape
								rename lookback pastm
								reshape long futm, i(pastm) j(future_month)
								rename futm Sig
								drop if Sig==.
								** Plot R2
								twoway contour Sig pastm future_month, levels(30) zlabel(, format(%9.2f))
								** Save plot
								cd_nb_results
								graph export "contour_plot_IS_Sig.png", width(3000)  replace

							} //end if
							di "Done with IS Plot and Save."
							
							** Plot and Save OOS
							local OOS = 1
							if `OOS' == 1 {
							
								** Load
								cd_nb_stage
								use join_master_OOS, clear
							
								** Stats Loop
								foreach pasty of numlist  12(60)732 {
									** Lookforward Loop
									foreach futury of numlist  12(60)732 {
										
										** Summary
										sum R2 if pastm == `pasty' & future_month == `futury'
										
										matrix table_oos_R[`pasty',`futury'] 	= r(mean)
										matrix table_oos_Sig[`pasty',`futury']	= r(sd)
										
											display "The mean is: " r(mean)
											display "The standard deviation is: " r(sd)
														
									} //end floop
									di "Done with future loop."
									
								} //end past loop
								di "Done with loops."
						
									summarize pastm
									display "The mean is: " r(mean)
									display "The standard deviation is: " r(sd)
									
								** Save OOS R matrix
								clear
								svmat double table_oos_R, names(futm)
								gen lookback				= _n
								order lookback
								** Reshape
								rename lookback pastm
								reshape long futm, i(pastm) j(future_month)
								rename futm R2
								drop if R2==.
								** Plot R2
								twoway contour R2 pastm future_month, levels(30) zlabel(, format(%9.2f))
								** Save plot
								cd_nb_results
								graph export "contour_plot_OOS_R2.png", width(3000)  replace

								** Save OOS Sig matrix
								clear
								svmat double table_oos_Sig, names(futm)
								gen lookback				= _n
								order lookback
								** Reshape
								rename lookback pastm
								reshape long futm, i(pastm) j(future_month)
								rename futm Sig
								drop if Sig==.
								** Plot R2
								twoway contour Sig pastm future_month, levels(30) zlabel(, format(%9.2f))
								** Save plot
								cd_nb_results
								graph export "contour_plot_OOS_Sig.png", width(3000)  replace

							} //end if
							di "Done with OOS Plot and Save."
							
							
								
						} //end if
						di "Done with grid search."
						
							
							asdf_stocks
							
						********************************
						** Bootstrap estimates
						********************************
						** Reload
						cd_nb_stage
						use arima_data, clear
						
						** Prep for OOS
						rename incl include
						
						** TRR "stock" 	years_future 	years_past 	cpi_year	cpi_month 	min_n 	seed
						TRFmo "stock" 	120 			0 			2024 		12 			1 	10 //11111
						*bootstrap att = r2_0, reps(50) seed(1011): TRFmo "house" 336 1 2024 12 679 1011
		
						** Bootstrap 95% CI for OOS R-squared
						matrix table_oos 	= 	J(200, 1, .)
						matrix table_is 	= 	table_oos
						matrix beta_mat		= 	table_is
						
							matrix list table_oos
						
						** Loop
						local sed 			= 1
						scalar mean_oos		= 0
						scalar mean_is		= 0
						scalar mean_beta	= 0
						foreach k of numlist 1/200 {
							
							TRFmo "stock" 336 0 2024 12 679 `sed'
						
							** Record
							matrix table_oos[`sed',1] 	= r2_0
							matrix table_is[`sed',1]	= r2_1
							matrix beta_mat[`sed',1]	= beta
						
							** Advance seed
							local sed 					= `sed' + 1
							scalar mean_oos		= mean_oos + r2_0 
							scalar mean_is		= mean_is + r2_1 
							scalar mean_beta	= mean_beta + beta
							
						} //end loop
						di "Done with CI loop."
						
						** Display CIs
						mata: st_matrix("table_oos", sort(st_matrix("table_oos"), 1))
						mata: st_matrix("table_is", sort(st_matrix("table_is"), 1))
						mata: st_matrix("beta_mat", sort(st_matrix("beta_mat"), 1))
						local mean_oos			= mean_oos / 200
						local mean_is			= mean_is / 200
						local mean_beta			= mean_beta / 200
						local upper_r2_OOS		= table_oos[195,1]
						local lower_r2_OOS		= table_oos[5,1]
						local upper_r2_IS		= table_is[195,1]
						local lower_r2_IS		= table_is[5,1]
						local upper_beta		= beta_mat[195,1]
						local lower_beta		= beta_mat[5,1]
						
							di "MeanOOS: `mean_oos', LowerOOS: `lower_r2_OOS', UpperOOS: `upper_r2_OOS'."
							di "MeanIS: `mean_is', LowerIS: `lower_r2_IS', UpperIS: `upper_r2_IS'."
							di "Betamean: `mean_beta', Lowerbeta: `lower_beta', Upperbeta: `upper_beta'."
												
						
					} //end if
					di "Done with Stock CAPE."
					
					********************************
					** Reproduce House CAPE - R-squared 23.96 obs 1357
					********************************
					** Reload
					cd_nb_stage
					use arima_data, clear
					
					** Prep for OOS
					rename incl include
					
					** Rename - utilize above section code
					** Rename stock terms - forward
					rename dividend temp_div
					rename earnings temp_ern
					//rename p_stock	temp_psto
					** Rename house terms - forward
					//rename p_house p_stock
					rename net_rent dividends
					gen    earnings = dividends
					** Drop first year (invalid data)
					drop if n<=12
					replace n = n - 12
										
					** Total return forecast
					** TRF "asset" 		years_future years_past 	cpi_year cpi_month min_n seed 
					** TRFmo "asset" 	months_future months_past 	cpi_year cpi_month min_n seed
					TRF "house" 	19 	1 	2024 12 679 1011111
					TRFmo "house" 	228 1 	2024 12 679 1011111
					TRFmox "house" 	228 1 	2024 12 679 1011111
					
					********************************
					** Gridsearch Years House CAPE - R-squared 
					********************************
					matrix table_oos = 	J(10, 35, .)
					matrix table_is = 	table_oos
						matrix list table_oos
						matrix list table_is
										
					** Lookback Loop
					foreach pasty of numlist 1/10 {
						** Lookforward Loop
						foreach futury of numlist 25/35 {
							
							** TRR "stock" years_future years_past cpi_year cpi_month min_n 
							TRF "house" `futury' `pasty' 2024 12 679 10 //11111
							
							matrix table_oos[`pasty',`futury'] 	= r2_0
							matrix table_is[`pasty',`futury']	= r2_1
								
						} //end floop
						di "Done with future loop."
						
					} //end past loop
					di "Done with loops."
					
					matrix list table_oos
					matrix list table_is	
					
					** Save matrix
					clear
					svmat double table_oos, names(futy)
					gen lookback				= _n
					order lookback
					** Save data
					cd_nb_results
					save House_CAPE_OOS, replace
					** Save matrix
					clear
					svmat double table_is, names(futy)
					gen lookback				= _n
					order lookback
					** Save data
					cd_nb_results
					save House_CAPE_IS, replace
										
					********************************
					** Gridsearch Months House CAPE - R-squared 
					********************************
					** Reload
					cd_nb_stage
					use arima_data, clear
					
					** Prep for OOS
					rename incl include
					
					** Rename - utilize above section code
					** Rename stock terms - forward
					rename dividend temp_div
					rename earnings temp_ern
					//rename p_stock	temp_psto
					** Rename house terms - forward
					//rename p_house p_stock
					rename net_rent dividends
					gen    earnings = dividends
					** Drop first year (invalid data)
					drop if n<=12
					replace n = n - 12
										
					matrix table_oos = 	J(24, 341, .)
					matrix table_is = 	table_oos
						matrix list table_oos
						matrix list table_is
						
					** Lookback Loop
					foreach pasty of numlist 1/12 {
						** Lookforward Loop
						foreach futury of numlist 321/341 {
							
							** TRR "stock" years_future years_past cpi_year cpi_month min_n 
							TRFmo "house" `futury' `pasty' 2024 12 679 101 //11111
							
							matrix table_oos[`pasty',`futury'] 	= r2_0
							matrix table_is[`pasty',`futury']	= r2_1
								
						} //end floop
						di "Done with future loop."
						
					} //end past loop
					di "Done with loops."
					
					matrix list table_oos
					matrix list table_is	
					
					** Save matrix
					clear
					svmat double table_oos, names(futm)
					gen lookback				= _n
					order lookback
					drop futm1-futm320					
					** Save data
					cd_nb_results
					save House_Month_CAPE_OOS, replace
					** Save matrix
					clear
					svmat double table_is, names(futm)
					gen lookback				= _n
					order lookback
					drop futm1-futm320					
					** Save data
					cd_nb_results
					save House_Month_CAPE_IS, replace
					
					********************************
					** Bootstrap estimates
					********************************
					** Reload
					cd_nb_stage
					use arima_data, clear
					
					** Prep for OOS
					rename incl include
					
					** Rename - utilize above section code
					** Rename stock terms - forward
					rename dividend temp_div
					rename earnings temp_ern
					//rename p_stock	temp_psto
					** Rename house terms - forward
					//rename p_house p_stock
					rename net_rent dividends
					gen    earnings = dividends
					** Drop first year (invalid data)
					drop if n<=12
					replace n = n - 12
					
					** TRR "stock" years_future years_past cpi_year cpi_month min_n 
					TRFmo "house" 336 0 2024 12 679 1011 //11111
					TRFmox "house" 336 0 2024 12 679 1011 //11111
					*bootstrap att = r2_0, reps(50) seed(1011): TRFmo "house" 336 1 2024 12 679 1011
	
					** Bootstrap 95% CI for OOS R-squared
					matrix table_oos 	= 	J(200, 1, .)
					matrix table_is 	= 	table_oos
					matrix beta_mat		= 	table_is
					
						matrix list table_oos
					
					** Loop
					local sed 			= 1
					scalar mean_oos		= 0
					scalar mean_is		= 0
					scalar mean_beta	= 0
					foreach k of numlist 1/200 {
						
						TRFmo "house" 336 0 2024 12 679 `sed'
					
						** Record
						matrix table_oos[`sed',1] 	= r2_0
						matrix table_is[`sed',1]	= r2_1
						matrix beta_mat[`sed',1]	= beta
					
						** Advance seed
						local sed 					= `sed' + 1
						scalar mean_oos		= mean_oos + r2_0 
						scalar mean_is		= mean_is + r2_1 
						scalar mean_beta	= mean_beta + beta
						
					} //end loop
					di "Done with CI loop."
					
					** Display CIs
					mata: st_matrix("table_oos", sort(st_matrix("table_oos"), 1))
					mata: st_matrix("table_is", sort(st_matrix("table_is"), 1))
					mata: st_matrix("beta_mat", sort(st_matrix("beta_mat"), 1))
					local mean_oos			= mean_oos / 200
					local mean_is			= mean_is / 200
					local mean_beta			= mean_beta / 200
					local upper_r2_OOS		= table_oos[195,1]
					local lower_r2_OOS		= table_oos[5,1]
					local upper_r2_IS		= table_is[195,1]
					local lower_r2_IS		= table_is[5,1]
					local upper_beta		= beta_mat[195,1]
					local lower_beta		= beta_mat[5,1]
					
						di "MeanOOS: `mean_oos', LowerOOS: `lower_r2_OOS', UpperOOS: `upper_r2_OOS'."
						di "MeanIS: `mean_is', LowerIS: `lower_r2_IS', UpperIS: `upper_r2_IS'."
						di "Betamean: `mean_beta', Lowerbeta: `lower_beta', Upperbeta: `upper_beta'."
												
					asdf_diff_earnings vs stock earnings
					
				} //end if
				di "Done with CAPE and SUR."
			
				******************************
				** Rogoff 2024 - annual (monthlied)
				******************************
				scalar rog 					= 1
				if rog == 1 {
					
					** Reload
					cd_nb_stage
					use arima_data, clear
					
					** Correlogram - linear detrended data (Rogoff trend)
					** Gen linear detrended bond rate for correlogram - rr_bondt
					//gen trend 					= n
					reg rr_bond t
					predict rr_bondt, xb
					replace rr_bondt 			= rr_bond - rr_bondt
					** Check
						reg rr_bondt rr_bond		
					** Correlogram
					ac  rr_bondt, ylabels(-.4(.2).6) name(ac_bond, replace)
					//graph save ac_bond, replace
					pac rr_bondt, ylabels(-.4(.2).6) name(pac_bond, replace)
					//graph save pac_bond, replace
					graph combine ac_bond pac_bond, rows(2) cols(1)
					drop rr_bondt
					
					** Corelogram-based ARIMA
					arima rr_bond t r_stock r_house, ar(1 2 15) ma(1 16) 
					estat aroots
					
					** Rogoff 2024 stationarity test Table 1
					foreach var of varlist r_* v_* a_* {
						
						** Check stationarity
						dfgls `var', maxlag(3) ers
						
					} //end loop 
					di "Done with check."
										
					** Rogoff 2024 half life Table 4 -- Matlab
					
					** Rogoff 2024 - Figure 1 - Long-run component
					
					** Annual ARIMA
					** Rogoff - max 3
					arima rr_bond t, ar(1 2 3) ma(1 2 3) 
					estat aroots
									
				} //end if
				di "Done with rogoff bonds annual."
			
				******************************
				** Knoll 2017 - annual - VAR (monthlied)
				******************************
				scalar knol 				= 1
				if knol == 1 {
					
					** Reload
					cd_nb_stage
					use arima_data, clear
					
					** Reg
					** rent: price ratio (Knoll 2017 analyzes price:rent)
					reg r_house L.r_house					//Knoll Eqn 3.7 (inverse)
					reg r_house L.r_house, robust
									
					** VAR
					var r_house, lags(1/16) dfk small // Knoll 2017 Table 3.4, Panel B, Column 3
					** Granger test
					vargranger	
					
					** Exented
					** Level
					var r_house r_stock r_bond r_price, lags(1 2 3 6 12 14) dfk small // Knoll 2017 Table 3.4, Panel B, Column 3
					** Granger test
					vargranger				
					** Plot
					irf create var1, step(20) set(myirf) replace
					irf graph oirf, impulse(r_house r_stock r_bond r_price) response(r_house r_stock r_bond r_price) yline(0,lcolor(black)) xlabel(0(3)18) byopts(yrescale)
					
					** Velocity
					var v_* , lags(1 2 3 6 10) dfk small // Knoll 2017 Table 3.4, Panel B, Column 3
					** Granger test
					vargranger	
					** Plot
					irf create var1, step(20) set(myirf) replace
					irf graph oirf, impulse(v_house v_stock v_bond v_price) response(v_house v_stock v_bond v_price) yline(0,lcolor(black)) xlabel(0(3)18) byopts(yrescale)
					
					** Acceleration
					var a_* , lags(1 2 3 6 10) dfk small // Knoll 2017 Table 3.4, Panel B, Column 3
					** Granger test
					vargranger	
					** Plot
					irf create var1, step(20) set(myirf) replace
					irf graph oirf, impulse(a_house a_stock a_bond a_price) response(a_house a_stock a_bond a_price) yline(0,lcolor(black)) xlabel(0(3)18) byopts(yrescale)
					
				} //end if
				di "Done with rogoff bonds annual."
								
				******************************
				** GARCH (monthlied)
				******************************
				scalar garch				= 1
				if garch == 1 {
					
					** Reload
					cd_nb_stage
					use arima_data, clear
					
					** GARCH - stocks and housing
					dvech (r_stock = L.r_stock) (r_house = L.r_house), arch(1) garch(1) 
					** Graph
					predict v*, variance
					tsline  v_r_*  
					twoway connected v_r_* year, name(garch, replace) legend(on) xlabel(1900(25)2025) yscale(range(0)) ylabel(-0.1(0.25)1.15) cmissing(n)
					
					** GARCH bonds
					dvech (r_bond = L.r_bond), arch(1) garch(1) 
					** Graph
					drop v*
					predict v*, variance
					twoway connected v_r_* year, name(garch, replace) legend(on) xlabel(1950(10)2025) yscale(range(0)) ylabel(-0.1(0.5)1.9) cmissing(n)
												
				} //end if
				di "Done with garch."
												
			} //end if
			di "Done with monthly."
					
			**********************************************
			** Annual analysis
			**********************************************
			scalar ans = 1
			if ans == 1 {
							
				** Reload
				cd_nb_stage
				use annual_data, clear
				
				***************
				** Analysis unit conversion
				** ni_* are billions count (units)
				** acc_* are billion dollars 
				** p_* are dollars
				** r_* are percentage points
				** w_* is market cap in billions of dollars
				***************
				replace q_bond				= q_bond / 1000						// Billions of bonds ($1000 face value each) - trillions of dollars
				replace ni_bondy			= ni_bondy / 1000					// Billions of bonds ($1000 face value each) - trillions of dollars
								
				****************
				** Look at net accretions over time
				****************	
				drop acc_*m
				drop ni_*m
				
					sum year month t w_* r_* p_* q_* acc_* ni_* if year>=1948
				
				** Net accretions
				gen double net_sup_acc 				= acc_sup_bond + acc_sup_stock + acc_sup_house
				gen double net_dem_acc 				= acc_dem_bond + acc_dem_stock + acc_dem_house
				gen double net_acc						= net_sup_acc + net_dem_acc
				
				** Per capita -- $ per person -- ( pop is in 000s , dollar figures are in billions)
				foreach var of varlist net_* acc_* w_* {
					
					gen double cap_`var'			= `var' / (pop * 1000) * 1000000 
					
				} //end loop
				di "Done with per cap vars."
				
				** Summary stats	
				sum year month t pop w_* r_* p_* q_* net_* acc_* cap_* ni_* if year>=1981
								
				** TSSET
				sort year
				gen n 						= _n
				tsset n
									
				******************************
				** N-Body - Combined
				** 1. Rocket
				** 2. 3-Body
				******************************
				scalar nb 					= 1
				if nb == 1 {
				
					**************************
					** Prep Relative distances
					**************************
					global nam "stock bond house price"
					** Stats loop
					** Primary
					foreach pri of global nam {

							di "Primary velocity and accel: `pri'."
							
						******************
						** Variables
						** 5.30.25
						******************						
						
						** Velocity
						gen double v_`pri'				= r_`pri' - L.r_`pri' 
						gen double lag_v_`pri'			= L.v_`pri'
						
						** Acceleration
						gen double a_`pri'				= v_`pri' - L.v_`pri' 
						gen double lag_a_`pri'			= L.a_`pri'
						
						** Jolt (Jerk)
						gen double j_`pri'				= a_`pri' - L.a_`pri' 
						gen double lag_j_`pri'			= L.j_`pri'
						
						** Mass
						gen double m_`pri'				= w_`pri'
						gen double lag_m_`pri'			= L.m_`pri'
						
						** Accretion
						gen double acd_`pri'			= acc_dem_`pri'
						gen double acs_`pri'			= acc_sup_`pri'
						
						** Lagged accretion -- 8.4.25 RC
						gen double lag_acd_`pri'			= L.acc_dem_`pri'
						gen double lag_acs_`pri'			= L.acc_sup_`pri'
						
						** Mass difference and ratio
						** Acceleration
						gen double m_diff_`pri'		= lag_m_`pri' - m_`pri'	
						gen double m_dot_`pri'			= 1 + m_diff_`pri' /  m_`pri'
						** Velocity -- 7.1.25
						gen double m_dot2_`pri'		= 1 + 2 * m_diff_`pri' /  m_`pri'
						** Rate -- added 7.1.25
						gen double lag_r_`pri'			= L.r_`pri'
						gen double lag2_r_`pri'		= L2.r_`pri'
						gen double m_dot3_`pri'		= m_dot_`pri'	 / m_dot2_`pri'	
						gen double m_dot3plus_`pri'	= 1 + m_dot3_`pri'	

						** Composit mass terms for regression
						** Acceleration
						gen double acc_ddot_`pri'		= acd_`pri' / m_`pri' / m_dot_`pri'						//added mass divisor 7.1.25
						gen double acc_sdot_`pri'		= acs_`pri' / m_`pri' / m_dot_`pri'						//added mass divisor 7.1.25
						gen double lag_v_dot_`pri'		= lag_v_`pri' * m_diff_`pri' / m_`pri' / m_dot_`pri'	//added mass divisor 7.1.25
						gen double v_dot_`pri'			= v_`pri' * m_diff_`pri' / m_`pri' / m_dot_`pri'		//added mass divisor 7.1.25
						** Velocity -- added 7.1.25
						gen double acc_ddot2_`pri'		= acd_`pri' / m_`pri' / m_dot2_`pri'					//added mass divisor 7.1.25
						gen double acc_sdot2_`pri'		= acs_`pri' / m_`pri' / m_dot2_`pri'					//added mass divisor 7.1.25
						gen double lag_v_dot2_`pri'	= lag_v_`pri' * m_diff_`pri' / m_`pri' / m_dot2_`pri'	//added mass divisor 7.1.25
						** Rate -- added 7.1.25
						gen double lag_r_dot_`pri'		= lag_r_`pri' * m_dot3plus_`pri'
						gen double lag2_r_dot_`pri'	= lag2_r_`pri' * m_dot3_`pri'
												
					} //end loop
					di "Done with relative distance loop."
					
					foreach pri of global nam {

						** Secondary terms
						foreach sec of global nam  {
							
								di "Starting primary: `pri' and secondary: `sec' section."
							
							******************
							** Two-asset Secondary variables
							******************
							
							** Distance
							gen double d_`sec'_`pri'				= r_`sec' - r_`pri' 
							gen double lag_d_`sec'_`pri'			= L.d_`sec'_`pri'
														
							** Normed distance
							gen double n_`sec'_`pri'				= abs(d_`sec'_`pri')^3
							gen double lag_n_`sec'_`pri'			= L.n_`sec'_`pri'
							
							** Grav terms for regression
							** Acceleration
							gen double grav_term_`sec'_`pri'			= lag_m_`sec' / m_dot_`pri' * lag_d_`sec'_`pri' / lag_n_`sec'_`pri'
							** Velocity
							gen double grav_term2_`sec'_`pri'			= lag_m_`sec' / m_dot2_`pri' * lag_d_`sec'_`pri' / lag_n_`sec'_`pri'
														
						} //end loop
						di "Done with seconary loop for primary: `pri' and sec: `sec'."
						
						** Delete diagonal elements
						drop *_`pri'_`pri'
						
					} //end loop
					di "Done with primary loop: `pri'."
										
					** Drop
					drop r_priceR
					drop m_price
					//drop *_price*
										
						** Order
						order *, alpha
						order *stock* *bond* *house* *price*
						order n t year month dt period r_* v_* a_* j_* m_* acc_* d_* n_* grav_* lag_*
						
					** Save
					cd_nb_stage
					save arima_data, replace
														
					////////////
					** Acceleration
					** General rocket + gravity
					////////////
					scalar gen_accel = 1111
					if gen_accel == 1 {
						
						** Load
						cd_nb_stage
						use arima_data, clear
												
						***********
						** House
						***********
						
						** Initial reg
						reg a_house grav_term_stock_house grav_term_bond_house  ///
							acc_ddot_house acc_sdot_house lag_v_dot_house if year >= 1981
							
						** Initial arima
						predict e_house, xb
						replace e_house 				= a_house - e_house		//Convert to error
						** Correlogram
						ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
						//graph save ac_house, replace
						pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
						//graph save pac_house, replace
						graph combine ac_house pac_house, rows(2) cols(1)
						drop e_*
						
						** ARIMA
						arima a_house grav_term_stock_house grav_term_bond_house  ///
							acc_ddot_house acc_sdot_house lag_v_dot_house if year >= 1981, ar(1) ma() 
						estat aroots	
						arima a_house grav_term_stock_house grav_term_bond_house  ///
							acc_ddot_house acc_sdot_house lag_v_dot_house if year >= 1981, ar() ma(1) 
						estat aroots	
						arima a_house grav_term_stock_house grav_term_bond_house  ///
						acc_ddot_house acc_sdot_house lag_v_dot_house if year >= 1981, ar(1) ma(1) 
						estat aroots	
						
						** Net v_dot term
						gen double net_a_house			= a_house - 4.4 * v_dot_house
						reg net_a_house grav_term_stock_house grav_term_bond_house  ///
							acc_ddot_house acc_sdot_house if year >= 1981
							
						** Initial arima
						predict e_house, xb
						replace e_house 				= a_house - e_house		//Convert to error
						** Correlogram
						ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
						//graph save ac_house, replace
						pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
						//graph save pac_house, replace
						graph combine ac_house pac_house, rows(2) cols(1)
						drop e_*	
							
						** ARIMA
						arima net_a_house grav_term_stock_house grav_term_bond_house  ///
							acc_ddot_house acc_sdot_house if year >= 1981, ar(1) ma() 
						estat aroots	
																											
						***********
						** Stock
						***********
						
						** Initial reg
						reg a_stock grav_term_bond_stock grav_term_house_stock  ///
							acc_ddot_stock acc_sdot_stock lag_v_dot_stock if year >= 1981
							
						** Initial arima
						predict e_stock, xb
						replace e_stock 				= a_stock - e_stock		//Convert to error
						** Correlogram
						ac  e_stock, ylabels(-.4(.2).6) name(ac_stock, replace)
						//graph save ac_stock, replace
						pac e_stock, ylabels(-.4(.2).6) name(pac_stock, replace)
						//graph save pac_stock, replace
						graph combine ac_stock pac_stock, rows(2) cols(1)
						drop e_*
						
						** ARIMA
						arima a_stock grav_term_bond_stock grav_term_house_stock  ///
							acc_ddot_stock acc_sdot_stock lag_v_dot_stock if year >= 1981, ar(1) ma() 
						estat aroots	
						
						** Net v_dot term
						gen double net_a_stock			= a_stock - 4.0 * v_dot_stock
						reg net_a_stock grav_term_bond_stock grav_term_house_stock  ///
							acc_ddot_stock acc_sdot_stock if year >= 1981
						
						** Initial arima
						predict e_stock, xb
						replace e_stock 				= a_stock - e_stock		//Convert to error
						** Correlogram
						ac  e_stock, ylabels(-.4(.2).6) name(ac_stock, replace)
						//graph save ac_stock, replace
						pac e_stock, ylabels(-.4(.2).6) name(pac_stock, replace)
						//graph save pac_stock, replace
						graph combine ac_stock pac_stock, rows(2) cols(1)
						drop e_*
						
						** ARIMA
						arima net_a_stock grav_term_bond_stock grav_term_house_stock  ///
							acc_ddot_stock acc_sdot_stock if year >= 1981, ar(1) ma() 
						estat aroots	
											
						***********
						** Bond
						***********
													
						** Initial reg
						reg a_bond grav_term_stock_bond grav_term_house_bond  ///
							acc_ddot_bond acc_sdot_bond lag_v_dot_bond if year >= 1981
							
						** Initial arima
						predict e_bond, xb
						replace e_bond 				= a_bond - e_bond		//Convert to error
						** Correlogram
						ac  e_bond, ylabels(-.4(.2).6) name(ac_bond, replace)
						//graph save ac_bond, replace
						pac e_bond, ylabels(-.4(.2).6) name(pac_bond, replace)
						//graph save pac_bond, replace
						graph combine ac_bond pac_bond, rows(2) cols(1)
						drop e_*
						
						** ARIMA
						arima a_bond grav_term_stock_bond grav_term_house_bond  ///
							acc_ddot_bond acc_sdot_bond lag_v_dot_bond if year >= 1981, ar(1) ma() 
						estat aroots	
						arima a_bond grav_term_stock_bond grav_term_house_bond  ///
							acc_ddot_bond acc_sdot_bond lag_v_dot_bond if year >= 1981, ar() ma(1) 
						estat aroots	
						
						** Net v_dot term
						gen double net_a_bond			= a_bond - 7.2 * v_dot_bond
						reg net_a_bond grav_term_stock_bond grav_term_house_bond  ///
							acc_ddot_bond acc_sdot_bond if year >= 1981
							
						** Initial arima
						predict e_bond, xb
						replace e_bond 				= a_bond - e_bond		//Convert to error
						** Correlogram
						ac  e_bond, ylabels(-.4(.2).6) name(ac_bond, replace)
						//graph save ac_bond, replace
						pac e_bond, ylabels(-.4(.2).6) name(pac_bond, replace)
						//graph save pac_bond, replace
						graph combine ac_bond pac_bond, rows(2) cols(1)
						drop e_*
							
						** ARIMA
						arima net_a_bond grav_term_stock_bond grav_term_house_bond  ///
							acc_ddot_bond acc_sdot_bond if year >= 1981, ar(1) ma() 
						estat aroots	
						arima net_a_bond grav_term_stock_bond grav_term_house_bond  ///
							acc_ddot_bond acc_sdot_bond if year >= 1981, ar() ma(1) 
						estat aroots		
						arima net_a_bond grav_term_stock_bond grav_term_house_bond  ///
						acc_ddot_bond acc_sdot_bond if year >= 1981, ar(1) ma(2) 
						estat aroots		
						
						***********
						** SUR
						***********
						** Initial reg
						reg a_stock grav_term_bond_stock grav_term_house_stock  	///
							acc_ddot_stock acc_sdot_stock lag_v_dot_stock if year >= 1981
						reg a_bond grav_term_stock_bond grav_term_house_bond  		///
							acc_ddot_bond acc_sdot_bond lag_v_dot_bond if year >= 1981	
						reg a_house grav_term_stock_house grav_term_bond_house  	///
							acc_ddot_house acc_sdot_house lag_v_dot_house if year >= 1981
						** SUR
						sureg (a_stock grav_term_bond_stock grav_term_house_stock  	///
							acc_ddot_stock acc_sdot_stock lag_v_dot_stock) 			///
							(a_bond grav_term_stock_bond grav_term_house_bond  		///
							acc_ddot_bond acc_sdot_bond lag_v_dot_bond) 			///
							(a_house grav_term_stock_house grav_term_bond_house 	///
							acc_ddot_house acc_sdot_house lag_v_dot_house) if year >= 1981
						
					} //end if
					di "Done with Acceleration."
				
					////////////
					** Velocity
					** General rocket + gravity
					////////////
					scalar gen_vel = 1111
					if gen_vel == 1 {
						
						** Load
						cd_nb_stage
						use arima_data, clear
													
						***********
						** House
						***********
						
						** Initial reg
						reg v_house grav_term2_stock_house grav_term2_bond_house  ///
							acc_ddot2_house acc_sdot2_house lag_v_dot2_house if year >= 1981
							
						** Initial arima
						predict e_house, xb
						replace e_house 				= a_house - e_house		//Convert to error
						** Correlogram
						ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
						//graph save ac_house, replace
						pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
						//graph save pac_house, replace
						graph combine ac_house pac_house, rows(2) cols(1)
						drop e_*
						
						** ARIMA
						arima v_house grav_term2_stock_house grav_term2_bond_house  ///
							acc_ddot2_house acc_sdot2_house lag_v_dot2_house if year >= 1981, ar(1) ma() 
						estat aroots	
																
						***********
						** Stock
						***********
						
						** Initial reg
						reg v_stock grav_term2_bond_stock grav_term2_house_stock  ///
							acc_ddot2_stock acc_sdot2_stock lag_v_dot2_stock if year >= 1981
							
						** Initial arima
						predict e_stock, xb
						replace e_stock 				= v_stock - e_stock		//Convert to error
						** Correlogram
						ac  e_stock, ylabels(-.4(.2).6) name(ac_stock, replace)
						//graph save ac_stock, replace
						pac e_stock, ylabels(-.4(.2).6) name(pac_stock, replace)
						//graph save pac_stock, replace
						graph combine ac_stock pac_stock, rows(2) cols(1)
						drop e_*
						
						** ARIMA
						arima v_stock grav_term2_bond_stock grav_term2_house_stock  ///
							acc_ddot2_stock acc_sdot2_stock lag_v_dot2_stock if year >= 1981, ar(2) ma() 
						estat aroots	
						arima v_stock grav_term2_bond_stock grav_term2_house_stock  ///
							acc_ddot2_stock acc_sdot2_stock lag_v_dot2_stock if year >= 1981, ar() ma(2) 
						estat aroots	
																							
						***********
						** Bond
						***********
													
						** Initial reg
						reg v_bond grav_term2_stock_bond grav_term2_house_bond  ///
							acc_ddot2_bond acc_sdot2_bond lag_v_dot2_bond if year >= 1981
							
						** Initial arima
						predict e_bond, xb
						replace e_bond 				= v_bond - e_bond		//Convert to error
						** Correlogram
						ac  e_bond, ylabels(-.4(.2).6) name(ac_bond, replace)
						//graph save ac_bond, replace
						pac e_bond, ylabels(-.4(.2).6) name(pac_bond, replace)
						//graph save pac_bond, replace
						graph combine ac_bond pac_bond, rows(2) cols(1)
						drop e_*
						
						** ARIMA
						arima v_bond grav_term2_stock_bond grav_term2_house_bond  ///
							acc_ddot2_bond acc_sdot2_bond lag_v_dot2_bond if year >= 1981, ar() ma(1) 
						estat aroots	
						
					} //end if
					di "Done with Velocity."
				
					////////////
					** Rate r
					** General rocket + gravity
					////////////
					scalar gen_rate = 1
					if gen_rate == 1 {
						
						** Load
						cd_nb_stage
						use arima_data, clear
						
						** Save turingbot
						order *stock* *bond* *house*
						order year r_* v_* a_* lag_r_* lag_v_* lag_a_* lag_m_* lag_acd_* lag_acs_*
						keep year r_* v_* a_* lag_r_* lag_v_* lag_a_* lag_m_* lag_acd_* lag_acs_*
						drop *dot*
						drop *price*
						drop if lag_m_stock == .
						cd_nb_stage
						save turingbot_data, replace
						use turingbot_data, clear
						
							drop if year < 1948
							drop r_stock r_bond r_house v_stock v_bond a_stock a_bond a_house
							replace v_house 			= v_house * 100
							
						** Load
						cd_nb_stage
						use arima_data, clear
													
						***********
						** House
						***********
						
						** Initial reg
						reg r_house grav_term2_stock_house grav_term2_bond_house  ///
							acc_ddot2_house acc_sdot2_house lag_r_dot_house lag2_r_dot_house if year >= 1949, noconstant
							
						** Initial arima
						predict e_house, xb
						replace e_house 				= a_house - e_house		//Convert to error
						** Correlogram
						ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
						//graph save ac_house, replace
						pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
						//graph save pac_house, replace
						graph combine ac_house pac_house, rows(2) cols(1)
						drop e_*
						
						** ARIMA
						** House rate rocket equation is AR-1 stationary in conditioned expression (already includes some lag terms) 
						arima r_house grav_term2_stock_house grav_term2_bond_house  ///
							acc_ddot2_house acc_sdot2_house lag_r_dot_house lag2_r_dot_house if year >= 1981, ar(1) ma() 
						estat aroots	
						arima r_house grav_term2_stock_house grav_term2_bond_house  ///
							acc_ddot2_house acc_sdot2_house lag_r_dot_house lag2_r_dot_house if year >= 1981, ar(2) ma() 
						estat aroots	
						arima r_house grav_term2_stock_house grav_term2_bond_house  ///
							acc_ddot2_house acc_sdot2_house lag_r_dot_house lag2_r_dot_house if year >= 1981, ar() ma(1) 
						estat aroots	
										
						** Reload
						cd_nb_stage
						use arima_data, clear
											
						** Approximations
						set seed	101
						gen double randsample			= runiform()
						sort randsample
						gen ob					= _n
						sum ob
						local holdout			= 0.70
						local upper				= ceil(r(max) * `holdout')
						gen incl 				= (ob <= `upper')
							di "Upper is `upper', holdout is `holdout'."
							sum ob randsample incl if year >= 1900
							tab incl if year >= 1900
						replace incl			= (incl==1 & year >= 1900)
						//replace incl			= (incl==1)
												
						** Linear -- 46.76% loss, 85.66% velocity, 84.21% accel. // 43.87%, 73.6%, 86.6% 1949 //13.95 16.22 68.7 1900
						reg r_house lag_r_bond lag_r_stock lag_r_house lag_m_stock lag_m_bond lag_m_house lag_acd_stock lag_acs_stock lag_acd_bond lag_acs_bond lag_acd_house lag_acs_house if (incl)
						fit_nb r_house 
												
						reg v_house lag_r_bond lag_r_stock lag_r_house lag_m_stock lag_m_bond lag_m_house lag_acd_stock lag_acs_stock lag_acd_bond lag_acs_bond lag_acd_house lag_acs_house if (incl)
						fit_nb v_house 
						
						reg a_house lag_r_bond lag_r_stock lag_r_house lag_m_stock lag_m_bond lag_m_house lag_acd_stock lag_acs_stock lag_acd_bond lag_acs_bond lag_acd_house lag_acs_house if (incl)
						fit_nb a_house 
						
						** Test Expansion
						** larger -- 46.18% loss 1981, 45.3% 1949, 12.62% 1900
						reg r_house lag_r_bond lag_r_stock lag_r_house c.lag_m_stock#c.lag_m_stock lag_m_bond c.lag_m_house#c.lag_m_house c.lag_acd_stock#c.lag_acd_stock c.lag_acs_stock#c.lag_acs_stock lag_acd_bond ///
							lag_acs_bond c.lag_acd_house##c.lag_acd_house c.lag_acs_house#c.lag_acs_house if (incl)
						fit_nb r_house
						** smaller -- 41.19% loss 1981, 45.1% 1949, 14.65% 1900
						reg r_house lag_r_bond lag_r_stock lag_r_house lag_m_stock lag_m_bond lag_m_house lag_acd_stock c.lag_acs_stock#c.lag_acs_stock lag_acd_bond ///
							lag_acs_bond c.lag_acd_house##c.lag_acd_house c.lag_acs_house#c.lag_acs_house if (incl)
						fit_nb r_house
						
						** Generate Expansions
						global nams "stock bond house"
						global namsac "acs acd"
						pause on
					
						** 2nd order  
						** Rate loop -- no value add -- housing rate is linear in lagged housing rate
						foreach nam of global nams {
							
							reg r_house c.lag_r_`nam'##c.lag_r_`nam' lag_r_bond lag_r_stock lag_r_house lag_m_stock lag_m_bond lag_m_house lag_acd_stock lag_acs_stock lag_acd_bond lag_acs_bond lag_acd_house lag_acs_house if year >= 1981
							** Plot
							sum lag_r_`nam'
							quietly margins , at(lag_r_`nam' = (4 (0.1) 8) ) 			
							marginsplot, recast(line) recastci(rarea)
							
							* Fit
							fit_nb r_house
							
							//pause
							
						} //end loop
						di "Done with loop expansion check r."
										
						** Mass loop
						** stock mass - U - almost no lin
						** U housing mass - plus lin
						foreach nam of global nams {
							
							reg r_house c.lag_m_`nam'#c.lag_m_`nam' lag_r_bond lag_r_stock lag_r_house lag_m_stock lag_m_bond lag_m_house lag_acd_stock lag_acs_stock lag_acd_bond lag_acs_bond lag_acd_house lag_acs_house if year >= 1981
							** Plot
							qui margins , at(lag_m_`nam' = (1 (1000) 50000) ) 			
							marginsplot, recast(line) recastci(rarea)
							
							//pause
							
						} //end loop
						di "Done with loop expansion check m."
							
						** Acc loop
						** U in lag_acd_stock - no lin
						** U in acd_house - plus lin
						** Inverse U in acs_stock, acs_house - no lin
						** Decr in acd_house, acd_bond (or U)
						foreach nam of global nams {
							
							foreach nac of global namsac {
									
									di "Beginnin nam: `nam', nac: `nac'."
								
								reg r_house c.lag_`nac'_`nam'#c.lag_`nac'_`nam' lag_r_bond lag_r_stock lag_r_house lag_m_stock lag_m_bond lag_m_house lag_acd_stock lag_acs_stock lag_acd_bond lag_acs_bond lag_acd_house lag_acs_house if year >= 1981
								
								** Plot
								quietly margins , at(lag_`nac'_`nam' = (-1000000 (10000) 1000000) ) 			
								marginsplot, recast(line) recastci(rarea)
								
									sum lag_`nac'_`nam' year r_house

								//pause
							
							} //end loop ac
							di "Done with AC loop."
							
						} //end loop
						di "Done with loop expansion check acs."
						
						** Resulting 2nd-order terms
						reg r_house lag_r_bond lag_r_stock lag_r_house c.lag_m_stock#c.lag_m_stock lag_m_bond c.lag_m_house#c.lag_m_house c.lag_acd_stock#c.lag_acd_stock c.lag_acs_stock#c.lag_acs_stock lag_acd_bond ///
							lag_acs_bond c.lag_acd_house##c.lag_acd_house c.lag_acs_house#c.lag_acs_house if year >= 1981
						reg r_house lag_r_bond lag_r_stock lag_r_house c.lag_m_stock lag_m_bond c.lag_m_house c.lag_acd_stock c.lag_acs_stock#c.lag_acs_stock lag_acd_bond ///
							lag_acs_bond c.lag_acd_house##c.lag_acd_house c.lag_acs_house#c.lag_acs_house if year >= 1949
						
						** Check sig 2nd-order effects
						sum lag_m_stock lag_m_house lag_acd_stock lag_acs_stock lag_acd_house lag_acs_house if year >= 1949
						** Stock m - none
						quietly margins , at(lag_m_stock = (2000 (1000) 50000) ) 		
						marginsplot, recast(line) recastci(rarea)
						** House m - none
						quietly margins , at(lag_m_house = (5000 (1000) 50000) ) 		
						marginsplot, recast(line) recastci(rarea)
						** Stock acd - none
						quietly margins , at(lag_acd_stock = (-8000 (100) 10000) ) 		
						marginsplot, recast(line) recastci(rarea)
						** Stock acs - none -- now yes
						quietly margins , at(lag_acs_stock = (-3000 (100) 2000) ) 		
						marginsplot, recast(line) recastci(rarea)
						** House acd - yes
						quietly margins , at(lag_acd_house = (-3000000 (100000) 7000000) ) 		
						marginsplot, recast(line) recastci(rarea)
						** House acs - none
						quietly margins , at(lag_acs_house = (-40000 (10000) 500000) ) 		
						marginsplot, recast(line) recastci(rarea)
						
						** 2nd order OOS
						reg r_house lag_r_bond lag_r_stock lag_r_house c.lag_m_stock lag_m_bond c.lag_m_house c.lag_acd_stock c.lag_acs_stock#c.lag_acs_stock lag_acd_bond ///
							lag_acs_bond c.lag_acd_house##c.lag_acd_house c.lag_acs_house#c.lag_acs_house if year >= 1949
						
						asdf_nonlin	
						
						***********
						** Stock
						***********
						
						** Initial reg
						reg r_stock grav_term2_bond_stock grav_term2_house_stock  ///
							acc_ddot2_stock acc_sdot2_stock lag_r_dot_stock lag2_r_dot_stock if year >= 1981
							
						** Initial arima
						predict e_stock, xb
						replace e_stock 				= v_stock - e_stock		//Convert to error
						** Correlogram
						ac  e_stock, ylabels(-.4(.2).6) name(ac_stock, replace)
						//graph save ac_stock, replace
						pac e_stock, ylabels(-.4(.2).6) name(pac_stock, replace)
						//graph save pac_stock, replace
						graph combine ac_stock pac_stock, rows(2) cols(1)
						drop e_*
						
						** ARIMA
																					
						***********
						** Bond
						***********
													
						** Initial reg
						reg r_bond grav_term2_stock_bond grav_term2_house_bond  ///
							acc_ddot2_bond acc_sdot2_bond lag_r_dot_bond lag2_r_dot_bond if year >= 1981
							
						** Initial arima
						predict e_bond, xb
						replace e_bond 				= v_bond - e_bond		//Convert to error
						** Correlogram
						ac  e_bond, ylabels(-.4(.2).6) name(ac_bond, replace)
						//graph save ac_bond, replace
						pac e_bond, ylabels(-.4(.2).6) name(pac_bond, replace)
						//graph save pac_bond, replace
						graph combine ac_bond pac_bond, rows(2) cols(1)
						drop e_*
						
						** ARIMA
						arima r_bond grav_term2_stock_bond grav_term2_house_bond  ///
							acc_ddot2_bond acc_sdot2_bond lag_r_dot_bond lag2_r_dot_bond if year >= 1981, ar(1) ma() 
						estat aroots	
						arima r_bond grav_term2_stock_bond grav_term2_house_bond  ///
							acc_ddot2_bond acc_sdot2_bond lag_r_dot_bond lag2_r_dot_bond if year >= 1981, ar() ma(1) 
						estat aroots
						arima r_bond grav_term2_stock_bond grav_term2_house_bond  ///
							acc_ddot2_bond acc_sdot2_bond lag_r_dot_bond lag2_r_dot_bond if year >= 1981, ar() ma(1 2 3) 
						estat aroots
						arima r_bond grav_term2_stock_bond grav_term2_house_bond  ///
							acc_ddot2_bond acc_sdot2_bond lag_r_dot_bond lag2_r_dot_bond if year >= 1981, ar() ma(2) 
						estat aroots
						
						** Approximations
						
												
						***********
						** Ornstein-Uhlenbeck model
						** Continuous time analog to the AR(1)
						** William Smith, February 2010, On the Simulation and Estimation of the Mean-Reverting Ornstein-Uhlenbeck Process
						***********
						scalar orn == 1
						if orn == 1 {
							
						** Load
						cd_nb_stage
						use arima_data, clear
								
							**********	
							** Stock
							** Naive LS
							** Initial reg
							reg v_stock lag_r_stock if year >= 1981
							* lamda = b
							nlcom _b[lag_r_stock]
							* mu = a / b
							nlcom _b[_cons] /  _b[lag_r_stock]
							* sigma = se(Epsilon)
							local sde = e(rmse)
								di "sde: `sde'."
							scalar sde = e(rmse)
								scalar list sde
							** Exact LS
							** Initial reg
							reg r_stock lag_r_stock if year >= 1981
							* lamda = -ln(b)
							nlcom -1*ln(_b[lag_r_stock]) 
							* mu = a / (1-b)
							nlcom _b[_cons] /  (1 - _b[lag_r_stock])
							* sigma = f(Epsilon, mu, lamda)
							scalar sde = e(rmse)
								scalar list sde
							nlcom sde * sqrt( 2 * (-1*ln(_b[lag_r_stock])/*end ln*/)/*end lambda*/ / (1-exp(-1 * 2* (-1*ln(_b[lag_r_stock])/*end ln*/)/*end lambda*/ )/*end exp*/)/*end denom*/) /*end sqrt*/
								
							** Compare to AR(1)
							** Correlogram
							ac  r_stock, ylabels(-.4(.2).6) name(ac_stock, replace)
							pac r_stock, ylabels(-.4(.2).6) name(pac_stock, replace)
							//graph save pac_stock, replace
							graph combine ac_stock pac_stock, rows(2) cols(1)
							** ARIMA
							arima r_stock if year >= 1981, ar(1) ma() 
							estat aroots	
							
								
							**********	
							** Bond						
							** Naive LS
							** Initial reg
							reg v_bond lag_r_bond //if year >= 1949
							* lamda = b
							nlcom _b[lag_r_bond]
							* mu = a / b
							nlcom _b[_cons] /  _b[lag_r_bond]
							* sigma = se(Epsilon)
							scalar sde = e(rmse)
								scalar list sde
							** Exact LS
							** Initial reg
							reg r_bond lag_r_bond if year >= 1981
							* lamda = -ln(b)
							nlcom -1*ln(_b[lag_r_bond]) 
							* mu = a / (1-b)
							nlcom _b[_cons] /  (1 - _b[lag_r_bond])
							* sigma = f(Epsilon, mu, lamda)
							scalar sde = e(rmse)
								scalar list sde
							nlcom sde * sqrt( 2 * (-1*ln(_b[lag_r_bond])/*end ln*/)/*end lambda*/ / (1-exp(-1 * 2* (-1*ln(_b[lag_r_bond])/*end ln*/)/*end lambda*/ )/*end exp*/)/*end denom*/) /*end sqrt*/
								
							**********	
							** House	
							** Naive LS
							** Initial reg
							reg v_house lag_r_house if year >= 1981
							* lamda = b
							nlcom _b[lag_r_house]
							* mu = a / b
							nlcom _b[_cons] /  _b[lag_r_house]
							* sigma = se(Epsilon)
							scalar sde = e(rmse)
								scalar list sde
							** Exact LS
							** Initial reg
							reg r_house lag_r_house if year >= 1981
							* lamda = -ln(b)
							nlcom -1*ln(_b[lag_r_house]) 
							* mu = a / (1-b)
							nlcom _b[_cons] /  (1 - _b[lag_r_house])
							* sigma = f(Epsilon, mu, lamda)
							scalar sde = e(rmse)
								scalar list sde
							nlcom sde * sqrt( 2 * (-1*ln(_b[lag_r_house])/*end ln*/)/*end lambda*/ / (1-exp(-1 * 2* (-1*ln(_b[lag_r_house])/*end ln*/)/*end lambda*/ )/*end exp*/)/*end denom*/) /*end sqrt*/
						
							** Compare to AR(1)
							** Correlogram
							ac  r_house, ylabels(-.4(.2).6) name(ac_house, replace)
							pac r_house, ylabels(-.4(.2).6) name(pac_house, replace)
							//graph save pac_house, replace
							graph combine ac_house pac_house, rows(2) cols(1)
							** ARIMA
							arima r_house if year >= 1981, ar(1) ma() 
							estat aroots	
							
						} //end if
						di "Done with Ornstein-Uhlenbeck."
					} //end if
					di "Done with Velocity."
								
					asdf_combined
				
					////////////
					** 1. Ideal rocket
					////////////
					scalar rocket = 1111
					if rocket == 1 {
						
						** Load
						cd_nb_stage
						use arima_data, clear
							
						** Need welfare decomposition of price (valuation) and quanity effects here
						
						** Unconditional estimates of ejected mass average velocity
						** Market price of risk Lambda ~= 0.20: 0.2 percent higher per standard deviation volatility - holds for all three approximately
						sum u_* r_* v_* rr_* year if year 
						sum u_* r_* rr_* year if year >= 1945 
						sum u_* r_* rr_* year if year >= 1981 
							
						** Estimate "u" 
						** If u_hat is positive, velocity interaction term == negative 1 -- ablating, switching signs -- accreting 
						** (4.9.25 p.3) estimate of average velocity of the ejected mass
						** Conditional estimates of mean ejected velocity
						** Here, the first coefficient b1 is "u" (4.9.25 p.3) estimate of velocity of the ejected mass
						** Updated to 4.16.25 p1 -- inverse of the fM variable less interaction term int_
						** Post 1981
						reg a_stock fminv_stock	int_stock	if year>1981, vce(robust)  
						reg a_bond  fminv_bond 	int_bond	if year>1981, vce(robust)  
						reg a_house fminv_house int_house	if year>1981, vce(robust)  
					
						reg a_house indu_house#c.fminv_house int_house	if year>1981, vce(robust)  
					
						** Acceleration a - house
						reg a_house fminv_house indu_house int_house, vce(robust) 
						reg a_house fminv_house indu_house int_house
						predict e_house, xb
						replace e_house 				= r_house - e_house		//Convert to error
						** Correlogram
						ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
						//graph save ac_house, replace
						pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
						//graph save pac_house, replace
						graph combine ac_house pac_house, rows(2) cols(1)
						drop e_*
						** ARIMA
						arima a_house fminv_house indu_house int_house, ar(1 2) ma() 
						estat aroots
						
					} //end if
					di "Done with perfect rocket."
								
					////////////
					** 3-body - motion
					////////////
					scalar threeb = 1111
					if threeb == 1 {
						
						** Load
						cd_nb_stage
						use arima_data, clear
							
						** Market price of risk Lambda ~= 0.20: 0.2 percent higher per standard deviation volatility - holds for all three approximately
						sum u_* r_* rr_* year if year >= 1890 
						sum u_* r_* rr_* year if year >= 1945 
							
						** Position r - stock  = AR(2) process by 3-body theory
						reg r_stock lag_m_bond lag_m_house lag_d_*_stock lag_in_*_stock L.r_stock L2.r_stock, vce(robust) //excludes lags
						reg r_stock lag_m_bond lag_m_house lag_d_*_stock lag_in_*_stock //excludes lags
						predict e_stock, xb
						replace e_stock 				= r_stock - e_stock		//Convert to error
						** Correlogram
						ac  e_stock, ylabels(-.4(.2).6) name(ac_stock, replace)
						//graph save ac_stock, replace
						pac e_stock, ylabels(-.4(.2).6) name(pac_stock, replace)
						//graph save pac_stock, replace
						graph combine ac_stock pac_stock, rows(2) cols(1)
						drop e_*
						** ARIMA
						arima r_stock lag_m_bond lag_m_house lag_d_*_stock lag_in_*_stock, ar(1 2) ma() 
						estat aroots
						
						** Position r - house = AR(2) process by 3-body theory
						reg r_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house L.r_house L2.r_house, vce(robust) //excludes lags
						reg r_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house //excludes lags
						predict e_house, xb
						replace e_house 				= r_house - e_house		//Convert to error
						** Correlogram
						ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
						//graph save ac_house, replace
						pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
						//graph save pac_house, replace
						graph combine ac_house pac_house, rows(2) cols(1)
						drop e_*
						** ARIMA
						arima r_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house, ar(1 2) ma() 
						estat aroots
						
						** Velocity v - house = AR(1) process by 3-body theory
						reg v_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house L.v_house, vce(robust) //look at flexible
						reg v_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house //excludes lags - reg for correlogram
						predict e_house, xb
						replace e_house 				= r_house - e_house		//Convert to error
						** Correlogram
						ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
						//graph save ac_house, replace
						pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
						//graph save pac_house, replace
						graph combine ac_house pac_house, rows(2) cols(1)
						drop e_*
						** ARIMA
						arima v_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house, ar(1) ma() 					
						estat aroots
						
						** Acceleration a - house = AR(0) process by 3-body theory
						reg a_house c.lag_m_stock#c.lag_d_stock_house#c.lag_in_stock_house c.lag_m_bond#c.lag_d_bond_house#c.lag_in_bond_house , vce(robust) //excludes lags
						reg a_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house //excludes lags
						predict e_house, xb
						replace e_house 				= r_house - e_house		//Convert to error
						** Correlogram
						ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
						//graph save ac_house, replace
						pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
						//graph save pac_house, replace
						graph combine ac_house pac_house, rows(2) cols(1)
						drop e_*
						** ARIMA
						arima a_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house, ar(1) ma() 
						arima a_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house, ar() ma(1) 
						estat aroots
						
						** Jolt j - house = AR(0) process by 3-body theory
						reg j_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house L.lag_m_bond L.lag_m_stock L.lag_d_stock_house L.lag_in_bond_house , vce(robust) //excludes lags
						reg j_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house //excludes lags
						predict e_house, xb
						replace e_house 				= r_house - e_house		//Convert to error
						** Correlogram
						ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
						//graph save ac_house, replace
						pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
						//graph save pac_house, replace
						graph combine ac_house pac_house, rows(2) cols(1)
						drop e_*
						** ARIMA
						arima j_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house, ar(1 2) ma() 
						estat aroots
						
					} //end if
					di "Done with 3-body."
					
					////////////
					** Add risk premium
					////////////
					scalar rocket = 1
					if rocket == 1 {
						
						** Load
						cd_nb_stage
						use arima_data, clear
							
						** Derive risk premia
						reg r_stock r_bond r_house 	if year >=1945, vce(robust)
						reg r_stock r_bond 			if year >=1945, vce(robust)
						reg r_stock r_house 		if year >=1945, vce(robust)
						reg r_house r_stock r_bond 	if year >=1945, vce(robust)
						reg r_house r_bond 			if year >=1945, vce(robust)
						reg r_house r_stock 		if year >=1945, vce(robust)
						reg r_bond r_stock r_house 	if year >=1945, vce(robust)
						reg r_bond r_house 			if year >=1945, vce(robust)
						reg r_bond r_stock 			if year >=1945, vce(robust)
							
						asdf_risk	
							
					} //end if
					di "Done with risk."
				
					////////////
					** Bonds
					////////////
					scalar bon 				= 1111
					if bon == 1 {
						
						** Load
						cd_nb_stage
						use arima_data, clear
							
						** Nominal interest rate
						//rename r_bond bond 
						reg r_bond L.r_bond m_* d_*_bond in_*_bond , vce(robust) 
						//reg r_bond L.r_bond c_*_bond , vce(robust) 
						predict e_bond, xb
						replace e_bond 				= bond - e_bond		//Convert to error
						** Correlogram
						ac  e_bond, ylabels(-.4(.2).6) name(ac_bond, replace)
						//graph save ac_bond, replace
						pac e_bond, ylabels(-.4(.2).6) name(pac_bond, replace)
						//graph save pac_bond, replace
						graph combine ac_bond pac_bond, rows(2) cols(1)
						drop e_*
						** ARIMA
						arima r_bond L.r_bond m_* d_*_bond in_*_bond  , ar(2 4) ma(1 3) vce(robust)
						estat aroots
						rename bond r_bond
						
						** Acceleration interest rate
						rename a_bond bond 
						rename m_bond	mass_bond
						//reg bond L.r_price L.m_* L.d_*_bond L.n_*_bond L.in_*_bond L.md_*_bond L.c_*_bond L.v_* L.a_* L.j_* 
						reg bond L.c_*_bond //2nd law
						reg bond L.m_* L.d_*_bond L.in_*_bond  //2nd law bits
						//reg bond m_* d_*_bond in_*_bond  //2nd law bits
						predict e_bond, xb
						replace e_bond 				= bond - e_bond		//Convert to error
						** Correlogram
						ac  e_bond, ylabels(-.4(.2).6) name(ac_bond, replace)
						//graph save ac_bond, replace
						pac e_bond, ylabels(-.4(.2).6) name(pac_bond, replace)
						//graph save pac_bond, replace
						graph combine ac_bond pac_bond, rows(2) cols(1)
						drop e_*
						** ARIMA
						//arima bond L.m_* L.d_*_bond L.in_*_bond, ar(1 15) ma(12)  //real bon
						arima bond L.m_* L.d_*_bond L.in_*_bond, ar(1) ma(4)
						estat aroots
						rename bond a_bond
						rename mass_bond m_bond
					
					} //end if
					di "Done with bonds NB."
						
					////////////
					** Stock
					////////////
					scalar stoc 			= 1111
					if stoc == 1 {
													
						** Stock acceleration
						rename a_stock stock 
						//reg stock L.m_* L.d_*_stock L.n_*_stock L.in_*_stock L.md_*_stock L.c_*_stock L.r_* L.v_* L.a_* L.j_*
						reg stock L.c_*_stock //2nd law
						reg stock L.m_* L.d_*_stock L.in_*_stock  //2nd law bits
						predict e_stock, xb
						replace e_stock 				= stock - e_stock		//Convert to error
						** Correlogram
						ac  e_stock, ylabels(-.4(.2).6) name(ac_stock, replace)
						//graph save ac_stock, replace
						pac e_stock, ylabels(-.4(.2).6) name(pac_stock, replace)
						//graph save pac_stock, replace
						graph combine ac_stock pac_stock, rows(2) cols(1)
						drop e_*
						** ARIMA
						//arima stock L.m_* L.d_*_stock L.in_*_stock, ar(1 3) ma(4) //2nd law bits
						arima stock L.c_*_stock, ar(1) ma() 
						estat aroots
						rename stock a_stock
																				
					} //end if
					di "Done with stock NB."
					
					////////////
					** House
					////////////
					scalar hous 			= 1111
					if hous == 1 {
											
						** House acceleration
						rename a_house house 
						rename m_house mass_house
						//reg house L.m_* L.d_*_house L.n_*_house L.in_*_house L.md_*_house L.c_*_house L.r_house L.v_* L.a_* L.j_*
						//reg house L.c_*_house //2nd law
						reg house L.m_* L.d_*_house L.in_*_house //2nd law bits
						predict e_house, xb
						replace e_house 				= house - e_house		//Convert to error
						** Correlogram
						ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
						//graph save ac_bond, replace
						pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
						//graph save pac_bond, replace
						graph combine ac_house pac_house, rows(2) cols(1)
						drop e_*
						** ARIMA
						arima house L.m_* L.d_*_house L.in_*_house, ar(1 2 6) ma() 
						estat aroots
						rename house a_house
						rename mass_house m_house
									
					} //end if
					di "Done with house NB."
					
				} //end if
				di "Done with NB combined."	
					
				******************************
				** N-Body - Special cases - archive
				** 1. Rocket
				** 2. 3-Body
				******************************
				scalar nb 					= 1111
				if nb == 1 {
				
					**************************
					** Prep Relative distances
					**************************
					global nam "stock bond house price"
					** Stats loop
					** Primary
					foreach pri of global nam {

							di "Primary velocity and accel: `pri'."
							
						******************
						** NB variables
						** 4.16.25 p.1
						******************
						
						** Velocity
						gen double v_`pri'				= r_`pri' - L.r_`pri' 
						gen double lag_v_`pri'			= L.v_`pri'
						
						** Acceleration
						gen double a_`pri'				= v_`pri' - L.v_`pri' 
						gen double lag_a_`pri'			= L.a_`pri'
						
						** Jolt (Jerk)
						gen double j_`pri'				= a_`pri' - L.a_`pri' 
						gen double lag_j_`pri'			= L.j_`pri'
						
						** Mass
						gen double lag_w_`pri'			= L.w_`pri'
						
						** Ablation
						//gen double ab_`pri'			= ni_`pri'
							
						******************
						** Rocket variables
						** 4.9.25 p.3
						******************
						
						** Percent change in mass - ln (m1 / m0)
						//gen double mdot_`pri'			= ln(F1.w_`pri' / w_`pri')  // this is ln (m0 / m1)
						//gen double mdotinv_`pri'		= mdot_`pri' ^ (-1)			// this is ln (m1 / m0)
						
						** Lagged values for rocket
						//gen double lag_mdot_`pri'		= L.mdotinv_`pri'
						
						** Ejected velocity u - rocket
						//gen double u_`pri'				= mdot_`pri' * F1.a_`pri' + v_`pri'
						
						******************
						** Rocket variables
						** 4.16.25 p1
						******************
						
						** Separate quantity change from price change here? -- at indu_* indicator 4.16.25
						
						** Percent change in mass - ln (m1 / m0)
						** Assumes change in mass is mass ablation/accretion -- but only some of the mass is ablating, 
						**   A portion is just disappearing (price change with no quantity change. Where does it go?
						gen double lnm_`pri'			= ln(w_`pri' / F1.w_`pri' )  // this is ln (m1 / m0)
						gen double fm_`pri'			= 1 - lnm_`pri' ^ (-1)			
						gen double fminv_`pri'			= fm_`pri' ^ (-1)			
						gen double int_`pri'			= lag_v_`pri' * fminv_`pri'
											
						** Ejected velocity u - rocket
						gen double u_`pri'				= F1.v_`pri' + a_`pri'  * fm_`pri'
						gen double indu_`pri'			= w_`pri' > F1.w_`pri'
						
						** Secondary
						foreach sec of global nam  {
							
								di "Starting primary: `pri' and secondary: `sec'."
							
							******************
							** NB variables
							** 4.16.25 p.1
							******************
							
							** Distance
							gen double d_`sec'_`pri'				= r_`sec' - r_`pri' 
							gen double lag_d_`sec'_`pri'			= L.d_`sec'_`pri'
														
							** Normed distance
							gen double n_`sec'_`pri'				= abs(d_`sec'_`pri')^3
							gen double lag_n_`sec'_`pri'			= L.n_`sec'_`pri'
							
							** Inververse normed distance
							gen double in_`sec'_`pri'				= 1/n_`sec'_`pri'
							gen double lag_in_`sec'_`pri'			= L.in_`sec'_`pri'

							******************
							** Rocket variables
							** 4.9.25 p.3
							******************

							** Mass-distance
							gen double md_`pri'_`sec'				= w_`sec' * d_`sec'_`pri'
										
							** Linear term
							gen double c_`sec'_`pri'				= w_`sec' * d_`sec'_`pri' * in_`sec'_`pri'
										
						} //end loop
						di "Done with seconary loop for primary: `pri'."
						
						** Delete diagonal elements
						drop *_`pri'_`pri'
						
					} //end loop
					di "Done with relative distance loop."
					
					** Rename mass variables
					rename w_* m_*
					rename *_w_* *_m_*
					
					** Drop
					drop r_priceR
					drop m_price
					drop *_price*
										
						** Order
						order *, alpha
						order *stock* *bond* *house* *price*
						order n t year month dt period r_* v_* a_* j_* m_* d_* n_* in_* lag_*
				
					** Save
					cd_nb_stage
					save arima_data, replace
				
					////////////
					** 1. Ideal rocket
					////////////
					scalar rocket = 1
					if rocket == 1 {
						
						** Load
						cd_nb_stage
						use arima_data, clear
							
						** Need welfare decomposition of price (valuation) and quanity effects here
						
						** Unconditional estimates of ejected mass average velocity
						** Market price of risk Lambda ~= 0.20: 0.2 percent higher per standard deviation volatility - holds for all three approximately
						sum u_* r_* v_* rr_* year if year 
						sum u_* r_* rr_* year if year >= 1945 
						sum u_* r_* rr_* year if year >= 1981 
							
						** Estimate "u" 
						** If u_hat is positive, velocity interaction term == negative 1 -- ablating, switching signs -- accreting 
						** (4.9.25 p.3) estimate of average velocity of the ejected mass
						** Conditional estimates of mean ejected velocity
						** Here, the first coefficient b1 is "u" (4.9.25 p.3) estimate of velocity of the ejected mass
						** Updated to 4.16.25 p1 -- inverse of the fM variable less interaction term int_
						** Post 1981
						reg a_stock fminv_stock	int_stock	if year>1981, vce(robust)  
						reg a_bond  fminv_bond 	int_bond	if year>1981, vce(robust)  
						reg a_house fminv_house int_house	if year>1981, vce(robust)  
					
						reg a_house indu_house#c.fminv_house int_house	if year>1981, vce(robust)  
					
						** Acceleration a - house
						reg a_house fminv_house indu_house int_house, vce(robust) 
						reg a_house fminv_house indu_house int_house
						predict e_house, xb
						replace e_house 				= r_house - e_house		//Convert to error
						** Correlogram
						ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
						//graph save ac_house, replace
						pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
						//graph save pac_house, replace
						graph combine ac_house pac_house, rows(2) cols(1)
						drop e_*
						** ARIMA
						arima a_house fminv_house indu_house int_house, ar(1 2) ma() 
						estat aroots
						
					} //end if
					di "Done with perfect rocket."
					
					////////////
					** 1.1 Rocket - Mass transfer
					////////////
					scalar rocket = 1
					if rocket == 1 {
						
						** Load
						cd_nb_stage
						use arima_data, clear
							
						** Need welfare decomposition of price (valuation) and quanity effects here
						
						
						
						omojmnlklkk
							
						** Estimate "u" 
						** If u_hat is positive, velocity interaction term == negative 1 -- ablating, switching signs -- accreting 
						** (4.9.25 p.3) estimate of average velocity of the ejected mass
						** Conditional estimates of mean ejected velocity
						** Here, the first coefficient b1 is "u" (4.9.25 p.3) estimate of velocity of the ejected mass
						** Updated to 4.16.25 p1 -- inverse of the fM variable less interaction term int_
						** Post 1981
						reg a_stock fminv_stock	int_stock	if year>1981, vce(robust)  
						reg a_bond  fminv_bond 	int_bond	if year>1981, vce(robust)  
						reg a_house fminv_house int_house	if year>1981, vce(robust)  
					
						reg a_house indu_house#c.fminv_house int_house	if year>1981, vce(robust)  
					
						** Acceleration a - house
						reg a_house fminv_house indu_house int_house, vce(robust) 
						reg a_house fminv_house indu_house int_house
						predict e_house, xb
						replace e_house 				= r_house - e_house		//Convert to error
						** Correlogram
						ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
						//graph save ac_house, replace
						pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
						//graph save pac_house, replace
						graph combine ac_house pac_house, rows(2) cols(1)
						drop e_*
						** ARIMA
						arima a_house fminv_house indu_house int_house, ar(1 2) ma() 
						estat aroots
						
					} //end if
					di "Done with transfer rocket."
								
					////////////
					** 3-body - motion
					////////////
					scalar threeb = 1
					if threeb == 1 {
						
						** Load
						cd_nb_stage
						use arima_data, clear
							
						** Market price of risk Lambda ~= 0.20: 0.2 percent higher per standard deviation volatility - holds for all three approximately
						sum u_* r_* rr_* year if year >= 1890 
						sum u_* r_* rr_* year if year >= 1945 
							
						** Position r - stock  = AR(2) process by 3-body theory
						reg r_stock lag_m_bond lag_m_house lag_d_*_stock lag_in_*_stock L.r_stock L2.r_stock, vce(robust) //excludes lags
						reg r_stock lag_m_bond lag_m_house lag_d_*_stock lag_in_*_stock //excludes lags
						predict e_stock, xb
						replace e_stock 				= r_stock - e_stock		//Convert to error
						** Correlogram
						ac  e_stock, ylabels(-.4(.2).6) name(ac_stock, replace)
						//graph save ac_stock, replace
						pac e_stock, ylabels(-.4(.2).6) name(pac_stock, replace)
						//graph save pac_stock, replace
						graph combine ac_stock pac_stock, rows(2) cols(1)
						drop e_*
						** ARIMA
						arima r_stock lag_m_bond lag_m_house lag_d_*_stock lag_in_*_stock, ar(1 2) ma() 
						estat aroots
						
						** Position r - house = AR(2) process by 3-body theory
						reg r_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house L.r_house L2.r_house, vce(robust) //excludes lags
						reg r_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house //excludes lags
						predict e_house, xb
						replace e_house 				= r_house - e_house		//Convert to error
						** Correlogram
						ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
						//graph save ac_house, replace
						pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
						//graph save pac_house, replace
						graph combine ac_house pac_house, rows(2) cols(1)
						drop e_*
						** ARIMA
						arima r_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house, ar(1 2) ma() 
						estat aroots
						
						** Velocity v - house = AR(1) process by 3-body theory
						reg v_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house L.v_house, vce(robust) //look at flexible
						reg v_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house //excludes lags - reg for correlogram
						predict e_house, xb
						replace e_house 				= r_house - e_house		//Convert to error
						** Correlogram
						ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
						//graph save ac_house, replace
						pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
						//graph save pac_house, replace
						graph combine ac_house pac_house, rows(2) cols(1)
						drop e_*
						** ARIMA
						arima v_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house, ar(1) ma() 					
						estat aroots
						
						** Acceleration a - house = AR(0) process by 3-body theory
						reg a_house c.lag_m_stock#c.lag_d_stock_house#c.lag_in_stock_house c.lag_m_bond#c.lag_d_bond_house#c.lag_in_bond_house , vce(robust) //excludes lags
						reg a_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house //excludes lags
						predict e_house, xb
						replace e_house 				= r_house - e_house		//Convert to error
						** Correlogram
						ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
						//graph save ac_house, replace
						pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
						//graph save pac_house, replace
						graph combine ac_house pac_house, rows(2) cols(1)
						drop e_*
						** ARIMA
						arima a_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house, ar(1) ma() 
						arima a_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house, ar() ma(1) 
						estat aroots
						
						** Jolt j - house = AR(0) process by 3-body theory
						reg j_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house L.lag_m_bond L.lag_m_stock L.lag_d_stock_house L.lag_in_bond_house , vce(robust) //excludes lags
						reg j_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house //excludes lags
						predict e_house, xb
						replace e_house 				= r_house - e_house		//Convert to error
						** Correlogram
						ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
						//graph save ac_house, replace
						pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
						//graph save pac_house, replace
						graph combine ac_house pac_house, rows(2) cols(1)
						drop e_*
						** ARIMA
						arima j_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house, ar(1 2) ma() 
						estat aroots
						
					} //end if
					di "Done with 3-body."
									
					////////////
					** Add risk premium
					////////////
					scalar rocket = 1
					if rocket == 1 {
						
						** Load
						cd_nb_stage
						use arima_data, clear
							
						** Derive risk premia
						reg r_stock r_bond r_house 	if year >=1945, vce(robust)
						reg r_stock r_bond 			if year >=1945, vce(robust)
						reg r_stock r_house 		if year >=1945, vce(robust)
						reg r_house r_stock r_bond 	if year >=1945, vce(robust)
						reg r_house r_bond 			if year >=1945, vce(robust)
						reg r_house r_stock 		if year >=1945, vce(robust)
						reg r_bond r_stock r_house 	if year >=1945, vce(robust)
						reg r_bond r_house 			if year >=1945, vce(robust)
						reg r_bond r_stock 			if year >=1945, vce(robust)
							
						asdf_risk	
							
					} //end if
					di "Done with risk."
				
					////////////
					** Bonds
					////////////
					scalar bon 				= 1
					if bon == 1 {
						
						** Load
						cd_nb_stage
						use arima_data, clear
							
						** Nominal interest rate
						//rename r_bond bond 
						reg r_bond L.r_bond m_* d_*_bond in_*_bond , vce(robust) 
						//reg r_bond L.r_bond c_*_bond , vce(robust) 
						predict e_bond, xb
						replace e_bond 				= bond - e_bond		//Convert to error
						** Correlogram
						ac  e_bond, ylabels(-.4(.2).6) name(ac_bond, replace)
						//graph save ac_bond, replace
						pac e_bond, ylabels(-.4(.2).6) name(pac_bond, replace)
						//graph save pac_bond, replace
						graph combine ac_bond pac_bond, rows(2) cols(1)
						drop e_*
						** ARIMA
						arima r_bond L.r_bond m_* d_*_bond in_*_bond  , ar(2 4) ma(1 3) vce(robust)
						estat aroots
						rename bond r_bond
						
						** Acceleration interest rate
						rename a_bond bond 
						rename m_bond	mass_bond
						//reg bond L.r_price L.m_* L.d_*_bond L.n_*_bond L.in_*_bond L.md_*_bond L.c_*_bond L.v_* L.a_* L.j_* 
						reg bond L.c_*_bond //2nd law
						reg bond L.m_* L.d_*_bond L.in_*_bond  //2nd law bits
						//reg bond m_* d_*_bond in_*_bond  //2nd law bits
						predict e_bond, xb
						replace e_bond 				= bond - e_bond		//Convert to error
						** Correlogram
						ac  e_bond, ylabels(-.4(.2).6) name(ac_bond, replace)
						//graph save ac_bond, replace
						pac e_bond, ylabels(-.4(.2).6) name(pac_bond, replace)
						//graph save pac_bond, replace
						graph combine ac_bond pac_bond, rows(2) cols(1)
						drop e_*
						** ARIMA
						//arima bond L.m_* L.d_*_bond L.in_*_bond, ar(1 15) ma(12)  //real bon
						arima bond L.m_* L.d_*_bond L.in_*_bond, ar(1) ma(4)
						estat aroots
						rename bond a_bond
						rename mass_bond m_bond
					
					} //end if
					di "Done with bonds NB."
						
					////////////
					** Stock
					////////////
					scalar stoc 			= 1
					if stoc == 1 {
													
						** Stock acceleration
						rename a_stock stock 
						//reg stock L.m_* L.d_*_stock L.n_*_stock L.in_*_stock L.md_*_stock L.c_*_stock L.r_* L.v_* L.a_* L.j_*
						reg stock L.c_*_stock //2nd law
						reg stock L.m_* L.d_*_stock L.in_*_stock  //2nd law bits
						predict e_stock, xb
						replace e_stock 				= stock - e_stock		//Convert to error
						** Correlogram
						ac  e_stock, ylabels(-.4(.2).6) name(ac_stock, replace)
						//graph save ac_stock, replace
						pac e_stock, ylabels(-.4(.2).6) name(pac_stock, replace)
						//graph save pac_stock, replace
						graph combine ac_stock pac_stock, rows(2) cols(1)
						drop e_*
						** ARIMA
						//arima stock L.m_* L.d_*_stock L.in_*_stock, ar(1 3) ma(4) //2nd law bits
						arima stock L.c_*_stock, ar(1) ma() 
						estat aroots
						rename stock a_stock
																				
					} //end if
					di "Done with stock NB."
					
					////////////
					** House
					////////////
					scalar hous 				= 1
					if hous == 1 {
											
						** House acceleration
						rename a_house house 
						rename m_house mass_house
						//reg house L.m_* L.d_*_house L.n_*_house L.in_*_house L.md_*_house L.c_*_house L.r_house L.v_* L.a_* L.j_*
						//reg house L.c_*_house //2nd law
						reg house L.m_* L.d_*_house L.in_*_house //2nd law bits
						predict e_house, xb
						replace e_house 				= house - e_house		//Convert to error
						** Correlogram
						ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
						//graph save ac_bond, replace
						pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
						//graph save pac_bond, replace
						graph combine ac_house pac_house, rows(2) cols(1)
						drop e_*
						** ARIMA
						arima house L.m_* L.d_*_house L.in_*_house, ar(1 2 6) ma() 
						estat aroots
						rename house a_house
						rename mass_house m_house
									
					} //end if
					di "Done with house NB."
					
				} //end if
				di "Done with NB-annual."	
					
				******************************
				** N-Body - ARIMA + Motion
				** Archive 4.16.25
				******************************
				scalar nb 					= 1111
				if nb == 1 {
				
					** Relative distances
					global nam "stock bond house price"
					** Stats loop
					** Primary
					foreach pri of global nam {

							di "Primary velocity and accel: `pri'."
							
						** Velocity
						gen double v_`pri'				= r_`pri' - L.r_`pri' 
												
						** Acceleration
						gen double a_`pri'				= v_`pri' - L.v_`pri' 
						
						** Jolt (Jerk)
						gen double j_`pri'				= a_`pri' - L.a_`pri' 
						
						** Secondary
						foreach sec of global nam  {
							
								di "Starting primary: `pri' and secondary: `sec'."
							
							** Distance
							gen double d_`sec'_`pri'				= r_`sec' - r_`pri' 
														
							** Normed distance
							gen double n_`sec'_`pri'				= abs(d_`sec'_`pri')^3
							
							** Inververse normed distance
							gen double in_`sec'_`pri'				= 1/n_`sec'_`pri'
							
							** Mass-distance
							gen double md_`pri'_`sec'				= w_`sec' * d_`sec'_`pri'
										
							** Linear term
							gen double c_`sec'_`pri'				= w_`sec' * d_`sec'_`pri' * in_`sec'_`pri'
										
						} //end loop
						di "Done with seconary loop for primary: `pri'."
						
						** Delete diagonal elements
						drop *_`pri'_`pri'
						
					} //end loop
					di "Done with relative distance loop."
					
					** Rename mass variables
					rename w_* m_*
					
					** Drop
					drop r_priceR
					drop m_price
										
						** Order
						order n t year month dt period r_* v_* a_* j_* m_* d_* n_* in_* c_* 
						
					////////////
					** Bonds
					////////////
					scalar bon 				= 1
					if bon == 1 {
								
						** Nominal interest rate
						rename r_bond bond 
						reg bond L.r_price L.m_* L.d_*_bond L.in_*_bond L.c_*_bond L.v_* L.a_* L.j_* 
						predict e_bond, xb
						replace e_bond 				= bond - e_bond		//Convert to error
						** Correlogram
						ac  e_bond, ylabels(-.4(.2).6) name(ac_bond, replace)
						//graph save ac_bond, replace
						pac e_bond, ylabels(-.4(.2).6) name(pac_bond, replace)
						//graph save pac_bond, replace
						graph combine ac_bond pac_bond, rows(2) cols(1)
						drop e_*
						** ARIMA
						//arima bond L.r_price L.m_* L.d_*_bond L.in_*_bond L.c_*_bond L.v_* L.a_* L.j_* , ar() ma()
						//estat aroots
						rename bond r_bond
						
						** Velocity interest rate
						rename v_bond bond
						reg bond L.r_price L.m_* L.d_*_bond L.in_*_bond L.c_*_bond L.v_* L.a_* L.j_* 
						predict e_bond, xb
						replace e_bond 				= bond - e_bond		//Convert to error
						** Correlogram
						ac  e_bond, ylabels(-.4(.2).6) name(ac_bond, replace)
						//graph save ac_bond, replace
						pac e_bond, ylabels(-.4(.2).6) name(pac_bond, replace)
						//graph save pac_bond, replace
						graph combine ac_bond pac_bond, rows(2) cols(1)
						drop e_*
						** ARIMA
						arima bond L.r_* L.m_* L.d_*_bond L.in_*_bond L.c_* L.v_* L.a_* L.j_*, ar(1) ma()
						estat aroots
						rename bond v_bond
						
						** Acceleration interest rate
						rename a_bond bond 
						reg bond L.r_price L.m_* L.d_*_bond L.n_*_bond L.in_*_bond L.md_*_bond L.c_*_bond L.v_* L.a_* L.j_* 
						*reg bond L.c_*_bond //2nd law
						*reg bond L.m_* L.d_*_bond L.in_*_bond  //2nd law bits
						predict e_bond, xb
						replace e_bond 				= bond - e_bond		//Convert to error
						** Correlogram
						ac  e_bond, ylabels(-.4(.2).6) name(ac_bond, replace)
						//graph save ac_bond, replace
						pac e_bond, ylabels(-.4(.2).6) name(pac_bond, replace)
						//graph save pac_bond, replace
						graph combine ac_bond pac_bond, rows(2) cols(1)
						drop e_*
						** ARIMA
						//arima bond L.r_price L.m_* L.d_*_bond L.in_*_bond L.c_*_bond L.v_* L.a_* L.j_*, ar(1) ma()
						//estat aroots
						rename bond a_bond
						
						** Jolt interest rate
						rename j_bond bond 
						reg L.r_price L.m_* L.d_*_bond L.in_*_bond L.c_*_bond L.v_* L.a_* L.j_* 
						predict e_bond, xb
						replace e_bond 				= bond - e_bond		//Convert to error
						** Correlogram
						ac  e_bond, ylabels(-.4(.2).6) name(ac_bond, replace)
						//graph save ac_bond, replace
						pac e_bond, ylabels(-.4(.2).6) name(pac_bond, replace)
						//graph save pac_bond, replace
						graph combine ac_bond pac_bond, rows(2) cols(1)
						drop e_*
						** ARIMA
						arima bond L.r_price L.m_* L.d_*_bond L.in_*_bond L.c_*_bond L.v_* L.a_* L.j_*, ar(1 2) ma(1)
						estat aroots
						rename bond j_bond
						
					
					} //end if
					di "Done with bonds NB."
						
					////////////
					** Stock
					////////////
					scalar stoc 			= 1
					if stoc == 1 {
												
						** Stock level
						reg r_stock r_bond r_house r_price L.d_stock* L.dd_stock* L.v_* L.a_* L.j_* L.m_stock*
						predict e_stock, xb
						replace e_stock 				= stock - e_stock		//Convert to error
						** Correlogram
						ac  e_stock, ylabels(-.4(.2).6) name(ac_stock, replace)
						//graph save ac_bond, replace
						pac e_stock, ylabels(-.4(.2).6) name(pac_stock, replace)
						//graph save pac_bond, replace
						graph combine ac_stock pac_stock, rows(2) cols(1)
						drop e_*
						** ARIMA
						arima r_stock r_bond r_house r_price L.d_stock* L.dd_stock* L.v_* L.a_* L.j_* L.m_stock*, ar(1 2) ma() //no ma lags converge
						estat aroots
					
						** Stock velocity (change)
						reg v_stock v_bond v_house v_price L.d_stock* L.dd_stock* L.r_price L.a_* L.j_* L.m_stock*
						predict e_stock, xb
						replace e_stock 				= stock - e_stock		//Convert to error
						** Correlogram
						ac  e_stock, ylabels(-.4(.2).6) name(ac_stock, replace)
						//graph save ac_bond, replace
						pac e_stock, ylabels(-.4(.2).6) name(pac_stock, replace)
						//graph save pac_bond, replace
						graph combine ac_stock pac_stock, rows(2) cols(1)
						drop e_*
						** ARIMA
						arima v_stock v_bond v_house v_price L.d_stock* L.dd_stock* L.r_price L.a_* L.j_* L.m_stock*, ar(1) ma(1) 
						estat aroots
						
						** Stock acceleration
						rename a_stock stock 
						reg stock L.m_* L.d_*_stock L.n_*_stock L.in_*_stock L.md_*_stock L.c_*_stock L.r_* L.v_* L.a_* L.j_*
						reg stock L.c_*_stock //2nd law
						reg stock L.m_* L.d_*_bond L.in_*_bond  //2nd law bits
						predict e_stock, xb
						replace e_stock 				= stock - e_stock		//Convert to error
						** Correlogram
						ac  e_stock, ylabels(-.4(.2).6) name(ac_stock, replace)
						//graph save ac_stock, replace
						pac e_stock, ylabels(-.4(.2).6) name(pac_stock, replace)
						//graph save pac_stock, replace
						graph combine ac_stock pac_stock, rows(2) cols(1)
						drop e_*
						** ARIMA
						arima stock L.m_* L.d_*_bond L.in_*_bond, ar(1) ma(1 3) 
						estat aroots
						rename stock a_stock
												
						** Stock jolt
						reg j_stock j_bond j_house j_price L.d_stock* L.dd_stock* L.r_price L.v_* L.a_* L.m_stock*
						predict e_stock, xb
						replace e_stock 				= stock - e_stock		//Convert to error
						** Correlogram
						ac  e_stock, ylabels(-.4(.2).6) name(ac_stock, replace)
						//graph save ac_bond, replace
						pac e_stock, ylabels(-.4(.2).6) name(pac_stock, replace)
						//graph save pac_bond, replace
						graph combine ac_stock pac_stock, rows(2) cols(1)
						drop e_*
						** ARIMA
						arima j_stock j_bond j_house j_price L.d_stock* L.dd_stock* L.r_price L.v_* L.a_* L.m_stock*, ar(1) ma() 
						estat aroots
												
					} //end if
					di "Done with stock NB."
					
					////////////
					** House
					////////////
					scalar hous 				= 1
					if hous == 1 {
											
						** House level
						reg r_house r_stock r_bond r_price L.d_house* L.dd_house* L.v_* L.a_* L.j_* L.m_house*
						predict e_house, xb
						replace e_house 				= house - e_house		//Convert to error
						** Correlogram
						ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
						//graph save ac_bond, replace
						pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
						//graph save pac_bond, replace
						graph combine ac_house pac_house, rows(2) cols(1)
						drop e_*
						** ARIMA
						arima  r_house r_stock r_bond r_price L.d_house* L.dd_house* L.v_* L.a_* L.j_* L.m_house*, ar(1 2) ma(7) 
						estat aroots
					
						** house velocity (change)
						reg v_house v_stock v_bond v_price L.d_house* L.dd_house* L.r_price L.a_* L.j_* L.m_house*
						predict e_house, xb
						replace e_house 				= house - e_house		//Convert to error
						** Correlogram
						ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
						//graph save ac_bond, replace
						pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
						//graph save pac_bond, replace
						graph combine ac_house pac_house, rows(2) cols(1)
						drop e_*
						** ARIMA
						arima v_house v_stock v_bond v_price L.d_house* L.dd_house* L.r_price L.a_* L.j_* L.m_house*, ar(1) ma() 
						estat aroots
						
						** House acceleration
						rename a_house house 
						reg house L.m_* L.d_*_house L.n_*_house L.in_*_house L.md_*_house L.c_*_house L.r_house L.v_* L.a_* L.j_*
						//reg house L.c_*_house //2nd law
						//reg house L.m_* L.d_*_house L.in_*_house //2nd law
						predict e_house, xb
						replace e_house 				= house - e_house		//Convert to error
						** Correlogram
						ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
						//graph save ac_bond, replace
						pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
						//graph save pac_bond, replace
						graph combine ac_house pac_house, rows(2) cols(1)
						drop e_*
						** ARIMA
						arima a_house a_house a_bond a_price D.r_* D.dd_house* D.m_house*, ar(1 2) ma() 
						estat aroots
												
						** House jolt
						reg j_house j_house j_bond j_price L.d_house* L.dd_house* L.r_price L.v_* L.a_* L.m_house*
						predict e_house, xb
						replace e_house 				= house - e_house		//Convert to error
						** Correlogram
						ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
						//graph save ac_bond, replace
						pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
						//graph save pac_bond, replace
						graph combine ac_house pac_house, rows(2) cols(1)
						drop e_*
						** ARIMA
						arima j_house j_stock j_bond j_price L.d_house* L.dd_house* L.r_price L.v_* L.a_* L.m_house*, ar(1 6) ma(5) 
						estat aroots
									
					} //end if
					di "Done with house NB."
					
				} //end if
				di "Done with NB-ARIMA."
									
				******************************
				** Rogoff 2024 - annual
				******************************
				scalar rog 					= 1
				if rog == 1 {
					
					** Correlogram - linear detrended data (Rogoff trend)
					** Gen linear detrended bond rate for correlogram - rr_bondt
					//gen trend 					= n
					reg rr_bond t
					predict rr_bondt, xb
					replace rr_bondt 			= rr_bond - rr_bondt
					** Check
						reg rr_bondt rr_bond		
					** Correlogram
					ac  rr_bondt, ylabels(-.4(.2).6) name(ac_bond, replace)
					//graph save ac_bond, replace
					pac rr_bondt, ylabels(-.4(.2).6) name(pac_bond, replace)
					//graph save pac_bond, replace
					graph combine ac_bond pac_bond, rows(2) cols(1)
					drop rr_bondt
					
					** Corelogram-based ARIMA
					arima rr_bond t r_stock r_house, ar(1 2 15) ma(1 16)
					estat aroots
					
					** Rogoff 2024 stationarity test Table 1
					foreach var of varlist r_* v_* a_* {
						
						** Check stationarity
						dfgls `var', maxlag(3) ers
						
					} //end loop 
					di "Done with check."
										
					** Rogoff 2024 half life Table 4 -- Matlab
					
					** Rogoff 2024 - Figure 1 - Long-run component
					
					** Annual ARIMA
					** Rogoff - max 3
					arima rr_bond t, ar(1 2 3) ma(1 2 3) 
					estat aroots
									
				} //end if
				di "Done with rogoff bonds annual."
			
				******************************
				** Knoll 2017 - annual - VAR
				******************************
				scalar knol 					= 1
				if knol == 1 {
					
					** Reg
					** rent: price ratio (Knoll 2017 analyzes price:rent)
					reg r_house L.r_house					//Knoll Eqn 3.7 (inverse)
					reg r_house L.r_house, robust
									
					** VAR
					var r_house, lags(1/16) dfk small // Knoll 2017 Table 3.4, Panel B, Column 3
					** Granger test
					vargranger	
					
					** Exented
					** Level
					var r_house r_stock r_bond r_price, lags(1 2 3 6 12 14) dfk small // Knoll 2017 Table 3.4, Panel B, Column 3
					** Granger test
					vargranger				
					** Plot
					irf create var1, step(20) set(myirf) replace
					irf graph oirf, impulse(r_house r_stock r_bond r_price) response(r_house r_stock r_bond r_price) yline(0,lcolor(black)) xlabel(0(3)18) byopts(yrescale)
					
					** Velocity
					var v_* , lags(1 2 3 6 10) dfk small // Knoll 2017 Table 3.4, Panel B, Column 3
					** Granger test
					vargranger	
					** Plot
					irf create var1, step(20) set(myirf) replace
					irf graph oirf, impulse(v_house v_stock v_bond v_price) response(v_house v_stock v_bond v_price) yline(0,lcolor(black)) xlabel(0(3)18) byopts(yrescale)
					
					** Acceleration
					var a_* , lags(1 2 3 6 10) dfk small // Knoll 2017 Table 3.4, Panel B, Column 3
					** Granger test
					vargranger	
					** Plot
					irf create var1, step(20) set(myirf) replace
					irf graph oirf, impulse(a_house a_stock a_bond a_price) response(a_house a_stock a_bond a_price) yline(0,lcolor(black)) xlabel(0(3)18) byopts(yrescale)
					
				} //end if
				di "Done with rogoff bonds annual."
								
				******************************
				** GARCH
				******************************
				scalar garch					= 1
				if garch == 1 {
					
					
					** GARCH - stocks and housing
					dvech (r_stock = L.r_stock) (r_house = L.r_house), arch(1) garch(1) 
					** Graph
					predict v*, variance
					tsline  v_r_*  
					twoway connected v_r_* year, name(garch, replace) legend(on) yscale(range(0)) ylabel(-1(2)7) cmissing(n)
					
					** GARCH bonds
					dvech (r_bond = L.r_bond), arch(1) garch(1) 
					** Graph
					drop v*
					predict v*, variance
					twoway connected v_r_* year, name(garch, replace) legend(on) yscale(range(0)) ylabel(-1(2)7) cmissing(n)
												
				} //end if
				di "Done with garch."
												
			} //end if
			di "Done with annual."
								
		} //End if
		di "Done with analysis."
		
		*********************
		** GRAPH
		*********************
		scalar graf = 1
		if graf == 1 {
			
			** Annual
			cd_nb_stage
			use annual_data, clear
			foreach n of numlist 1/4 {
				
					di "Saving period `n'. Names list is now: `names'."
					
				twoway connected r_stock r_bond r_house year if period == `n' & month==12, name(period_`n', replace) legend(off) yscale(range(0)) ylabel(-6(2)10) cmissing(n) 
				graph save period_`n', replace 
				//graph export period_`n'.png, replace
				local names = "`names'" + "period_`n'.gph "
				
			} //end loop
			di "Done with scatter loop."
			graph combine `names', rows(2) cols(2) 
						
			** Monthly
			cd_nb_stage
			use monthly_data, clear
			foreach n of numlist 1/4 {
				
					di "Saving period `n'. Names list is now: `names'."
					
				twoway connected r_stock r_bond r_house dt if period == `n', name(period_`n', replace) legend(off) yscale(range(0)) ylabel(-6(2)10) cmissing(n) xlabel()
				graph save period_`n', replace 
				//graph export period_`n'.png, replace
				local names2 = "`names2'" + "period_`n'.gph "
				
			} //end loop
			di "Done with scatter loop."
			graph combine `names2', rows(2) cols(2) 

		} //end if
		di "Done with graphs."
					
	} //end if
	di "Done with runit."
	
	*********************
	** ARCHIVE
	*********************
	scalar archive	= 1111
	if archive == 1 {
		
		////////////
		** Bonds
		////////////
		scalar bon 				= 1111
		if bon == 1 {
			
			** Load
			cd_nb_stage
			use arima_data, clear
				
			** Nominal interest rate
			//rename r_bond bond 
			reg r_bond L.r_bond m_* d_*_bond in_*_bond , vce(robust) 
			//reg r_bond L.r_bond c_*_bond , vce(robust) 
			predict e_bond, xb
			replace e_bond 				= bond - e_bond		//Convert to error
			** Correlogram
			ac  e_bond, ylabels(-.4(.2).6) name(ac_bond, replace)
			//graph save ac_bond, replace
			pac e_bond, ylabels(-.4(.2).6) name(pac_bond, replace)
			//graph save pac_bond, replace
			graph combine ac_bond pac_bond, rows(2) cols(1)
			drop e_*
			** ARIMA
			arima r_bond L.r_bond m_* d_*_bond in_*_bond  , ar(2 4) ma(1 3) vce(robust)
			estat aroots
			rename bond r_bond
			
			** Acceleration interest rate
			rename a_bond bond 
			rename m_bond	mass_bond
			//reg bond L.r_price L.m_* L.d_*_bond L.n_*_bond L.in_*_bond L.md_*_bond L.c_*_bond L.v_* L.a_* L.j_* 
			reg bond L.c_*_bond //2nd law
			reg bond L.m_* L.d_*_bond L.in_*_bond  //2nd law bits
			//reg bond m_* d_*_bond in_*_bond  //2nd law bits
			predict e_bond, xb
			replace e_bond 				= bond - e_bond		//Convert to error
			** Correlogram
			ac  e_bond, ylabels(-.4(.2).6) name(ac_bond, replace)
			//graph save ac_bond, replace
			pac e_bond, ylabels(-.4(.2).6) name(pac_bond, replace)
			//graph save pac_bond, replace
			graph combine ac_bond pac_bond, rows(2) cols(1)
			drop e_*
			** ARIMA
			//arima bond L.m_* L.d_*_bond L.in_*_bond, ar(1 15) ma(12)  //real bon
			arima bond L.m_* L.d_*_bond L.in_*_bond, ar(1) ma(4)
			estat aroots
			rename bond a_bond
			rename mass_bond m_bond
		
		} //end if
		di "Done with bonds NB."
			
		////////////
		** Stock
		////////////
		scalar stoc 			= 1111
		if stoc == 1 {
										
			** Stock acceleration
			rename a_stock stock 
			//reg stock L.m_* L.d_*_stock L.n_*_stock L.in_*_stock L.md_*_stock L.c_*_stock L.r_* L.v_* L.a_* L.j_*
			reg stock L.c_*_stock //2nd law
			reg stock L.m_* L.d_*_stock L.in_*_stock  //2nd law bits
			predict e_stock, xb
			replace e_stock 				= stock - e_stock		//Convert to error
			** Correlogram
			ac  e_stock, ylabels(-.4(.2).6) name(ac_stock, replace)
			//graph save ac_stock, replace
			pac e_stock, ylabels(-.4(.2).6) name(pac_stock, replace)
			//graph save pac_stock, replace
			graph combine ac_stock pac_stock, rows(2) cols(1)
			drop e_*
			** ARIMA
			//arima stock L.m_* L.d_*_stock L.in_*_stock, ar(1 3) ma(4) //2nd law bits
			arima stock L.c_*_stock, ar(1) ma() 
			estat aroots
			rename stock a_stock
																	
		} //end if
		di "Done with stock NB."
		
		////////////
		** House
		////////////
		scalar hous 			= 1111
		if hous == 1 {
								
			** House acceleration
			rename a_house house 
			rename m_house mass_house
			//reg house L.m_* L.d_*_house L.n_*_house L.in_*_house L.md_*_house L.c_*_house L.r_house L.v_* L.a_* L.j_*
			//reg house L.c_*_house //2nd law
			reg house L.m_* L.d_*_house L.in_*_house //2nd law bits
			predict e_house, xb
			replace e_house 				= house - e_house		//Convert to error
			** Correlogram
			ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
			//graph save ac_bond, replace
			pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
			//graph save pac_bond, replace
			graph combine ac_house pac_house, rows(2) cols(1)
			drop e_*
			** ARIMA
			arima house L.m_* L.d_*_house L.in_*_house, ar(1 2 6) ma() 
			estat aroots
			rename house a_house
			rename mass_house m_house
						
		} //end if
		di "Done with house NB."
		
		////////////
		** Acceleration
		** General rocket + gravity
		////////////
		scalar gen_accel = 1111
		if gen_accel == 1 {
			
			** Load
			cd_nb_stage
			use arima_data, clear
									
			***********
			** House
			***********
			
			** Unconditional ARIMA 
			arima j_house , ar(1 2 3) ma() 
			estat aroots
			arima a_house , ar(1 2 3) ma() technique(bhhh)
			estat aroots
			arima v_house , ar(1) ma(1) technique(bhhh)
			estat aroots
			arima r_house , ar(1) ma(1) technique(bhhh)
			estat aroots
			** Correlogram
			ac  a_house, ylabels(-.4(.2).6) name(ac_house, replace)
			//graph save ac_house, replace
			pac a_house, ylabels(-.4(.2).6) name(pac_house, replace)
			//graph save pac_house, replace
			graph combine ac_house pac_house, rows(2) cols(1)
			
			** Initial reg
			reg a_house grav_term_stock_house grav_term_bond_house  ///
				acc_ddot_house acc_sdot_house lag_v_dot_house //if year >= 1949
										
			** Initial arima
			predict e_house, xb
			replace e_house 				= a_house - e_house		//Convert to error
			** Correlogram
			ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
			//graph save ac_house, replace
			pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
			//graph save pac_house, replace
			graph combine ac_house pac_house, rows(2) cols(1)
			drop e_*
			
			** Reload
			cd_nb_stage
			use arima_data, clear
			//drop *_price
									
			** Keep complete data only for balanced OOS testing
			** Drop missing jolt observations (4-months) for balanced OOS run
			global assets "stock bond house"
			global letters "r v a j"
			pause on
			
			foreach asset of global assets {
				
				foreach let of global letters {
											
					reg `let'_`asset' lag_r_* lag_v_* lag_j_* lag_m_* lag_acd_* lag_acs_*
					predict yhat, xb
					gen complete_data	= (yhat~=.)
						sum year yhat complete* 
						*tab year complete_data 
					drop if yhat==.
					drop if `let'_house == .
					drop yhat complete_data
					
					** Look
					*scatter `let'_`asset' year //if  `let'_`asset' < 0.05 &  `let'_`asset' > -0.05
					
					*pause

				} //end loop
				di "Done with letter loop."
				
			} //end loop
			di "Done with asset loop."
															
			** OOS
			set seed	10111
			gen randsample			= runiform()
			sort randsample
			gen ob					= _n
			sum ob
			local holdout			= 0.60
			local upper				= ceil(r(max) * `holdout')
			gen incl 				= (ob <= `upper')
				di "Upper is `upper', holdout is `holdout'."
				sum ob randsample incl //if year >= 1900
				tab incl //if year >= 1900
			replace incl			= (incl==1 ) //& year >= 1900)

			** Initial rocket-grav reg
			reg a_house grav_term_stock_house grav_term_bond_house  ///
				acc_ddot_house acc_sdot_house lag_v_dot_house if (incl)
			fit_nb a_house
			
			*************************************
			** Approximations
			drop *diff*
			**************************************
								
			** Order vars for regressions 
			order *stock *bond *house
			order *_r_* *_v_* *_a_* *_j_*
			rename *_r_dot_* *_rdot_*
			rename *_v_dot_* *_vdot_*
			rename *_v_dot2_* *_vdot2_*
			order *_dot*, last
			
			** PCA R Data Output
			cd_nb_stage
			outsheet lag_r_* lag_v_* lag_a_* lag_j_* lag_m_* lag_acd_* lag_acs_* lag_rdot_* lag_vdot_* lag_vdot2_* using NB_R_PCA_Output.csv, replace comma
			
			** Save for turingbot
			cd_nb_stage
			save tempm, replace
			use tempm, clear
			** Save turingbot
			drop lag_m_price lag_a*_price *vdot*_price *_r_price
			order year month *stock* *bond* *house*
			sort year month
			order year month a_house lag_r_* lag_v_* lag_a_* lag_j_* lag_m_* lag_acd_* lag_acs_* lag_rdot_* lag_vdot_* lag_vdot2_*
			keep  a_house lag_r_* lag_v_* lag_a_* lag_j_* lag_m_* lag_acd_* lag_acs_* lag_rdot_* lag_vdot_* lag_vdot2_*
			foreach var of varlist a_house lag_r_* lag_v_* lag_a_* lag_j_* lag_m_* lag_acd_* lag_acs_* lag_rdot_* lag_vdot_* lag_vdot2_* {
				
			replace `var' 				= `var' * 100
			
			} //end loop
			di "Done with rescale loop."
			
			** Save
			cd_nb_stage
			save turingbot_datam, replace
			use turingbot_datam, clear
			
			** Reload
			cd_nb_stage
			use tempm, clear
			
				** Look
				sort year month
				order year month m_* 
				order year month *_bond
				order year month *_stock
				drop lag_m_price lag_a*_price *vdot*_price *_r_price
				
				** Linear -- 52.28%
				reg a_house lag_r_*  lag_v_* lag_a_* lag_j_* lag_m_* lag_acd_* lag_acs_* lag_rdot_* lag_vdot_* lag_vdot2_* if (incl)
				fit_nb a_house 
						
				** 51.23%
				reg v_house lag_r_* lag_v_* lag_a_* lag_j_* lag_m_* lag_acd_* lag_acs_* if (incl)
				fit_nb v_house 
				
				** 38.66%
				reg r_house lag_r_stock lag_r_bond lag_v_* lag_a_* lag_j_* lag_m_* lag_acd_* lag_acs_* if (incl)
				fit_nb r_house 
				
				** 51.12%
				reg j_house lag_r_* lag_v_* lag_a_* lag_j_* lag_m_* lag_acd_* lag_acs_* if (incl)
				fit_nb j_house
			
				** Test Expansion
				** larger -- 46.18% loss 1981, 45.3% 1949, 12.62% 1900
				reg a_house lag_r_bond lag_r_stock lag_r_house c.lag_m_stock#c.lag_m_stock lag_m_bond c.lag_m_house#c.lag_m_house c.lag_acd_stock#c.lag_acd_stock c.lag_acs_stock#c.lag_acs_stock lag_acd_bond ///
					lag_acs_bond c.lag_acd_house##c.lag_acd_house c.lag_acs_house#c.lag_acs_house if (incl)
				fit_nb a_house
				** smaller -- 41.19% loss 1981, 45.1% 1949, 14.65% 1900
				reg a_house lag_r_bond lag_r_stock lag_r_house lag_m_stock lag_m_bond lag_m_house lag_acd_stock c.lag_acs_stock#c.lag_acs_stock lag_acd_bond ///
					lag_acs_bond c.lag_acd_house##c.lag_acd_house c.lag_acs_house#c.lag_acs_house if (incl)
				fit_nb a_house
			
			** Generate Expansions
			global nams "stock bond house"
			global namsac "acs acd"
			pause on
		
			** 2nd order  
			** Rate loop -- a housing is non-linear in lagged r housing
			foreach nam of global nams {
				
				reg a_house c.lag_r_`nam'#c.lag_r_`nam' lag_r_* lag_v_* lag_a_* lag_j_* lag_m_* lag_acd_* lag_acs_* if (incl)
				** Plot
				sum lag_r_`nam'
				quietly margins , at(lag_r_`nam' = (4 (0.1) 8) ) 			
				marginsplot, recast(line) recastci(rarea)
				
				* Fit
				fit_nb a_house
				
				pause
				
			} //end loop
			di "Done with loop expansion check r."
							
			** Mass loop -- linear
			foreach nam of global nams {
				
				reg a_house c.lag_m_`nam'#c.lag_m_`nam' lag_r_* lag_v_* lag_a_* lag_j_* lag_m_* lag_acd_* lag_acs_* if (incl)
				** Plot
				qui margins , at(lag_m_`nam' = (1 (1000) 50000) ) 			
				marginsplot, recast(line) recastci(rarea)
				
				* Fit
				fit_nb a_house
				
				sum lag_m_`nam'
				
				//pause
				
			} //end loop
			di "Done with loop expansion check m."
				
			** Acc loop
			** acs_house (U)
			foreach nam of global nams {
				
				foreach nac of global namsac {
						
						di "Beginnin nam: `nam', nac: `nac'."
					
					reg a_house c.lag_`nac'_`nam'#c.lag_`nac'_`nam' lag_r_* lag_v_* lag_a_* lag_j_* lag_m_* lag_acd_* lag_acs_* if (incl)
					
					** Plot
					quietly margins , at(lag_`nac'_`nam' = (-10000 (1000) 50000) ) 			
					marginsplot, recast(line) recastci(rarea)
					
					* Fit
					fit_nb a_house
					
					sum lag_`nac'_`nam'
					
					//pause
				
				} //end loop ac
				di "Done with AC loop."
				
			} //end loop
			di "Done with loop expansion check acs."
								
				** 2nd order OOS
				reg a_house c.lag_acs_house#c.lag_acs_house lag_r_* lag_v_* lag_a_* lag_j_* lag_m_* lag_acd_* lag_acs_* if (incl)
				fit_nb a_house
				
			asdf_nonlin					
				
				** Simple
				** Distance
				reg a_house lag_d_stock_house c.lag_d_bond_house##c.lag_d_bond_house##c.lag_d_bond_house if (incl)
				fit_nb a_house
				** Velocity
				reg a_house lag_v_house if (incl)
				fit_nb a_house
				reg a_house c.lag_v_house##c.lag_v_house if (incl)
				fit_nb a_house
				
							
							

																								
			***********
			** Stock
			***********
			
			** Initial reg
			reg a_stock grav_term_bond_stock grav_term_house_stock  ///
				acc_ddot_stock acc_sdot_stock lag_v_dot_stock if year >= 1981
				
			** Initial arima
			predict e_stock, xb
			replace e_stock 				= a_stock - e_stock		//Convert to error
			** Correlogram
			ac  e_stock, ylabels(-.4(.2).6) name(ac_stock, replace)
			//graph save ac_stock, replace
			pac e_stock, ylabels(-.4(.2).6) name(pac_stock, replace)
			//graph save pac_stock, replace
			graph combine ac_stock pac_stock, rows(2) cols(1)
			drop e_*
			
			** ARIMA
			arima a_stock grav_term_bond_stock grav_term_house_stock  ///
				acc_ddot_stock acc_sdot_stock lag_v_dot_stock if year >= 1981, ar(1) ma() 
			estat aroots	
			
			** Net v_dot term
			gen double net_a_stock			= a_stock - 4.0 * v_dot_stock
			reg net_a_stock grav_term_bond_stock grav_term_house_stock  ///
				acc_ddot_stock acc_sdot_stock if year >= 1981
			
			** Initial arima
			predict e_stock, xb
			replace e_stock 				= a_stock - e_stock		//Convert to error
			** Correlogram
			ac  e_stock, ylabels(-.4(.2).6) name(ac_stock, replace)
			//graph save ac_stock, replace
			pac e_stock, ylabels(-.4(.2).6) name(pac_stock, replace)
			//graph save pac_stock, replace
			graph combine ac_stock pac_stock, rows(2) cols(1)
			drop e_*
			
			** ARIMA
			arima net_a_stock grav_term_bond_stock grav_term_house_stock  ///
				acc_ddot_stock acc_sdot_stock if year >= 1981, ar(1) ma() 
			estat aroots	
								
			***********
			** Bond
			***********
										
			** Initial reg
			reg a_bond grav_term_stock_bond grav_term_house_bond  ///
				acc_ddot_bond acc_sdot_bond lag_v_dot_bond if year >= 1981
				
			** Initial arima
			predict e_bond, xb
			replace e_bond 				= a_bond - e_bond		//Convert to error
			** Correlogram
			ac  e_bond, ylabels(-.4(.2).6) name(ac_bond, replace)
			//graph save ac_bond, replace
			pac e_bond, ylabels(-.4(.2).6) name(pac_bond, replace)
			//graph save pac_bond, replace
			graph combine ac_bond pac_bond, rows(2) cols(1)
			drop e_*
			
			** ARIMA
			arima a_bond grav_term_stock_bond grav_term_house_bond  ///
				acc_ddot_bond acc_sdot_bond lag_v_dot_bond if year >= 1981, ar(1) ma() 
			estat aroots	
			arima a_bond grav_term_stock_bond grav_term_house_bond  ///
				acc_ddot_bond acc_sdot_bond lag_v_dot_bond if year >= 1981, ar() ma(1) 
			estat aroots	
			
			** Net v_dot term
			gen double net_a_bond			= a_bond - 7.2 * v_dot_bond
			reg net_a_bond grav_term_stock_bond grav_term_house_bond  ///
				acc_ddot_bond acc_sdot_bond if year >= 1981
				
			** Initial arima
			predict e_bond, xb
			replace e_bond 				= a_bond - e_bond		//Convert to error
			** Correlogram
			ac  e_bond, ylabels(-.4(.2).6) name(ac_bond, replace)
			//graph save ac_bond, replace
			pac e_bond, ylabels(-.4(.2).6) name(pac_bond, replace)
			//graph save pac_bond, replace
			graph combine ac_bond pac_bond, rows(2) cols(1)
			drop e_*
				
			** ARIMA
			arima net_a_bond grav_term_stock_bond grav_term_house_bond  ///
				acc_ddot_bond acc_sdot_bond if year >= 1981, ar(1) ma() 
			estat aroots	
			arima net_a_bond grav_term_stock_bond grav_term_house_bond  ///
				acc_ddot_bond acc_sdot_bond if year >= 1981, ar() ma(1) 
			estat aroots		
			arima net_a_bond grav_term_stock_bond grav_term_house_bond  ///
			acc_ddot_bond acc_sdot_bond if year >= 1981, ar(1) ma(2) 
			estat aroots		
			
			***********
			** SUR
			***********
			** Initial reg
			reg a_stock grav_term_bond_stock grav_term_house_stock  	///
				acc_ddot_stock acc_sdot_stock lag_v_dot_stock if year >= 1981
			reg a_bond grav_term_stock_bond grav_term_house_bond  		///
				acc_ddot_bond acc_sdot_bond lag_v_dot_bond if year >= 1981	
			reg a_house grav_term_stock_house grav_term_bond_house  	///
				acc_ddot_house acc_sdot_house lag_v_dot_house if year >= 1981
			** SUR
			sureg (a_stock grav_term_bond_stock grav_term_house_stock  	///
				acc_ddot_stock acc_sdot_stock lag_v_dot_stock) 			///
				(a_bond grav_term_stock_bond grav_term_house_bond  		///
				acc_ddot_bond acc_sdot_bond lag_v_dot_bond) 			///
				(a_house grav_term_stock_house grav_term_bond_house 	///
				acc_ddot_house acc_sdot_house lag_v_dot_house) if year >= 1981
			
		} //end if
		di "Done with Acceleration."
	
		////////////
		** Velocity
		** General rocket + gravity
		////////////
		scalar gen_vel = 1111
		if gen_vel == 1 {
			
			** Load
			cd_nb_stage
			use arima_data, clear
										
			***********
			** House
			***********
			
			** Initial reg
			reg v_house grav_term2_stock_house grav_term2_bond_house  ///
				acc_ddot2_house acc_sdot2_house lag_v_dot2_house if year >= 1981
				
			** Initial arima
			predict e_house, xb
			replace e_house 				= a_house - e_house		//Convert to error
			** Correlogram
			ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
			//graph save ac_house, replace
			pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
			//graph save pac_house, replace
			graph combine ac_house pac_house, rows(2) cols(1)
			drop e_*
			
			** ARIMA
			arima v_house grav_term2_stock_house grav_term2_bond_house  ///
				acc_ddot2_house acc_sdot2_house lag_v_dot2_house if year >= 1981, ar(1) ma() 
			estat aroots	
													
			***********
			** Stock
			***********
			
			** Initial reg
			reg v_stock grav_term2_bond_stock grav_term2_house_stock  ///
				acc_ddot2_stock acc_sdot2_stock lag_v_dot2_stock if year >= 1981
				
			** Initial arima
			predict e_stock, xb
			replace e_stock 				= v_stock - e_stock		//Convert to error
			** Correlogram
			ac  e_stock, ylabels(-.4(.2).6) name(ac_stock, replace)
			//graph save ac_stock, replace
			pac e_stock, ylabels(-.4(.2).6) name(pac_stock, replace)
			//graph save pac_stock, replace
			graph combine ac_stock pac_stock, rows(2) cols(1)
			drop e_*
			
			** ARIMA
			arima v_stock grav_term2_bond_stock grav_term2_house_stock  ///
				acc_ddot2_stock acc_sdot2_stock lag_v_dot2_stock if year >= 1981, ar(2) ma() 
			estat aroots	
			arima v_stock grav_term2_bond_stock grav_term2_house_stock  ///
				acc_ddot2_stock acc_sdot2_stock lag_v_dot2_stock if year >= 1981, ar() ma(2) 
			estat aroots	
																				
			***********
			** Bond
			***********
										
			** Initial reg
			reg v_bond grav_term2_stock_bond grav_term2_house_bond  ///
				acc_ddot2_bond acc_sdot2_bond lag_v_dot2_bond if year >= 1981
				
			** Initial arima
			predict e_bond, xb
			replace e_bond 				= v_bond - e_bond		//Convert to error
			** Correlogram
			ac  e_bond, ylabels(-.4(.2).6) name(ac_bond, replace)
			//graph save ac_bond, replace
			pac e_bond, ylabels(-.4(.2).6) name(pac_bond, replace)
			//graph save pac_bond, replace
			graph combine ac_bond pac_bond, rows(2) cols(1)
			drop e_*
			
			** ARIMA
			arima v_bond grav_term2_stock_bond grav_term2_house_bond  ///
				acc_ddot2_bond acc_sdot2_bond lag_v_dot2_bond if year >= 1981, ar() ma(1) 
			estat aroots	
			
		} //end if
		di "Done with Velocity."
	
		////////////
		** Rate r
		** General rocket + gravity
		////////////
		scalar gen_rate = 1111
		if gen_rate == 1 {
			
			** Load
			cd_nb_stage
			use arima_data, clear
			
			** Save turingbot
			order *stock* *bond* *house*
			order year r_* v_* a_* j_* lag_r_* lag_v_* lag_a_* lag_j_* lag_m_* lag_acd_* lag_acs_*
			keep year r_* v_* a_* j_* lag_r_* lag_v_* lag_a_* lag_j_* lag_m_* lag_acd_* lag_acs_*
			drop *dot*
			drop *price*
			drop if lag_m_stock == .
			cd_nb_stage
			save turingbot_data, replace
			use turingbot_data, clear
			
				drop if year < 1948
				drop r_stock r_bond r_house v_stock v_bond a_stock a_bond a_house
				replace v_house 			= v_house * 100
				
			** Load
			cd_nb_stage
			use arima_data, clear
										
			***********
			** House
			***********
			
			** Initial reg - won't work for rate, check accel
			reg r_house grav_term2_stock_house grav_term2_bond_house  ///
				acc_ddot2_house acc_sdot2_house lag_r_dot_house lag2_r_dot_house if year >= 1949, noconstant
				
			** Corr
			corr r_house grav_term2_stock_house grav_term2_bond_house  ///
				acc_ddot2_house acc_sdot2_house lag_r_dot_house lag2_r_dot_house if year >= 1949
			** Initial arima
			predict e_house, xb
			replace e_house 				= a_house - e_house		//Convert to error
			** Correlogram
			ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
			//graph save ac_house, replace
			pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
			//graph save pac_house, replace
			graph combine ac_house pac_house, rows(2) cols(1)
			drop e_*
			
			** ARIMA
			** House rate rocket equation is AR-1 stationary in conditioned expression (already includes some lag terms) 
			arima r_house grav_term2_stock_house grav_term2_bond_house  ///
				acc_ddot2_house acc_sdot2_house lag_r_dot_house lag2_r_dot_house if year >= 1981, ar(1) ma(1) 
			estat aroots	
			arima r_house grav_term2_stock_house grav_term2_bond_house  ///
				acc_ddot2_house acc_sdot2_house lag_r_dot_house lag2_r_dot_house if year >= 1981, ar(1 2 3 12) ma(1)  technique(bhhh)
			estat aroots	
			arima r_house grav_term2_stock_house grav_term2_bond_house  ///
				acc_ddot2_house acc_sdot2_house lag_r_dot_house lag2_r_dot_house if year >= 1981, ar() ma(1) 
			estat aroots	
							
			** Reload
			cd_nb_stage
			use arima_data, clear
								
			** Approximations
			set seed	101
			gen randsample			= runiform()
			sort randsample
			gen ob					= _n
			sum ob
			local holdout			= 0.70
			local upper				= ceil(r(max) * `holdout')
			gen incl 				= (ob <= `upper')
				di "Upper is `upper', holdout is `holdout'."
				sum ob randsample incl if year >= 1900
				tab incl if year >= 1900
			replace incl			= (incl==1 & year >= 1900)
			//replace incl			= (incl==1)
									
			** Linear -- 46.76% loss, 85.66% velocity, 84.21% accel. // 43.87%, 73.6%, 86.6% 1949 //13.95 16.22 68.7 1900
			reg r_house lag_r_bond lag_r_stock lag_r_house lag_m_stock lag_m_bond lag_m_house lag_acd_stock lag_acs_stock lag_acd_bond lag_acs_bond lag_acd_house lag_acs_house if (incl)
			fit_nb r_house 
									
			reg v_house lag_r_bond lag_r_stock lag_r_house lag_m_stock lag_m_bond lag_m_house lag_acd_stock lag_acs_stock lag_acd_bond lag_acs_bond lag_acd_house lag_acs_house if (incl)
			fit_nb v_house 
			
			reg a_house lag_r_bond lag_r_stock lag_r_house lag_m_stock lag_m_bond lag_m_house lag_acd_stock lag_acs_stock lag_acd_bond lag_acs_bond lag_acd_house lag_acs_house if (incl)
			fit_nb a_house 
			
			** Test Expansion
			** larger -- 46.18% loss 1981, 45.3% 1949, 12.62% 1900
			reg r_house lag_r_bond lag_r_stock lag_r_house c.lag_m_stock#c.lag_m_stock lag_m_bond c.lag_m_house#c.lag_m_house c.lag_acd_stock#c.lag_acd_stock c.lag_acs_stock#c.lag_acs_stock lag_acd_bond ///
				lag_acs_bond c.lag_acd_house##c.lag_acd_house c.lag_acs_house#c.lag_acs_house if (incl)
			fit_nb r_house
			** smaller -- 41.19% loss 1981, 45.1% 1949, 14.65% 1900
			reg r_house lag_r_bond lag_r_stock lag_r_house lag_m_stock lag_m_bond lag_m_house lag_acd_stock c.lag_acs_stock#c.lag_acs_stock lag_acd_bond ///
				lag_acs_bond c.lag_acd_house##c.lag_acd_house c.lag_acs_house#c.lag_acs_house if (incl)
			fit_nb r_house
			
			** Generate Expansions
			global nams "stock bond house"
			global namsac "acs acd"
			pause on
		
			** 2nd order  
			** Rate loop -- no value add -- housing rate is linear in lagged housing rate
			foreach nam of global nams {
				
				reg r_house c.lag_r_`nam'##c.lag_r_`nam' lag_r_bond lag_r_stock lag_r_house lag_m_stock lag_m_bond lag_m_house lag_acd_stock lag_acs_stock lag_acd_bond lag_acs_bond lag_acd_house lag_acs_house if year >= 1981
				** Plot
				sum lag_r_`nam'
				quietly margins , at(lag_r_`nam' = (4 (0.1) 8) ) 			
				marginsplot, recast(line) recastci(rarea)
				
				* Fit
				fit_nb r_house
				
				//pause
				
			} //end loop
			di "Done with loop expansion check r."
							
			** Mass loop
			** stock mass - U - almost no lin
			** U housing mass - plus lin
			foreach nam of global nams {
				
				reg r_house c.lag_m_`nam'#c.lag_m_`nam' lag_r_bond lag_r_stock lag_r_house lag_m_stock lag_m_bond lag_m_house lag_acd_stock lag_acs_stock lag_acd_bond lag_acs_bond lag_acd_house lag_acs_house if year >= 1981
				** Plot
				qui margins , at(lag_m_`nam' = (1 (1000) 50000) ) 			
				marginsplot, recast(line) recastci(rarea)
				
				//pause
				
			} //end loop
			di "Done with loop expansion check m."
				
			** Acc loop
			** U in lag_acd_stock - no lin
			** U in acd_house - plus lin
			** Inverse U in acs_stock, acs_house - no lin
			** Decr in acd_house, acd_bond (or U)
			foreach nam of global nams {
				
				foreach nac of global namsac {
						
						di "Beginnin nam: `nam', nac: `nac'."
					
					reg r_house c.lag_`nac'_`nam'#c.lag_`nac'_`nam' lag_r_bond lag_r_stock lag_r_house lag_m_stock lag_m_bond lag_m_house lag_acd_stock lag_acs_stock lag_acd_bond lag_acs_bond lag_acd_house lag_acs_house if year >= 1981
					
					** Plot
					quietly margins , at(lag_`nac'_`nam' = (-1000000 (10000) 1000000) ) 			
					marginsplot, recast(line) recastci(rarea)
					
						sum lag_`nac'_`nam' year r_house

					//pause
				
				} //end loop ac
				di "Done with AC loop."
				
			} //end loop
			di "Done with loop expansion check acs."
			
			** Resulting 2nd-order terms
			reg r_house lag_r_bond lag_r_stock lag_r_house c.lag_m_stock#c.lag_m_stock lag_m_bond c.lag_m_house#c.lag_m_house c.lag_acd_stock#c.lag_acd_stock c.lag_acs_stock#c.lag_acs_stock lag_acd_bond ///
				lag_acs_bond c.lag_acd_house##c.lag_acd_house c.lag_acs_house#c.lag_acs_house if year >= 1981
			reg r_house lag_r_bond lag_r_stock lag_r_house c.lag_m_stock lag_m_bond c.lag_m_house c.lag_acd_stock c.lag_acs_stock#c.lag_acs_stock lag_acd_bond ///
				lag_acs_bond c.lag_acd_house##c.lag_acd_house c.lag_acs_house#c.lag_acs_house if year >= 1949
			
			** Check sig 2nd-order effects
			sum lag_m_stock lag_m_house lag_acd_stock lag_acs_stock lag_acd_house lag_acs_house if year >= 1949
			** Stock m - none
			quietly margins , at(lag_m_stock = (2000 (1000) 50000) ) 		
			marginsplot, recast(line) recastci(rarea)
			** House m - none
			quietly margins , at(lag_m_house = (5000 (1000) 50000) ) 		
			marginsplot, recast(line) recastci(rarea)
			** Stock acd - none
			quietly margins , at(lag_acd_stock = (-8000 (100) 10000) ) 		
			marginsplot, recast(line) recastci(rarea)
			** Stock acs - none -- now yes
			quietly margins , at(lag_acs_stock = (-3000 (100) 2000) ) 		
			marginsplot, recast(line) recastci(rarea)
			** House acd - yes
			quietly margins , at(lag_acd_house = (-3000000 (100000) 7000000) ) 		
			marginsplot, recast(line) recastci(rarea)
			** House acs - none
			quietly margins , at(lag_acs_house = (-40000 (10000) 500000) ) 		
			marginsplot, recast(line) recastci(rarea)
			
			** 2nd order OOS
			reg r_house lag_r_bond lag_r_stock lag_r_house c.lag_m_stock lag_m_bond c.lag_m_house c.lag_acd_stock c.lag_acs_stock#c.lag_acs_stock lag_acd_bond ///
				lag_acs_bond c.lag_acd_house##c.lag_acd_house c.lag_acs_house#c.lag_acs_house if year >= 1949
			
			asdf_nonlin	
			
			***********
			** Stock
			***********
			
			** Initial reg
			reg r_stock grav_term2_bond_stock grav_term2_house_stock  ///
				acc_ddot2_stock acc_sdot2_stock lag_r_dot_stock lag2_r_dot_stock if year >= 1981
				
			** Initial arima
			predict e_stock, xb
			replace e_stock 				= v_stock - e_stock		//Convert to error
			** Correlogram
			ac  e_stock, ylabels(-.4(.2).6) name(ac_stock, replace)
			//graph save ac_stock, replace
			pac e_stock, ylabels(-.4(.2).6) name(pac_stock, replace)
			//graph save pac_stock, replace
			graph combine ac_stock pac_stock, rows(2) cols(1)
			drop e_*
			
			** ARIMA
																		
			***********
			** Bond
			***********
										
			** Initial reg
			reg r_bond grav_term2_stock_bond grav_term2_house_bond  ///
				acc_ddot2_bond acc_sdot2_bond lag_r_dot_bond lag2_r_dot_bond if year >= 1981
				
			** Initial arima
			predict e_bond, xb
			replace e_bond 				= v_bond - e_bond		//Convert to error
			** Correlogram
			ac  e_bond, ylabels(-.4(.2).6) name(ac_bond, replace)
			//graph save ac_bond, replace
			pac e_bond, ylabels(-.4(.2).6) name(pac_bond, replace)
			//graph save pac_bond, replace
			graph combine ac_bond pac_bond, rows(2) cols(1)
			drop e_*
			
			** ARIMA
			arima r_bond grav_term2_stock_bond grav_term2_house_bond  ///
				acc_ddot2_bond acc_sdot2_bond lag_r_dot_bond lag2_r_dot_bond if year >= 1981, ar(1) ma() 
			estat aroots	
			arima r_bond grav_term2_stock_bond grav_term2_house_bond  ///
				acc_ddot2_bond acc_sdot2_bond lag_r_dot_bond lag2_r_dot_bond if year >= 1981, ar() ma(1) 
			estat aroots
			arima r_bond grav_term2_stock_bond grav_term2_house_bond  ///
				acc_ddot2_bond acc_sdot2_bond lag_r_dot_bond lag2_r_dot_bond if year >= 1981, ar() ma(1 2 3) 
			estat aroots
			arima r_bond grav_term2_stock_bond grav_term2_house_bond  ///
				acc_ddot2_bond acc_sdot2_bond lag_r_dot_bond lag2_r_dot_bond if year >= 1981, ar() ma(2) 
			estat aroots
			
			** Approximations
			
									
			***********
			** Ornstein-Uhlenbeck model
			** Continuous time analog to the AR(1)
			** William Smith, February 2010, On the Simulation and Estimation of the Mean-Reverting Ornstein-Uhlenbeck Process
			***********
			scalar orn == 1
			if orn == 1 {
				
			** Load
			cd_nb_stage
			use arima_data, clear
					
				**********	
				** Stock
				** Naive LS
				** Initial reg
				reg v_stock lag_r_stock if year >= 1981
				* lamda = b
				nlcom _b[lag_r_stock]
				* mu = a / b
				nlcom _b[_cons] /  _b[lag_r_stock]
				* sigma = se(Epsilon)
				local sde = e(rmse)
					di "sde: `sde'."
				scalar sde = e(rmse)
					scalar list sde
				** Exact LS
				** Initial reg
				reg r_stock lag_r_stock if year >= 1981
				* lamda = -ln(b)
				nlcom -1*ln(_b[lag_r_stock]) 
				* mu = a / (1-b)
				nlcom _b[_cons] /  (1 - _b[lag_r_stock])
				* sigma = f(Epsilon, mu, lamda)
				scalar sde = e(rmse)
					scalar list sde
				nlcom sde * sqrt( 2 * (-1*ln(_b[lag_r_stock])/*end ln*/)/*end lambda*/ / (1-exp(-1 * 2* (-1*ln(_b[lag_r_stock])/*end ln*/)/*end lambda*/ )/*end exp*/)/*end denom*/) /*end sqrt*/
					
				** Compare to AR(1)
				** Correlogram
				ac  r_stock, ylabels(-.4(.2).6) name(ac_stock, replace)
				pac r_stock, ylabels(-.4(.2).6) name(pac_stock, replace)
				//graph save pac_stock, replace
				graph combine ac_stock pac_stock, rows(2) cols(1)
				** ARIMA
				arima r_stock if year >= 1981, ar(1) ma() 
				estat aroots	
												
				**********	
				** Bond						
				** Naive LS
				** Initial reg
				reg v_bond lag_r_bond //if year >= 1949
				* lamda = b
				nlcom _b[lag_r_bond]
				* mu = a / b
				nlcom _b[_cons] /  _b[lag_r_bond]
				* sigma = se(Epsilon)
				scalar sde = e(rmse)
					scalar list sde
				** Exact LS
				** Initial reg
				reg r_bond lag_r_bond if year >= 1981
				* lamda = -ln(b)
				nlcom -1*ln(_b[lag_r_bond]) 
				* mu = a / (1-b)
				nlcom _b[_cons] /  (1 - _b[lag_r_bond])
				* sigma = f(Epsilon, mu, lamda)
				scalar sde = e(rmse)
					scalar list sde
				nlcom sde * sqrt( 2 * (-1*ln(_b[lag_r_bond])/*end ln*/)/*end lambda*/ / (1-exp(-1 * 2* (-1*ln(_b[lag_r_bond])/*end ln*/)/*end lambda*/ )/*end exp*/)/*end denom*/) /*end sqrt*/
					
				**********	
				** House	
				** Naive LS
				** Initial reg
				reg v_house lag_r_house if year >= 1981
				* lamda = b
				nlcom _b[lag_r_house]
				* mu = a / b
				nlcom _b[_cons] /  _b[lag_r_house]
				* sigma = se(Epsilon)
				scalar sde = e(rmse)
					scalar list sde
				** Exact LS
				** Initial reg
				reg r_house lag_r_house if year >= 1981
				* lamda = -ln(b)
				nlcom -1*ln(_b[lag_r_house]) 
				* mu = a / (1-b)
				nlcom _b[_cons] /  (1 - _b[lag_r_house])
				* sigma = f(Epsilon, mu, lamda)
				scalar sde = e(rmse)
					scalar list sde
				nlcom sde * sqrt( 2 * (-1*ln(_b[lag_r_house])/*end ln*/)/*end lambda*/ / (1-exp(-1 * 2* (-1*ln(_b[lag_r_house])/*end ln*/)/*end lambda*/ )/*end exp*/)/*end denom*/) /*end sqrt*/
			
				** Compare to AR(1)
				** Correlogram
				ac  r_house, ylabels(-.4(.2).6) name(ac_house, replace)
				pac r_house, ylabels(-.4(.2).6) name(pac_house, replace)
				//graph save pac_house, replace
				graph combine ac_house pac_house, rows(2) cols(1)
				** ARIMA
				arima r_house if year >= 1981, ar(1) ma() 
				estat aroots	
				
			} //end if
			di "Done with Ornstein-Uhlenbeck."
			
		} //end if
		di "Done with Velocity."
			
		////////////
		** 1. Ideal rocket
		////////////
		scalar rocket = 1111
		if rocket == 1 {
			
			** Load
			cd_nb_stage
			use arima_data, clear
				
			** Need welfare decomposition of price (valuation) and quanity effects here
			
			** Unconditional estimates of ejected mass average velocity
			** Market price of risk Lambda ~= 0.20: 0.2 percent higher per standard deviation volatility - holds for all three approximately
			sum u_* r_* v_* rr_* year if year 
			sum u_* r_* rr_* year if year >= 1945 
			sum u_* r_* rr_* year if year >= 1981 
				
			** Estimate "u" 
			** If u_hat is positive, velocity interaction term == negative 1 -- ablating, switching signs -- accreting 
			** (4.9.25 p.3) estimate of average velocity of the ejected mass
			** Conditional estimates of mean ejected velocity
			** Here, the first coefficient b1 is "u" (4.9.25 p.3) estimate of velocity of the ejected mass
			** Updated to 4.16.25 p1 -- inverse of the fM variable less interaction term int_
			** Post 1981
			reg a_stock fminv_stock	int_stock	if year>1981, vce(robust)  
			reg a_bond  fminv_bond 	int_bond	if year>1981, vce(robust)  
			reg a_house fminv_house int_house	if year>1981, vce(robust)  
		
			reg a_house indu_house#c.fminv_house int_house	if year>1981, vce(robust)  
		
			** Acceleration a - house
			reg a_house fminv_house indu_house int_house, vce(robust) 
			reg a_house fminv_house indu_house int_house
			predict e_house, xb
			replace e_house 				= r_house - e_house		//Convert to error
			** Correlogram
			ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
			//graph save ac_house, replace
			pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
			//graph save pac_house, replace
			graph combine ac_house pac_house, rows(2) cols(1)
			drop e_*
			** ARIMA
			arima a_house fminv_house indu_house int_house, ar(1 2) ma() 
			estat aroots
			
		} //end if
		di "Done with perfect rocket."
					
		////////////
		** 3-body - motion
		////////////
		scalar threeb = 1111
		if threeb == 1 {
			
			** Load
			cd_nb_stage
			use arima_data, clear
				
			** Market price of risk Lambda ~= 0.20: 0.2 percent higher per standard deviation volatility - holds for all three approximately
			sum u_* r_* rr_* year if year >= 1890 
			sum u_* r_* rr_* year if year >= 1945 
				
			** Position r - stock  = AR(2) process by 3-body theory
			reg r_stock lag_m_bond lag_m_house lag_d_*_stock lag_in_*_stock L.r_stock L2.r_stock, vce(robust) //excludes lags
			reg r_stock lag_m_bond lag_m_house lag_d_*_stock lag_in_*_stock //excludes lags
			predict e_stock, xb
			replace e_stock 				= r_stock - e_stock		//Convert to error
			** Correlogram
			ac  e_stock, ylabels(-.4(.2).6) name(ac_stock, replace)
			//graph save ac_stock, replace
			pac e_stock, ylabels(-.4(.2).6) name(pac_stock, replace)
			//graph save pac_stock, replace
			graph combine ac_stock pac_stock, rows(2) cols(1)
			drop e_*
			** ARIMA
			arima r_stock lag_m_bond lag_m_house lag_d_*_stock lag_in_*_stock, ar(1 2) ma() 
			estat aroots
			
			** Position r - house = AR(2) process by 3-body theory
			reg r_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house L.r_house L2.r_house, vce(robust) //excludes lags
			reg r_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house //excludes lags
			predict e_house, xb
			replace e_house 				= r_house - e_house		//Convert to error
			** Correlogram
			ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
			//graph save ac_house, replace
			pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
			//graph save pac_house, replace
			graph combine ac_house pac_house, rows(2) cols(1)
			drop e_*
			** ARIMA
			arima r_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house, ar(1 2) ma() 
			estat aroots
			
			** Velocity v - house = AR(1) process by 3-body theory
			reg v_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house L.v_house, vce(robust) //look at flexible
			reg v_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house //excludes lags - reg for correlogram
			predict e_house, xb
			replace e_house 				= r_house - e_house		//Convert to error
			** Correlogram
			ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
			//graph save ac_house, replace
			pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
			//graph save pac_house, replace
			graph combine ac_house pac_house, rows(2) cols(1)
			drop e_*
			** ARIMA
			arima v_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house, ar(1) ma() 					
			estat aroots
			
			** Acceleration a - house = AR(0) process by 3-body theory
			reg a_house c.lag_m_stock#c.lag_d_stock_house#c.lag_in_stock_house c.lag_m_bond#c.lag_d_bond_house#c.lag_in_bond_house , vce(robust) //excludes lags
			reg a_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house //excludes lags
			predict e_house, xb
			replace e_house 				= r_house - e_house		//Convert to error
			** Correlogram
			ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
			//graph save ac_house, replace
			pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
			//graph save pac_house, replace
			graph combine ac_house pac_house, rows(2) cols(1)
			drop e_*
			** ARIMA
			arima a_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house, ar(1) ma() 
			arima a_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house, ar() ma(1) 
			estat aroots
			
			** Jolt j - house = AR(0) process by 3-body theory
			reg j_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house L.lag_m_bond L.lag_m_stock L.lag_d_stock_house L.lag_in_bond_house , vce(robust) //excludes lags
			reg j_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house //excludes lags
			predict e_house, xb
			replace e_house 				= r_house - e_house		//Convert to error
			** Correlogram
			ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
			//graph save ac_house, replace
			pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
			//graph save pac_house, replace
			graph combine ac_house pac_house, rows(2) cols(1)
			drop e_*
			** ARIMA
			arima j_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house, ar(1 2) ma() 
			estat aroots
			
		} //end if
		di "Done with 3-body."
		
		******************************
		** N-Body - Special cases - archive
		** 1. Rocket - special
		** 2. 3-Body - special
		******************************
		scalar nb 					= 1111
		if nb == 1 {
		
			**************************
			** Prep Relative distances
			**************************
			global nam "stock bond house price"
			** Stats loop
			** Primary
			foreach pri of global nam {

					di "Primary velocity and accel: `pri'."
					
				******************
				** NB variables
				** 4.16.25 p.1
				******************
				
				** Velocity
				gen double v_`pri'				= r_`pri' - L.r_`pri' 
				gen double lag_v_`pri'			= L.v_`pri'
				
				** Acceleration
				gen double a_`pri'				= v_`pri' - L.v_`pri' 
				gen double lag_a_`pri'			= L.a_`pri'
				
				** Jolt (Jerk)
				gen double j_`pri'				= a_`pri' - L.a_`pri' 
				gen double lag_j_`pri'			= L.j_`pri'
				
				** Mass
				gen double lag_w_`pri'			= L.w_`pri'
				
				** Ablation
				//gen double ab_`pri'			= ni_`pri'
					
				******************
				** Rocket variables
				** 4.9.25 p.3
				******************
				
				** Percent change in mass - ln (m1 / m0)
				//gen double mdot_`pri'			= ln(F1.w_`pri' / w_`pri')  // this is ln (m0 / m1)
				//gen double mdotinv_`pri'		= mdot_`pri' ^ (-1)			// this is ln (m1 / m0)
				
				** Lagged values for rocket
				//gen double lag_mdot_`pri'		= L.mdotinv_`pri'
				
				** Ejected velocity u - rocket
				//gen double u_`pri'				= mdot_`pri' * F1.a_`pri' + v_`pri'
				
				******************
				** Rocket variables
				** 4.16.25 p1
				******************
				
				** Separate quantity change from price change here? -- at indu_* indicator 4.16.25
				
				** Percent change in mass - ln (m1 / m0)
				** Assumes change in mass is mass ablation/accretion -- but only some of the mass is ablating, 
				**   A portion is just disappearing (price change with no quantity change. Where does it go?
				gen double lnm_`pri'			= ln(w_`pri' / F1.w_`pri' )  // this is ln (m1 / m0)
				gen double fm_`pri'			= 1 - lnm_`pri' ^ (-1)			
				gen double fminv_`pri'			= fm_`pri' ^ (-1)			
				gen double int_`pri'			= lag_v_`pri' * fminv_`pri'
									
				** Ejected velocity u - rocket
				gen double u_`pri'				= F1.v_`pri' + a_`pri'  * fm_`pri'
				gen double indu_`pri'			= w_`pri' > F1.w_`pri'
				
				** Secondary
				foreach sec of global nam  {
					
						di "Starting primary: `pri' and secondary: `sec'."
					
					******************
					** NB variables
					** 4.16.25 p.1
					******************
					
					** Distance
					gen double d_`sec'_`pri'				= r_`sec' - r_`pri' 
					gen double lag_d_`sec'_`pri'			= L.d_`sec'_`pri'
												
					** Normed distance
					gen double n_`sec'_`pri'				= abs(d_`sec'_`pri')^3
					gen double lag_n_`sec'_`pri'			= L.n_`sec'_`pri'
					
					** Inververse normed distance
					gen double in_`sec'_`pri'				= 1/n_`sec'_`pri'
					gen double lag_in_`sec'_`pri'			= L.in_`sec'_`pri'

					******************
					** Rocket variables
					** 4.9.25 p.3
					******************

					** Mass-distance
					gen double md_`pri'_`sec'				= w_`sec' * d_`sec'_`pri'
								
					** Linear term
					gen double c_`sec'_`pri'				= w_`sec' * d_`sec'_`pri' * in_`sec'_`pri'
								
				} //end loop
				di "Done with seconary loop for primary: `pri'."
				
				** Delete diagonal elements
				drop *_`pri'_`pri'
				
			} //end loop
			di "Done with relative distance loop."
			
			** Rename mass variables
			rename w_* m_*
			rename *_w_* *_m_*
			
			** Drop
			drop r_priceR
			drop m_price
			drop *_price*
								
				** Order
				order *, alpha
				order *stock* *bond* *house* *price*
				order n t year month dt period r_* v_* a_* j_* m_* d_* n_* in_* lag_*
		
			** Save
			cd_nb_stage
			save arima_data, replace
		
			////////////
			** 1. Ideal rocket
			////////////
			scalar rocket = 1
			if rocket == 1 {
				
				** Load
				cd_nb_stage
				use arima_data, clear
					
				** Need welfare decomposition of price (valuation) and quanity effects here
				
				** Unconditional estimates of ejected mass average velocity
				** Market price of risk Lambda ~= 0.20: 0.2 percent higher per standard deviation volatility - holds for all three approximately
				sum u_* r_* v_* rr_* year if year 
				sum u_* r_* rr_* year if year >= 1945 
				sum u_* r_* rr_* year if year >= 1981 
					
				** Estimate "u" 
				** If u_hat is positive, velocity interaction term == negative 1 -- ablating, switching signs -- accreting 
				** (4.9.25 p.3) estimate of average velocity of the ejected mass
				** Conditional estimates of mean ejected velocity
				** Here, the first coefficient b1 is "u" (4.9.25 p.3) estimate of velocity of the ejected mass
				** Updated to 4.16.25 p1 -- inverse of the fM variable less interaction term int_
				** Post 1981
				reg a_stock fminv_stock	int_stock	if year>1981, vce(robust)  
				reg a_bond  fminv_bond 	int_bond	if year>1981, vce(robust)  
				reg a_house fminv_house int_house	if year>1981, vce(robust)  
			
				reg a_house indu_house#c.fminv_house int_house	if year>1981, vce(robust)  
			
				** Acceleration a - house
				reg a_house fminv_house indu_house int_house, vce(robust) 
				reg a_house fminv_house indu_house int_house
				predict e_house, xb
				replace e_house 				= r_house - e_house		//Convert to error
				** Correlogram
				ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
				//graph save ac_house, replace
				pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
				//graph save pac_house, replace
				graph combine ac_house pac_house, rows(2) cols(1)
				drop e_*
				** ARIMA
				arima a_house fminv_house indu_house int_house, ar(1 2) ma() 
				estat aroots
				
			} //end if
			di "Done with perfect rocket."
			
			////////////
			** 1.1 Rocket - Mass transfer
			////////////
			scalar rocket = 1
			if rocket == 1 {
				
				** Load
				cd_nb_stage
				use arima_data, clear
					
				** Need welfare decomposition of price (valuation) and quanity effects here
				
				
				
				omojmnlklkk
					
				** Estimate "u" 
				** If u_hat is positive, velocity interaction term == negative 1 -- ablating, switching signs -- accreting 
				** (4.9.25 p.3) estimate of average velocity of the ejected mass
				** Conditional estimates of mean ejected velocity
				** Here, the first coefficient b1 is "u" (4.9.25 p.3) estimate of velocity of the ejected mass
				** Updated to 4.16.25 p1 -- inverse of the fM variable less interaction term int_
				** Post 1981
				reg a_stock fminv_stock	int_stock	if year>1981, vce(robust)  
				reg a_bond  fminv_bond 	int_bond	if year>1981, vce(robust)  
				reg a_house fminv_house int_house	if year>1981, vce(robust)  
			
				reg a_house indu_house#c.fminv_house int_house	if year>1981, vce(robust)  
			
				** Acceleration a - house
				reg a_house fminv_house indu_house int_house, vce(robust) 
				reg a_house fminv_house indu_house int_house
				predict e_house, xb
				replace e_house 				= r_house - e_house		//Convert to error
				** Correlogram
				ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
				//graph save ac_house, replace
				pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
				//graph save pac_house, replace
				graph combine ac_house pac_house, rows(2) cols(1)
				drop e_*
				** ARIMA
				arima a_house fminv_house indu_house int_house, ar(1 2) ma() 
				estat aroots
				
			} //end if
			di "Done with transfer rocket."
						
			////////////
			** 3-body - motion
			////////////
			scalar threeb = 1
			if threeb == 1 {
				
				** Load
				cd_nb_stage
				use arima_data, clear
					
				** Market price of risk Lambda ~= 0.20: 0.2 percent higher per standard deviation volatility - holds for all three approximately
				sum u_* r_* rr_* year if year >= 1890 
				sum u_* r_* rr_* year if year >= 1945 
					
				** Position r - stock  = AR(2) process by 3-body theory
				reg r_stock lag_m_bond lag_m_house lag_d_*_stock lag_in_*_stock L.r_stock L2.r_stock, vce(robust) //excludes lags
				reg r_stock lag_m_bond lag_m_house lag_d_*_stock lag_in_*_stock //excludes lags
				predict e_stock, xb
				replace e_stock 				= r_stock - e_stock		//Convert to error
				** Correlogram
				ac  e_stock, ylabels(-.4(.2).6) name(ac_stock, replace)
				//graph save ac_stock, replace
				pac e_stock, ylabels(-.4(.2).6) name(pac_stock, replace)
				//graph save pac_stock, replace
				graph combine ac_stock pac_stock, rows(2) cols(1)
				drop e_*
				** ARIMA
				arima r_stock lag_m_bond lag_m_house lag_d_*_stock lag_in_*_stock, ar(1 2) ma() 
				estat aroots
				
				** Position r - house = AR(2) process by 3-body theory
				reg r_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house L.r_house L2.r_house, vce(robust) //excludes lags
				reg r_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house //excludes lags
				predict e_house, xb
				replace e_house 				= r_house - e_house		//Convert to error
				** Correlogram
				ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
				//graph save ac_house, replace
				pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
				//graph save pac_house, replace
				graph combine ac_house pac_house, rows(2) cols(1)
				drop e_*
				** ARIMA
				arima r_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house, ar(1 2) ma() 
				estat aroots
				
				** Velocity v - house = AR(1) process by 3-body theory
				reg v_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house L.v_house, vce(robust) //look at flexible
				reg v_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house //excludes lags - reg for correlogram
				predict e_house, xb
				replace e_house 				= r_house - e_house		//Convert to error
				** Correlogram
				ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
				//graph save ac_house, replace
				pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
				//graph save pac_house, replace
				graph combine ac_house pac_house, rows(2) cols(1)
				drop e_*
				** ARIMA
				arima v_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house, ar(1) ma() 					
				estat aroots
				
				** Acceleration a - house = AR(0) process by 3-body theory
				reg a_house c.lag_m_stock#c.lag_d_stock_house#c.lag_in_stock_house c.lag_m_bond#c.lag_d_bond_house#c.lag_in_bond_house , vce(robust) //excludes lags
				reg a_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house //excludes lags
				predict e_house, xb
				replace e_house 				= r_house - e_house		//Convert to error
				** Correlogram
				ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
				//graph save ac_house, replace
				pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
				//graph save pac_house, replace
				graph combine ac_house pac_house, rows(2) cols(1)
				drop e_*
				** ARIMA
				arima a_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house, ar(1) ma() 
				arima a_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house, ar() ma(1) 
				estat aroots
				
				** Jolt j - house = AR(0) process by 3-body theory
				reg j_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house L.lag_m_bond L.lag_m_stock L.lag_d_stock_house L.lag_in_bond_house , vce(robust) //excludes lags
				reg j_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house //excludes lags
				predict e_house, xb
				replace e_house 				= r_house - e_house		//Convert to error
				** Correlogram
				ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
				//graph save ac_house, replace
				pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
				//graph save pac_house, replace
				graph combine ac_house pac_house, rows(2) cols(1)
				drop e_*
				** ARIMA
				arima j_house lag_m_bond lag_m_stock lag_d_*_house lag_in_*_house, ar(1 2) ma() 
				estat aroots
				
			} //end if
			di "Done with 3-body."
							
			////////////
			** Add risk premium
			////////////
			scalar rocket = 1
			if rocket == 1 {
				
				** Load
				cd_nb_stage
				use arima_data, clear
					
				** Derive risk premia
				reg r_stock r_bond r_house 	if year >=1945, vce(robust)
				reg r_stock r_bond 			if year >=1945, vce(robust)
				reg r_stock r_house 		if year >=1945, vce(robust)
				reg r_house r_stock r_bond 	if year >=1945, vce(robust)
				reg r_house r_bond 			if year >=1945, vce(robust)
				reg r_house r_stock 		if year >=1945, vce(robust)
				reg r_bond r_stock r_house 	if year >=1945, vce(robust)
				reg r_bond r_house 			if year >=1945, vce(robust)
				reg r_bond r_stock 			if year >=1945, vce(robust)
					
				asdf_risk	
					
			} //end if
			di "Done with risk."
		
			////////////
			** Bonds
			////////////
			scalar bon 				= 1
			if bon == 1 {
				
				** Load
				cd_nb_stage
				use arima_data, clear
					
				** Nominal interest rate
				//rename r_bond bond 
				reg r_bond L.r_bond m_* d_*_bond in_*_bond , vce(robust) 
				//reg r_bond L.r_bond c_*_bond , vce(robust) 
				predict e_bond, xb
				replace e_bond 				= bond - e_bond		//Convert to error
				** Correlogram
				ac  e_bond, ylabels(-.4(.2).6) name(ac_bond, replace)
				//graph save ac_bond, replace
				pac e_bond, ylabels(-.4(.2).6) name(pac_bond, replace)
				//graph save pac_bond, replace
				graph combine ac_bond pac_bond, rows(2) cols(1)
				drop e_*
				** ARIMA
				arima r_bond L.r_bond m_* d_*_bond in_*_bond  , ar(2 4) ma(1 3) vce(robust)
				estat aroots
				rename bond r_bond
				
				** Acceleration interest rate
				rename a_bond bond 
				rename m_bond	mass_bond
				//reg bond L.r_price L.m_* L.d_*_bond L.n_*_bond L.in_*_bond L.md_*_bond L.c_*_bond L.v_* L.a_* L.j_* 
				reg bond L.c_*_bond //2nd law
				reg bond L.m_* L.d_*_bond L.in_*_bond  //2nd law bits
				//reg bond m_* d_*_bond in_*_bond  //2nd law bits
				predict e_bond, xb
				replace e_bond 				= bond - e_bond		//Convert to error
				** Correlogram
				ac  e_bond, ylabels(-.4(.2).6) name(ac_bond, replace)
				//graph save ac_bond, replace
				pac e_bond, ylabels(-.4(.2).6) name(pac_bond, replace)
				//graph save pac_bond, replace
				graph combine ac_bond pac_bond, rows(2) cols(1)
				drop e_*
				** ARIMA
				//arima bond L.m_* L.d_*_bond L.in_*_bond, ar(1 15) ma(12)  //real bon
				arima bond L.m_* L.d_*_bond L.in_*_bond, ar(1) ma(4)
				estat aroots
				rename bond a_bond
				rename mass_bond m_bond
			
			} //end if
			di "Done with bonds NB."
				
			////////////
			** Stock
			////////////
			scalar stoc 			= 1
			if stoc == 1 {
											
				** Stock acceleration
				rename a_stock stock 
				//reg stock L.m_* L.d_*_stock L.n_*_stock L.in_*_stock L.md_*_stock L.c_*_stock L.r_* L.v_* L.a_* L.j_*
				reg stock L.c_*_stock //2nd law
				reg stock L.m_* L.d_*_stock L.in_*_stock  //2nd law bits
				predict e_stock, xb
				replace e_stock 				= stock - e_stock		//Convert to error
				** Correlogram
				ac  e_stock, ylabels(-.4(.2).6) name(ac_stock, replace)
				//graph save ac_stock, replace
				pac e_stock, ylabels(-.4(.2).6) name(pac_stock, replace)
				//graph save pac_stock, replace
				graph combine ac_stock pac_stock, rows(2) cols(1)
				drop e_*
				** ARIMA
				//arima stock L.m_* L.d_*_stock L.in_*_stock, ar(1 3) ma(4) //2nd law bits
				arima stock L.c_*_stock, ar(1) ma() 
				estat aroots
				rename stock a_stock
																		
			} //end if
			di "Done with stock NB."
			
			////////////
			** House
			////////////
			scalar hous 				= 1
			if hous == 1 {
									
				** House acceleration
				rename a_house house 
				rename m_house mass_house
				//reg house L.m_* L.d_*_house L.n_*_house L.in_*_house L.md_*_house L.c_*_house L.r_house L.v_* L.a_* L.j_*
				//reg house L.c_*_house //2nd law
				reg house L.m_* L.d_*_house L.in_*_house //2nd law bits
				predict e_house, xb
				replace e_house 				= house - e_house		//Convert to error
				** Correlogram
				ac  e_house, ylabels(-.4(.2).6) name(ac_house, replace)
				//graph save ac_bond, replace
				pac e_house, ylabels(-.4(.2).6) name(pac_house, replace)
				//graph save pac_bond, replace
				graph combine ac_house pac_house, rows(2) cols(1)
				drop e_*
				** ARIMA
				arima house L.m_* L.d_*_house L.in_*_house, ar(1 2 6) ma() 
				estat aroots
				rename house a_house
				rename mass_house m_house
							
			} //end if
			di "Done with house NB."
			
		} //end if
		di "Done with NB-annual."	
				
	} //end if 
	di "Done with archive."
	
end


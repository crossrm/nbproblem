***********************************************************
***********************************************************
**  OVB

** Goal: 	Find synthetic instrument

** Inputs:	User settings (see options below)			

** Outputs: 

** Written: 
**		robin m cross 1.26.26

** Updated: 

***********************************************************
***********************************************************
capture program 	drop 	OVB
program 			define 	OVB, rclass

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

	
	} //end if
	di "Done with load and prep."
	
	***********************************************************
	** Gen instrument (x0) orthogonal to unobserved (x11) (Ability), correlated with X (x12), and no direct effect on Y (x13)
	** Unobservable ability later x_11 (creates two endogenous variables x_12 & x_13 )
	***********************************************************
	scalar runit = 1
	if runit == 1 {

		clear all
		
		set seed 111
		
		set obs 100000
		
		** Gen iid stn errors - loop
		foreach num of numlist 0/13 {
			
				di "Starting num `num'."
			
			** Gen
			gen u_`num' 					= rnormal()
			order u_`num'
			
				sum *
				corr *
	
			** First standardize
			** Standardize
			sum u_`num'
			replace u_`num' 		= (u_`num' - r(mean)) / r(sd)
			
				sum u_`num'
	
			** Decorr and restandardize
			if `num' > 1 {
				
				** Reg loop
				local prior 				= `num' - 1
				foreach k of numlist 1/`prior' {
				
					** Reg
					reg u_`num' u_`k'
					** Decorr
					predict u_hat, xb
					replace u_`num'			= u_`num' - u_hat
					drop u_hat
					** Standardize
					sum u_`num'
					replace u_`num' 		= (u_`num' - r(mean)) / r(sd)
								
				} //end subloop
				di "Done with subloop `k'."
								
			} //end subloop
			di "Done with if `n' > 0."

				sum
				corr *
				
		} //end loop
		di "Done with error loop."
			
			sum *
			corr *
			
		** Gen vars
		gen x_1 							= u_1
		order x_1
		foreach num of numlist 2/13 {
			
			** Prior
			local prior 					= `num' - 1

			** Gen
			gen x_`num'						= u_`num'
			order x_`num'
				
			** Covariate loop
			foreach k of numlist 1/`prior' {
				
					di "    ++++++Starting `k'."
				
				** Coeff
				local a_`num'_`k'			= 0.2
				
				** Add
				qui replace x_`num' 		= `a_`num'_`k'' * x_`k' + x_`num'
								
			} //end loop
			di "Done with covariate loop `num'."
				
			** Add instrument x_0 to variable
			if `num' == 12 {
				
					di "     ==========Running instrument."
				
				//qui replace x_`num' 	= 0.2 * u_0 + x_`num' 
				
			} //end if
			di "Done wtih instrument check `num'."
				
		} //end loop
		di "Done with vars loop."
				
			reg x_*
			sum x_*
			corr x_* u_0

		** Instrument
		local instru = 1
		if `instru' == 1 {
			
			** Temporarily remove x_12 influence from x_13	
			replace x_13	= x_13 - 0.2 * x_12
					
			** Add instrument to x_12
			replace x_12 	= 0.2 * u_0 + x_12 
			
			** Add new x_12 back to x_13
			replace x_13	= x_13 + 0.2 * x_12
			
				
				** Reg check
				reg x_2-x_1
				reg x_3-x_1
				reg x_4-x_1
				reg x_5-x_1
				reg x_*
							
				** OVB check
				reg x_13-x_12 x_10-x_1			// x_11 is missing ability
				reg x_13-x_12
			
			** Check instrument
			reg x_12 u_0
			predict z_12, xb
			order z_*
			reg x_13 x_12 x_10-x_1
			reg x_13 z_12 x_10-x_1

			** 2SLS
			** Conditional
			reg x_13 x_12 x_10-x_1
			reg x_13 z_12 x_10-x_1
			ivregress 2sls x_13 x_10-x_1 (x_12 = u_0)
			** Unconditional
			reg x_13 x_12 
			reg x_13 z_12 
			ivregress 2sls x_13 (x_12 = u_0)
			
			** Verify F
			reg x_12 u_0
			
			** For Symbolic regression:
			keep x_13 x_12-x_1
			cd_nb_stage
			save symbol_data, replace
			export delimited sybol_data.csv, replace
			
			** Check reverse
			reg x_1 x_13 x_12-x_2 //0.3236 R-squared
		
		} //end if
		di "Done with instru."
		
		asdf_old
		
		** Gen pairwise errors and estimates
		foreach num of numlist 1/12 {
			
			** decor pairwise
			reg x_`num' x_13 
			predict hat_`num', xb
			order hat_`num'
			gen e_`num'				= x_`num' - hat_`num'
			order e_`num'
			
				corr x_13 x_`num' e_`num' hat_`num'
			
		} //end loop
		di "Done with residual loop."
		
		order e_*
		
			** Check - all same OVB
			reg x_13-x_12 x_10-x_1			// x_11 is missing ability
			reg x_13 x_12 e_10-e_1
			reg x_13 x_12 hat_10-hat_1
			
			corr x_13 e_10-e_1
		
		** Make instrument from hats (odd)
		reg x_12 hat_10-hat_1
*		reg x_12 e_11-e_2
		predict zh_12, xb
		order zh_*
		
		** Make instrument from errors
		reg x_12 e_10-e_1
		predict ze_12, xb
		order ze_*
		
		** Make instrument from variables
		reg x_12 x_10-x_1
		predict zx_12, xb
		order zx_*
		
		** Make instrument from residuals
		reg x_12 u_10-u_1
		predict zu_12, xb
		order zu_*
		
			** Try 3
			reg x_*
			reg x_12 x_10-x_1
			reg x_13-x_12 x_10-x_1			// x_11 is missing ability
			
			reg x_13 x_12
			reg x_13 zh_12
			reg x_13 ze_12
			reg x_13 zx_12
			reg x_13 zu_12
			** x
			reg x_13 zh_12 x_10-x_1				
			reg x_13 ze_12 x_10-x_1			
			reg x_13 zx_12 x_10-x_1			
			reg x_13 zu_12 x_10-x_1			
			** e
			reg x_13 ze_12 e_10-e_1				
			reg x_13 zh_12 e_10-e_1				
			reg x_13 zx_12 e_10-e_1				
			reg x_13 zu_12 e_10-e_1				
			** hat
			reg x_13 ze_12 hat_10-hat_1				
			reg x_13 zh_12 hat_10-hat_1				
			reg x_13 zx_12 hat_10-hat_1			
			reg x_13 zu_12 hat_10-hat_1			
			** 2SLS
			ivregress 2sls x_13 (x_12 = hat_10-hat_1)
			ivregress 2sls x_13 (x_12 = e_10-e_1)
			ivregress 2sls x_13 (x_12 = x_10-x_1)
			ivregress 2sls x_13 (x_12 = u_10-u_1)
			ivregress 2sls x_13 (x_12 = u_0)
			ivregress 2sls x_13 x_10-x_1 (x_12 = u_0)
			
			asdf
			
		** RLS - recover TE with instrument
			reg x_13 u_12-u_1
			reg x_13 u_12 u_10-u_1
			reg x_13 x_12 u_10-u_1

			cor x_13 e_12-e_1
			
	} //end if
	di "Done with unobservable 11 b."
	
	***********************************************************
	** Gen e orthogonal to x_13 and all non-x_12 covariates
	** Unobservable ability later x_11 (creates two endogenous variables x_12 & x_13 )
	***********************************************************
	scalar runit = 1111
	if runit == 1 {

		clear all
		
		set seed 111
		
		set obs 10000
		
		** Gen iid stn errors - loop
		foreach num of numlist 0/13 {
			
				di "Starting num `num'."
			
			** Gen
			gen u_`num' 					= rnormal()
			order u_`num'
			
				sum *
				corr *
	
			** First standardize
			** Standardize
			sum u_`num'
			replace u_`num' 		= (u_`num' - r(mean)) / r(sd)
			
				sum u_`num'
	
			** Decorr and restandardize
			if `num' > 1 {
				
				** Reg loop
				local prior 				= `num' - 1
				foreach k of numlist 1/`prior' {
				
					** Reg
					reg u_`num' u_`k'
					** Decorr
					predict u_hat, xb
					replace u_`num'			= u_`num' - u_hat
					drop u_hat
					** Standardize
					sum u_`num'
					replace u_`num' 		= (u_`num' - r(mean)) / r(sd)
								
				} //end subloop
				di "Done with subloop `k'."
								
			} //end subloop
			di "Done with if `n' > 0."

				sum
				corr *
				
		} //end loop
		di "Done with error loop."
			
			sum *
			corr *
			
		** Gen vars
		gen x_1 							= u_1
		order x_1
		foreach num of numlist 2/13 {
			
			** Prior
			local prior 					= `num' - 1

			** Gen
			gen x_`num'						= u_`num'
			order x_`num'
				
			** Covariate loop
			foreach k of numlist 1/`prior' {
				
					di "    ++++++Starting `k'."
				
				** Coeff
				local a_`num'_`k'			= 0.2
				
				** Add
				qui replace x_`num' 		= `a_`num'_`k'' * x_`k' + x_`num'
								
			} //end loop
			di "Done with covariate loop `num'."
				
			** Add instrument x_0 to variable
			if `num' == 12 {
				
					di "     ==========Running instrument."
				
				//qui replace x_`num' 	= 0.2 * u_0 + x_`num' 
				
			} //end if
			di "Done wtih instrument check `num'."
				
		} //end loop
		di "Done with vars loop."
				
		** Add instrument to x_12
		replace x_12 	= 0.2 * u_0 + x_12 
				
				
			sum x_*	
			corr x_*
				
			** Reg check
			reg x_2-x_1
			reg x_3-x_1
			reg x_4-x_1
			reg x_5-x_1
			reg x_*
						
			** OVB check
			reg x_13-x_12 x_10-x_1			// x_11 is missing ability
			reg x_13-x_12
			
		** Gen pairwise errors and estimates
		foreach num of numlist 1/12 {
			
			** decor pairwise
			reg x_`num' x_13 
			predict hat_`num', xb
			order hat_`num'
			gen e_`num'				= x_`num' - hat_`num'
			order e_`num'
			
				corr x_13 x_`num' e_`num' hat_`num'
			
		} //end loop
		di "Done with residual loop."
		
		order e_*
		
			** Check - all same OVB
			reg x_13-x_12 x_10-x_1			// x_11 is missing ability
			reg x_13 x_12 e_10-e_1
			reg x_13 x_12 hat_10-hat_1
			
			corr x_13 e_10-e_1
		
		** Make instrument from hats (odd)
		reg x_12 hat_10-hat_1
*		reg x_12 e_11-e_2
		predict zh_12, xb
		order zh_*
		
		** Make instrument from errors
		reg x_12 e_10-e_1
		predict ze_12, xb
		order ze_*
		
		** Make instrument from variables
		reg x_12 x_10-x_1
		predict zx_12, xb
		order zx_*
		
		** Make instrument from residuals
		reg x_12 u_10-u_1
		predict zu_12, xb
		order zu_*
		
			** Try 3
			reg x_*
			reg x_12 x_10-x_1
			reg x_13-x_12 x_10-x_1			// x_11 is missing ability
			
			reg x_13 x_12
			reg x_13 zh_12
			reg x_13 ze_12
			reg x_13 zx_12
			reg x_13 zu_12
			** x
			reg x_13 zh_12 x_10-x_1				
			reg x_13 ze_12 x_10-x_1			
			reg x_13 zx_12 x_10-x_1			
			reg x_13 zu_12 x_10-x_1			
			** e
			reg x_13 ze_12 e_10-e_1				
			reg x_13 zh_12 e_10-e_1				
			reg x_13 zx_12 e_10-e_1				
			reg x_13 zu_12 e_10-e_1				
			** hat
			reg x_13 ze_12 hat_10-hat_1				
			reg x_13 zh_12 hat_10-hat_1				
			reg x_13 zx_12 hat_10-hat_1			
			reg x_13 zu_12 hat_10-hat_1			
			** 2SLS
			ivregress 2sls x_13 (x_12 = hat_10-hat_1)
			ivregress 2sls x_13 (x_12 = e_10-e_1)
			ivregress 2sls x_13 (x_12 = x_10-x_1)
			ivregress 2sls x_13 (x_12 = u_10-u_1)
			ivregress 2sls x_13 (x_12 = u_0)
			ivregress 2sls x_13 x_10-x_1 (x_12 = u_0)
			
			asdf
			
		** RLS - recover TE with instrument
			reg x_13 u_12-u_1
			reg x_13 u_12 u_10-u_1
			reg x_13 x_12 u_10-u_1

			cor x_13 e_12-e_1
			
	} //end if
	di "Done with unobservable 11 b."
	
	***********************************************************
	** Unobservable ability later x_11 (creates two endogenous variables x_11 & x_13 )
	***********************************************************
	scalar runit = 1111
	if runit == 1 {

		clear all
		
		set seed 11
		
		set obs 100
		
		** Gen iid stn errors - loop
		foreach num of numlist 1/13 {
			
				di "Starting num `num'."
			
			** Gen
			gen u_`num' 					= rnormal()
			order u_`num'
			
				sum *
				corr *
	
			** First standardize
			** Standardize
			sum u_`num'
			replace u_`num' 		= (u_`num' - r(mean)) / r(sd)
			
				sum u_`num'
	
			** Decorr and restandardize
			if `num' > 1 {
				
				** Reg loop
				local prior 				= `num' - 1
				foreach k of numlist 1/`prior' {
				
					** Reg
					reg u_`num' u_`k'
					** Decorr
					predict u_hat, xb
					replace u_`num'			= u_`num' - u_hat
					drop u_hat
					** Standardize
					sum u_`num'
					replace u_`num' 		= (u_`num' - r(mean)) / r(sd)
								
				} //end subloop
				di "Done with subloop `k'."
								
				
			} //end subloop
			di "Done with if `n' > 0."

				sum
				corr *
				
		} //end loop
		di "Done with error loop."
			
			sum *
			corr *
			
		** Gen vars
		gen x_1 					= u_1
		order x_1
		foreach num of numlist 2/13 {
			
			** Prior
			local prior 			= `num' - 1

			** Gen
			gen x_`num'				= u_`num'
			order x_`num'
				
			** Covariate loop
			foreach k of numlist 1/`prior' {
				
					di "    ++++++Starting `k'."
				
				** Coeff
				local a_`num'_`k'			= 0.2
				
				** Add
				replace x_`num' = `a_`num'_`k'' * x_`k' + x_`num'
				
			} //end loop
			di "Done with covariate loop `num'."
							
		} //end loop
		di "Done with vars loop."
				
			sum x_*	
			corr x_*
				
			** Reg check
			reg x_2-x_1
			reg x_3-x_1
			reg x_4-x_1
			reg x_5-x_1
			reg x_*
						
			** OVB check
			reg x_13-x_12 x_10-x_1			// x_11 is missing ability
												
		** Gen pairwise errors and estimates
		foreach num of numlist 1/12 {
			
			** decor pairwise
			reg x_`num' x_13 
			predict hat_`num', xb
			order hat_`num'
			gen e_`num'				= x_`num' - hat_`num'
			order e_`num'
			
				corr x_13 x_`num' e_`num' hat_`num'
			
		} //end loop
		di "Done with residual loop."
		
		order e_*
		
			** Check - all same OVB
			reg x_13-x_12 x_10-x_1			// x_11 is missing ability
			reg x_13 x_12 e_10-e_1
			reg x_13 x_12 hat_10-hat_1
			
			corr x_13 e_10-e_1
		
		** Make instrument from hats (odd)
		reg x_12 hat_10-hat_1
*		reg x_12 e_11-e_2
		predict zh_12, xb
		order zh_*
		
		** Make instrument from errors
		reg x_12 e_10-e_1
		predict ze_12, xb
		order ze_*
		
		** Make instrument from variables
		reg x_12 x_10-x_1
		predict zx_12, xb
		order zx_*
		
		** Make instrument from residuals
		reg x_12 u_10-u_1
		predict zu_12, xb
		order zu_*
		
			** Try 3
			reg x_*
			reg x_13-x_12 x_10-x_1			// x_11 is missing ability
			reg x_13 x_12
			reg x_13 zh_12
			reg x_13 ze_12
			reg x_13 zx_12
			reg x_13 zu_12
			** x
			reg x_13 zh_12 x_10-x_1				
			reg x_13 ze_12 x_10-x_1			
			reg x_13 zx_12 x_10-x_1			
			reg x_13 zu_12 x_10-x_1			
			** e
			reg x_13 ze_12 e_10-e_1				
			reg x_13 zh_12 e_10-e_1				
			reg x_13 zx_12 e_10-e_1				
			reg x_13 zu_12 e_10-e_1				
			** hat
			reg x_13 ze_12 hat_10-hat_1				
			reg x_13 zh_12 hat_10-hat_1				
			reg x_13 zx_12 hat_10-hat_1			
			reg x_13 zu_12 hat_10-hat_1			
			** 2SLS
			ivregress 2sls x_13 (x_12 = hat_10-hat_1)
			ivregress 2sls x_13 (x_12 = e_10-e_1)
			ivregress 2sls x_13 (x_12 = x_10-x_1)
			ivregress 2sls x_13 (x_12 = u_10-u_1)
			
		** RLS - recover TE with instrument
			reg x_13 u_12-u_1
			reg x_13 u_12 u_10-u_1
			reg x_13 x_12 u_10-u_1

			cor x_13 e_12-e_1
			
	} //end if
	di "Done with unobservable 11."
	
	***********************************************************
	** Unobservable ability earliest x_1
	***********************************************************
	scalar runit = 1111
	if runit == 1 {

		clear all
		
		set seed 11
		
		set obs 100
		
		** Gen iid stn errors - loop
		foreach num of numlist 1/13 {
			
				di "Starting num `num'."
			
			** Gen
			gen u_`num' 					= rnormal()
			
				sum *
				corr *
	
			** First standardize
			** Standardize
			sum u_`num'
			replace u_`num' 		= (u_`num' - r(mean)) / r(sd)
			
				sum u_`num'
	
			** Decorr and restandardize
			if `num' > 1 {
				
				** Reg loop
				local prior 				= `num' - 1
				foreach k of numlist 1/`prior' {
				
					** Reg
					reg u_`num' u_`k'
					** Decorr
					predict u_hat, xb
					replace u_`num'			= u_`num' - u_hat
					drop u_hat
					** Standardize
					sum u_`num'
					replace u_`num' 		= (u_`num' - r(mean)) / r(sd)
								
				} //end subloop
				di "Done with subloop `k'."
								
				
			} //end subloop
			di "Done with if `n' > 0."

				sum
				corr *
				
		} //end loop
		di "Done with error loop."
			
			sum *
			corr *
			
		** Gen vars
		gen x_1 					= u_1
		order x_1
		foreach num of numlist 2/13 {
			
			** Prior
			local prior 			= `num' - 1

			** Gen
			gen x_`num'				= u_`num'
			order x_`num'
				
			** Covariate loop
			foreach k of numlist 1/`prior' {
				
					di "    ++++++Starting `k'."
				
				** Coeff
				local a_`num'_`k'			= 0.2
				
				** Add
				replace x_`num' = `a_`num'_`k'' * x_`k' + x_`num'
				
			} //end loop
			di "Done with covariate loop `num'."
							
		} //end loop
		di "Done with vars loop."
				
		** Reg check
			reg x_2-x_1
			reg x_3-x_1
			reg x_4-x_1
			reg x_5-x_1
			reg x_*
						
			** OVB check
			reg x_13-x_2			// x_1 is missing ability
									
		** Try - x_1 is missing ability
		foreach num of numlist 2/12 {
			
			** decor pairwise
			reg x_13 x_`num'
			predict hat_`num', xb
			order hat_`num'
			gen e_`num'				= x_`num' - hat_`num'
			order e_`num'
			
		} //end loop
		di "Done with residual loop."
		
		order e_*
		
			** Check
			reg x_13-x_2
			reg x_13 x_12 e_11-e_2
			reg x_13 x_12 hat_11-hat_2
		
		** Make instrument from hats (odd)
		reg x_12 hat_11-hat_2
*		reg x_12 e_11-e_2
		predict zh_12, xb
		order zh_*
		
		** Make instrument from errors
		reg x_12 e_11-e_2
		predict ze_12, xb
		order ze_*
		
			** Try 3
			** x
			reg x_13 zh_12 x_11-x_2				
			reg x_13 ze_12 x_11-x_2				
			** e
			reg x_13 ze_12 e_11-e_2				
			reg x_13 zh_12 e_11-e_2				
			** hat
			reg x_13 ze_12 hat_11-hat_2				
			reg x_13 zh_12 hat_11-hat_2				
		
		** Make all error instruments
		foreach num of numlist 3/13 {
			
			** Prior
			local prior 			= `num' - 1
			
			** decor pairwise
			reg x_`num' x_`prior'-x_2
			predict z_`num', xb
			order z_`num'
			
		} //end loop
		di "Done with instrument loop."
		
			** Try 4
			reg x_13 z_12-z_3 
		
	} //end if
	di "Done with unobservable 1."

end


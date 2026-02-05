*********************************************************************************
** Note:  To follow linear regression
** Call fit_nb depvarName incl -- incl==1 in-sample, 0 out-of-sample
** R^2 formula: 1 - (SS_residual / SS_total)

*********************************************************************************
capture program 	drop 			fit_nb
program 			define 			fit_nb, rclass

	display "Now running Fit NB."

	local s		= "`1'"
	
	** Locals
	display "Fitting variable: `s', in or out (1 or 0) of sample: `incl'."

	****************************************************************
	** Predict - make sure you have the correct estimators active
	****************************************************************

	** Estimate Rsq
	foreach incl of numlist 1 0  {
			
			if (`incl'==1) di "Beginning in-sample - in == `incl':"
			else di "Beginning out-of-sample - in == `incl':"
		
		** SS method
		quietly predict yhat, xb		
		quietly gen ehat		=	(`s' - yhat) 
		quietly gen ESS			=	ehat^2
		quietly summarize ESS 							if (incl==`incl' & yhat~=.)
		scalar ess				=	r(mean)
		quietly summarize `s' 							if (incl==`incl' & yhat~=.)
		scalar smean			=	r(mean)
		quietly gen TSS			=	(`s' - smean)^2
		quietly summarize TSS 							if (incl==`incl' & yhat~=.)
		scalar tss				=	r(mean)
		scalar r2				=	1- (ess / tss)
			di ""
		///scalar list ess tss r2
		
		** Corr method
		quietly corr `s' yhat if (incl==`incl' & yhat~=.)
		scalar R2				= r(rho)^2
			di "        Corr method:" 
			scalar list R2
			di ""
		
		** Store stats for ratio -- r2 for SS method, R2 for corr method
		scalar r2_`incl'		= R2	//r2  
		
			//sum ehat ESS TSS yhat `s' year if incl==`incl'
		drop ehat ESS TSS yhat
				
	} //end loop
	di ""
	
	** Calc ratio
	scalar loss				= (r2_1 - r2_0) / r2_1
		di "Resulting overfitting loss percentage: "
		di ""
	scalar list r2_1 r2_0 loss
	
	** Return values (rclass program)
	return scalar r2_0 		= r2_0
	return scalar r2_1 		= r2_1
	
	
end

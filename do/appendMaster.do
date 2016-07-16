
	** Abro la œltima actualizaci—n de la base madre
	clear 
	capture noisily use "${dtaPath}/basePrincipal.dta", clear

	// pego el œltimo d’a actualizada
	append using "${dtaPath}/tempProcesada.dta" 

	** SEGUNDO: Verifico que la base actualizada sea completamente nueva 
	** y la guardo como basemadrerutine, ssi es completamente nueva:
	*******************************************************************************
	bysort *: gen duplicados=_n
	keep if duplicados==1
	drop duplicados

	if $version > 12 {
		saveold "${dtaPath}/basePrincipal.dta", replace
	}
	else {
		save "${dtaPath}/basePrincipal.dta", replace
	}

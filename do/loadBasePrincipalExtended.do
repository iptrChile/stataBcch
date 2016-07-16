set more off

* Cargamos base
	use "${dtaPath}/diccProductos.dta", replace

* Cargamos diccionario
	capture drop varObsDuplicadas
	bysort ${varsKey}: gen varObsDuplicadas=_n
	keep if varObsDuplicadas==1
	drop varObsDuplicadas

* Merge con diccionario
	merge 1:m ${varsKey} using "${dtaPath}/basePrincipal.dta"
	tab subcat fechaScrap

* Collapse a nivel de categoria
	*preserve
		*collapse (count) precio, by(fechaScrap)
	*restore

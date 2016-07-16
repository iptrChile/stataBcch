set more off

// Archivo hace encoding de cada archivo csv descargado
// para agregarlo a sistema generarl
***************************************************
local lclVarsImport ${varsImport}
local lclVarsUtf ${varsUtf}
local lclVarsToEncode ${varsToEncode}
local lclVarsPrice ${varsPrice}
local lclVarsDicc ${varsDicc}
local lclVarsDrop ${varsDrop}
local lclVarsKey ${varsKey}
local lclVarsDropIfEmpty ${varsDropIfEmpty}
local lclReshapeLongNeed ${reshapeLongNeed}
local lclReshapeLongByproduct ${reshapeLongByproduct}
local lclReshapeLongRename ${reshapeLongRename}
local lclShortFrmt ${shortFrmt}

	* Limpieza de caracteres mal cargados en UTF-8
	foreach var of varlist `lclVarsUtf' {
		*replace `var' = subinstr(`var'," ","_",.)
		replace `var' = subinstr(`var',"(","",.)
		replace `var' = subinstr(`var',")","",.)
		replace `var' = subinstr(`var',"̩","e",.)
		replace `var' = subinstr(`var',"î","e",.)
		replace `var' = subinstr(`var',"É","e",.)
		replace `var' = subinstr(`var',"è","e",.)
		replace `var' = subinstr(`var',"ê","e",.)
		replace `var' = subinstr(`var',"�?","i",.)
		replace `var' = subinstr(`var',"Ã­","i",.)
		replace `var' = subinstr(`var',"Í","i",.)
		replace `var' = subinstr(`var',"ï","i",.)
		replace `var' = subinstr(`var',"Ãº","o",.)
		replace `var' = subinstr(`var',"Ó","o",.)
		replace `var' = subinstr(`var',"Ãº","u",.)
		replace `var' = subinstr(`var',"ü","u",.)
		replace `var' = subinstr(`var',"ú","u",.)
		replace `var' = subinstr(`var',"ù","u",.)
		replace `var' = subinstr(`var',"ú","u",.)
		replace `var' = subinstr(`var',"Ã±","n",.)
		replace `var' = subinstr(`var',"��","a",.)
		replace `var' = subinstr(`var',"Ã¡","a",.)
		replace `var' = subinstr(`var',"Ã³","o",.)
		replace `var' = subinstr(`var',"Ô","o",.)
		replace `var' = subinstr(`var',"Ó","o",.)
		replace `var' = subinstr(`var',"á","a",.)
		replace `var' = subinstr(`var',"Á","a",.)
		replace `var' = subinstr(`var',"ó","o",.)
		replace `var' = subinstr(`var',"ô","o",.)
		replace `var' = subinstr(`var',"í","i",.)
		replace `var' = subinstr(`var',"Ã©","e",.)
		replace `var' = subinstr(`var',"é","e",.)
		replace `var' = subinstr(`var',"ñ","n",.)
		}

	* Encoding de variables con archivos existentes 
	* en carpeta /lbl
	foreach var of varlist `lclVarsToEncode'  {
		capture do "${lblPath}/`var'.do"
		rename `var' varToEncode
		noisily capture encode varToEncode, gen(`var') label(`var')
		if _rc == 107 { * Variable es num�rica, lo que significa que no 
						* hay que generar labels nuevos
			label values varToEncode `var' 
			rename varToEncode `var'
		}
		capture label save `var' using "${lblPath}/`var'", replace
		capture drop varToEncode
		*label list
		}

	* Reformateo
	foreach x of varlist `lclShortFrmt' {
		noisily capture format %50.0g `x'
		if _rc == 120 { * Variable es string
			format %50s `x'
		}
	}

	* Variables a n�meros reales
	foreach x of varlist `lclVarsPrice' {
		capture replace `x'= subinstr(`x',"${miles}","",.)
		capture replace `x'= subinstr(`x',"${decimal}",".",.)
		capture replace `x'= subinstr(`x',"$","",.)
		capture drop `x'1
		rename `x' `x'1 
		gen `x'=real(`x'1)
		drop `x'1
		*drop if `x'1==.
		}
	
	
	
	* Limpieza de duplicados
	/* Nota que esta manera de eliminar duplicados
	asume que la informaci�n de precios efectivamente
	est� duplicada, y que no hay mayor informaci�n en
	los datos que estamos eliminando. Si hay dos lecturas
	con precios diferentes del mismo producto esta
	manera de eliminar duplicados NO incorporar� la 
	informaci�n que est� en las observaciones, la
	que definitivamente se perder� */	 
	capture drop varObsDuplicadas
	bysort `lclVarsKey': gen varObsDuplicadas=_n
	keep if varObsDuplicadas==1
	drop varObsDuplicadas
	
	* Necesidad de hacer reshape
	if "${reshapeLongNeed}" != "" {
		reshape long `lclReshapeLongNeed', i(`lclVarsKey') j(`lclReshapeLongByproduct') string
		rename `lclReshapeLongNeed' `lclReshapeLongRename'
		if "${reshapeLongBypEncode}" == "ok" {
		foreach var of varlist `lclReshapeLongByproduct'  {
			capture do "${lblPath}/`var'.do"
			rename `var' varToEncode
			encode varToEncode, gen(`var') label(`var')
			capture label save `var' using "${lblPath}/`var'", replace
			drop varToEncode
			*label list
			}
		}
	}

	* Eliminaci�n de variables vac�as
	if "`lclVarsDropIfEmpty'" != "" {
		foreach var of varlist `lclVarsDropIfEmpty'  {
			capture drop if `var' == .
			}
	}

	* Generaci�n de diccionario opcional
	if "`lclVarsDicc'" != "" {
	preserve
	
		* Variables de inter�s
		keep `lclVarsDicc'
		order `lclVarsDicc'
		sort `lclVarsDicc'
		
		* Limpieza de Duplicados
		capture drop varObsDuplicadas
		bysort *: gen varObsDuplicadas=[_n]
		keep if varObsDuplicadas==1
		drop varObsDuplicadas
	
		* Guardado temporal
		if $version != 12 {
			saveold "${dtaPath}/tempDicc.dta", replace
		}
		else {
			save "${dtaPath}/tempDicc.dta", replace
		}

		* Abro master
		clear
		capture use "${dtaPath}/diccProductos.dta", clear
		append using "${dtaPath}/tempDicc.dta"

		* Limpieza de Duplicados
		bysort *: gen duplicados=_n
		keep if duplicados==1
		drop duplicados
		
		* Guardado master
		if $version != 12 {
			saveold "${dtaPath}/diccProductos.dta", replace
		}
		else {
			save "${dtaPath}/diccProductos.dta", replace
		}
		
	restore
	}
	
	* Limpieza de Base
	if "`lclVarsDrop'" != "" {
		foreach x of varlist `lclVarsDrop' {
			capture drop `x'
		}
	}


	* Guardamos base procesada
	if $version != 12 {
		saveold "${dtaPath}/tempProcesada.dta", replace
		}
	else {
		saveold "${dtaPath}/tempProcesada.dta", replace
		}
	
				
	* Dato
	global encodeDbResult = "ok"


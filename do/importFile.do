clear all

// Programa para importar como texto
***************************************************
do "${doPath}/pgrChewFile.do"

// Importar datos 
****************************************************

* Identificamos tama–o del archivo
quietly checksum "${csvPath}/${fileName}"
local fileSize = r(filelen)

	if `fileSize' > 0 {
	
		if $version != 12 {
			capture noisily import delimited "${csvPath}/${fileName}", stringcols(_all)
		}
		else {
			*chewfile using "${csvPath}/${fileName}", clear
			capture noisily insheet ${varsImport} using "${csvPath}/${fileName}"
		}

			/* Error Handling de ac‡ para abajo !! */
			if _rc == 100 { /*varlist required */
				global importFileResult = "no"
				global processStatus = "Error 03. Listado de variables mal especificado (Stata no lee variables)"
			}
			else if _rc == 111 { /* variable not found */
 				global importFileResult = "no"
				global processStatus = "Error 04. Variable definida no se encontr—"
			}
			else if _rc == 102 { /*too few variables specified */
				global importFileResult = "no"
				global processStatus = "Error 05. Archivo tiene m‡s columnas que numero de variables especificadas."
			}
			else if _rc == 103 { /* too many variables specified */
				global importFileResult = "no"
				global processStatus = "Error 06. Archivo tiene menos columnas que numero de variables especificadas"
			}
			else if _rc == 602 { /* unexpected end of file */
				global importFileResult = "no"
				global processStatus = "Error 07. Archivo finaliza inesperadamente"
			}
			else if _rc == 0 { /* sin error */
				* No se hace nada, ya que esto s—lo es error handling
			}
			else {  /* error no especificado */
				global codErrorHandling _rc
				global importFileResult = "no"
				global processStatus = "Error 08. Error de importacion no previsto, codigo ${codErrorHandling}"
			}

		gen fechaScrap = date(substr("${fileName}",1,10),"YMD")
		format fechaScrap %td
		drop if [_n] == 1
		
		* Solo cuando hay datos bien importados guardamos, si no no.
		if [_N] > 0 {
		
			* Se guarda base temporal
			if $version > 12 {
				saveold "${dtaPath}/tempProcesada.dta", replace
			}
			else {
				save "${dtaPath}/tempProcesada.dta", replace
			}
			global importFileResult = "ok"
		
		}
		else {
			* Significa que [_N] = 0
			global importFileResult = "no"
			global processStatus = "Error 02. Archivo a importar no incorpora observaciones. [_N] = 0"
		}
	
	}
	
	else {	
		* Significa que fileSize = 0
		global importFileResult = "no"
		global processStatus = "Error 01. Archivo a importar tiene tama–o = 0"	
	}

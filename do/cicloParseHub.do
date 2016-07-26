set more off

* Archivo realiza proceso de solicitudes a parseHub que son necesarias para 
* realizar el proceso recurrente y/ o chequeos y descargas pendientes en 
* los libros de cada caso. 

* El archivo sigue el siguiente orden logico: 
	* 1. Chequea estado de todos los items cargados en RunsToCheckStatus
	* 2. Cancela todos los runs que estŽn incluidos en RunsToKill
	* 3. Descarga todos los archivos que estŽn guardados en RunsToDownload
	
* Desde el punto de los temas a considerar en Do
////////////////////////////////////////////////////////////
* apicallsToProcess -> Cargamos info en ApiCallsLog
* RunsToCheckStatus -> cargamos info desde parseHub
* RunsToDownload -> descargamos los archivos que ya estŽn listos
* RunsToKill -> Cancelamos runs que est‡n con problemas

* Hacemos un loop de todos los RunsToCheckStatus. En el proceso de hacer esto 
* se va a cargar informaci—n nueva o no considerada previamente en los 3 libros
* Esto va a disparar automaticamente los apicallsToProcess, asi que no me 
* preocupo de ese ciclo. 

* En el processApiCall hay que identificar el o los trigger que llevan a 
* incluir un run en RunsToKill.  

* 0. corremos apicallsToProcess, por si acaso hay algo pendiente al inicio
////////////////////////////////////////////////////////////
do "${doPath}/processApiCall.do"

* 1. RunsToCheckStatus
////////////////////////////////////////////////////////////
* Actualizamos detalle de œltimos requests hechos a ParseHub, para asegurarnos
* de no realizar un check de status que no hayamos realizado antes de X minutos
* (si no est‡ definido, se hara con un default de 5 minutos)
* Detalle minutos minimos de pollng limit
	if (${pollingMinimum}+0) == 0 {
		global pollingLimit = 5
	}
	else {
		global pollingLimit = ${pollingMinimum}
	}
* Actualizacion de parametros de polling
	capture use "${dtaPath}/ApiCallsLog.dta", replace
	if _rc == 0 {
		capture drop minutes_elapsed act_status
		gen minutes_elapsed = minutes(Clock("$S_DATE $S_TIME","DMYhms#")-stata_timelog)	
		egen act_status = max(status == "complete" | status == "cancelled"), by(run_token)
		replace act_status = 0 if act_status == .
		collapse (min) minutes_elapsed, by(run_token act_status)
		save "${dtaPath}/tempUpdatedLog.dta", replace
		}
* Cargamos archivo con detalle de apis a guardar
	clear
	capture use "${dtaPath}/RunsToCheckStatus.dta", replace
	if _rc == 0 {
		* Mezclamos con la info que acabamos de preparar
		merge 1:1 run_token using ${dtaPath}/tempUpdatedLog.dta
		keep if minutes_elapsed >= ${pollingLimit} & act_status != 1
		
		* Se inicia el ciclo
		local nobs = [_N]
		if `nobs' > 0 {
		forvalues casenum = 1/`nobs' {
			preserve
			global runToCheck = run_token[`casenum']
			* Realizamos solicitud
			parseHubRunUpdate, api("${apiKey}") prt("${runToCheck}")
			restore
			}
 		}	
	}

* 2. RunsToKill
////////////////////////////////////////////////////////////
* Cargamos archivo con detalle de apis a cancelar
capture use "${dtaPath}/RunsToKill.dta", replace
	if _rc == 0 {
		local nobs = [_N]
		if `nobs' > 0 {
			forvalues casenum = 1/`nobs' {
				global runToCancel = run_token[`casenum']
				* Realizamos solicitud
				parseHubRunCancel, api("${apiKey}") prt("${runToCancel}")
				}
			* Eliminamos de listado
			preserve
			capture use "${dtaPath}/RunsToKill.dta", replace
			drop if run_token == "${runToCancel}"
			save "${dtaPath}/RunsToKill.dta", replace
			restore
			}
 		}

* 3. RunsToDownload
////////////////////////////////////////////////////////////
* Cargamos archivo con detalle de apis a descargar
capture use "${dtaPath}/RunsToDownload.dta", replace
	if _rc == 0 {
		* Eliminados duplicados del proceso
		capture drop varObsDuplicadas
		bysort *: gen varObsDuplicadas=_n
		keep if varObsDuplicadas==1
		drop varObsDuplicadas
		
		* Eliminamos archivos ya descargados
		capture merge 1:1 run_token using ${dtaPath}/RunsDownloaded.dta
		capture drop if _merge >= 2
	
		* Iniciamos ciclo de descargas si hay > 0 observaciones
		local nobs = [_N]
		if `nobs' > 0 {
		forvalues casenum = 1/`nobs' {
			global runToDownload = run_token[`casenum']
			global frmtToDownload = format[`casenum']
			* Realizamos solicitud
			parseHubRunDownload, api("${apiKey}") prt("${runToDownload}") f("${frmtToDownload}") fol("${csvPath}") file("${runToDownload}")
			}
 		}
	}

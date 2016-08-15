set more off

* Codigo para abrir cada apiCall tmp (ya identificados en el archivo 
* {$dtaPath}/apicallToProcess.dta, y enviar los contenidos de esos 
* archivos a las bases que corresponda. Es necesario abrir la jerarquía
* de operaciones a chequear para cada caso. 

* Desde el punto de vista de las API de parseHub
////////////////////////////////////////////////////////////
* Runs. 
* Agregar run inicializados a chequeos de base de datos (identificar status
* cada 5 minutos) para descargar. Si están listos para ser descargados, 
* hacerlo e ingresar solicitud de proceso a dta que corresponde. 

* Desde el punto de vista de las DTA en nuestro sistema
////////////////////////////////////////////////////////////
* ApiCalls (Filelist, FilelistToProcess, ProcFilelist). 
* Base de todas las apiCalls realizadas desde Stata, y las que ya se enviaron 
* a procesamiento y las que están listas para ser procesadas. 

* RunsToCheckStatus
* Todos los RUN que es necesario hacer un status check para identificar si
* los descargamos y/o realizamos otro proceso. 

* RunsToDownload
* Todos los RUNs listos para ser descargados y que todavia no se ha realizado 
* un proceso de descarga correcto.  

* ApiCallsLog
* Detalle de cada solicitud enviada a la Api de parseHub, basada más que nada
* en la respuesta de este server. Ojo con que en un caso (el de descargas) la
* respuesta del servidor no es un tmp con data sino que el archivo que queremos
* descargar. 

* FailedRunsToReview
* Detalle de Runs que dieron errores, y ojalá con la explicación del tipo
* de error. Dependiendo de esta base es posible que resolicitemos, rearmemos
* la estructura del parseHub, solicitemos una subpágina?, etc??

* RunsToKill
* Runs que hay que detener o cancelar, porque están consumiendo muchos 
* recursos en el server y/o porque se han demorado mucho. 

* Desde el punto de vista de los procesos a correr
////////////////////////////////////////////////////////////
* 01. API Call iniciando run. 
* // Se arma el webhook necesario. 
* // Se descarga tmp con respuesta del server, agregando apiCallType:Run.
* // Se integra respuesta del server a DTA de ApiCallsLog.
* // Se agrega data a RunToCheckStatus. 

* 02. Polling del server para identificar si han terminado el procesamiento. 
* Si han pasado más de x minutos (5?, necesariamente más de 3 por políticas
* del servidor), se puede chequear el status del run. 
* // Se arma el webhook necesario. 
* // Se descarga tmp con respuesta del sever, agregando apiCallType:StatusCheck.
* // Se integra respuesta del server a DTA de ApiCallsLog.
* // Si el estado pasó a finalizado exitosamente, se elimina de RunsToCheckStatus
* y se agrega a RunsToDownload. 
* // Si el estado pasó a finalizado con errores, se agrega a FailedRunsToReview
* y se elimina de RunsToCheckStatus
* // Si la solicitud lleva procesandose más de XX horas, agregar a RunsToKill. y 
* se elimina de RunsToCheckStatus

* 03. Downloading de datos. 
* Api descarga el set de datos que corresponda. 
* // Se arma el webhook necesario. 
* // Se descarga respuesta del sever y se envia a carpeta destino, ojo que en
* este caso no hay tmp.
* // Se agrega log de descarga de datos a ApiCallsLog
* // Se elimina de RunsToDownload
* // Se realiza chequeo de integridad de datos. Se puede ver algo con el MD5, 
* pero especialmente vería que no sea un archivo con tamaño 0, y que no haya
* problemas con la descarga del csv. 
* // Si no se pudo descargar bien vía csv, redescargamos, pero con formato json
* // Si es que nuevamente hay un problema de integridad de datos hay que 
* identificar en FailedRunsToReview

* 04. Killing procesos
* Api cancela un proceso que actualmente se está procesando. 
* // Se arma el webhook necesario. 
* // Se descarga tmp con respuesta del sever, agregando apiCallType:StatusCheck.
* // Se integra respuesta del server a DTA de ApiCallsLog.
* // Si el estado pasó a finalizado exitosamente, se elimina de RunsToKill. 

* 05. Importación a DTA de cada sitio y procesamiento.
* Esto se ve a nivel del ciclo y proceso individual de cada sitio. 

* Identificamos y actualizamos lo que haya que procesar
identifyToProcess, path(${apiCallPath}) ext(tmp) db(apicall) 

* Cargamos archivo con detalle de apis a guardar
capture use "${dtaPath}/apicallToProcess.dta", replace
if _rc == 0 {

* Chequeamos si existen archivos a procesar
if [_N] > 0 {

	* Cargamos numero de archivos a local macro
	local nobs = [_N]

	* Loop para cada archivo a cargar
	forvalues fnum = 1/`nobs' {

		* Codigo para testear sin hacer el loop completo. Eliminar al final del test
		*capture use "${dtaPath}/apicallToProcess.dta", replace
		*local fnum 1

		* Cargamos nombre de archivo a procesar
		global fileName = files[`fnum']
		di "Archivo de log a cargar a base: ${fileName}"

		* Guardamos estado de la base
		preserve
		
		* Limpiamos base
		clear
		
		* Detallamos variables a cargar
		quietly local varToStore = "project_token run_token status data_ready pages start_time end_time start_url start_value start_template md5sum owner_email options_json custom_proxies"

		* Creamos variables
		foreach var in `varToStore' {
			gen str240 `var'=""
			format %25s `var'
		}
		
		* Cargamos data de la api
		insheetjson `varToStore' using "${apiCallPath}/${fileName}", topscalars replace col(`varToStore')
		if "`r(status)'" != "" {
			global status `r(status)'
			global run_token `r(run_token)'
			global data_ready `r(data_ready)'
			di "datos ok, token: $run_token"
		}
		else {
			insheetjson run_token using "${apiCallPath}/${fileName}", topscalars replace col(run_token)
			global run_token `r(run_token)'
			global status "cancelled"
			replace status = "cancelled" in 1
			replace data_ready = "0" in 1
			di "run cancelado, token: $run_token"
		}
		di "Generando Timelog"
		gen stata_timelog = Clock(word(subinstr(substr("${fileName}",26,.),"."," ",.),1),"DMYhms#")
		format stata_timelog %tC
		
		* Integramos a base de datos general
		capture append using "${dtaPath}/ApiCallsLog.dta"
		if _rc == 601 {
			* No hay problema, significa que es el primer dato a guardar
			}
		save "${dtaPath}/ApiCallsLog.dta", replace
	
		* Si el run lleva corriendo más de 12 horas, se cancela.
			* Detalle cantidad de horas
			if (${maxHoras}+0) == 0 {
				global horas = 12
			}
			else {
				global horas = ${maxHoras}
			}
			* Generamos variable que identifique cantidad de horas desde el inicio
			capture drop hours_elapsed
			gen hours_elapsed = hours(Clock("$S_DATE $S_TIME","DMYhms#")-stata_timelog)	
			* Generamos variable que identifique si status es complete o cancelled
			capture drop act_status
			egen act_status = max(status == "complete" | status == "cancelled"), by(run_token)
			* Eliminamos lo que está terminado o cancelado
			drop if act_status == 1
			* Filtramos lo que nos interesa trabajar
			capture collapse (max) hours_elapsed, by(run_token)
			if _rc == 2000 {
				di "Archivo a procesar no tiene observaciones"
			}
			else if _rc == 0 {
				* Archivo a procesar no tieneproblemas
			}
			drop if hours_elapsed <= ${horas}
			* Cantidad de casos
			local nobs2 = [_N]			
			if `nobs2' > 0 {
				forvalues casenum = 1/`nobs2' {
					global runToKill = run_token[`casenum']
					* Agregamos a RunsToKill
					capture use "${dtaPath}/RunsToKill.dta", replace
					if _rc == 601 {
						clear
						gen str240 run_token = ""
						format %25s run_token
						}
					local nobs3 = [_N] +1
					set obs `nobs3'
					replace run_token = "${runToKill}" in `nobs3'
					save "${dtaPath}/RunsToKill.dta", replace
					}		
			 	}
		
		* Eliminamos dato de apicallToProcess.dta
		capture use "${dtaPath}/apicallToProcess.dta", replace
		drop if files == "${fileName}"
		save "${dtaPath}/apicallToProcess.dta", replace
		
		* Agregamos el dato a apicallProcFilelist.dta y guardamos
		capture use "${dtaPath}/apicallProcFilelist.dta", replace
		if _rc == 601 {
			clear
			gen str55 files = ""
			}
		local nobs2 = [_N] +1
		set obs `nobs2'
		replace files = "${fileName}" in `nobs2'
		save "${dtaPath}/apicallProcFilelist.dta", replace		

		* Si es un run recién inicialiizado, agregamos a RunToCheckStatus
		if "${status}" == "initialized" {
			capture use "${dtaPath}/RunsToCheckStatus.dta", replace
			if _rc == 601 {
				clear
				gen str240 run_token = ""
				format %25s run_token
				}
			local nobs2 = [_N] +1
			set obs `nobs2'
			replace run_token = "${run_token}" in `nobs2'
			save "${dtaPath}/RunsToCheckStatus.dta", replace
		 	}	

		* Si es un run finalizado y está con data ready para descarga, 
		* eliminamos de RunToCheckStatus y agregamos a RunsToDownload
		if "${status}" == "complete" & ${data_ready} == 1 {
			* Eliminamos de RunToCheckStatus
			capture use "${dtaPath}/RunsToCheckStatus.dta", replace
			if _rc == 0 {
				drop if run_token == "${run_token}"
				save "${dtaPath}/RunsToCheckStatus.dta", replace
				}
			
			* Agregamos a RunsToDownload
			capture use "${dtaPath}/RunsToDownload.dta", replace
			if _rc == 601 {
				clear
				gen str240 run_token = ""
				format %25s run_token
				gen str10 format = ""
				}
			local nobs2 = [_N] +1
			set obs `nobs2'
			replace run_token = "${run_token}" in `nobs2'
			replace format = "csv" in `nobs2'
			save "${dtaPath}/RunsToDownload.dta", replace
		 	}

		* Si es un run cancelado, eliminamos de RunToCheckStatus y RunsToDownload
		if "${status}" == "cancelled" {
			* Eliminamos de RunToCheckStatus
			capture use "${dtaPath}/RunsToCheckStatus.dta", replace
			if _rc == 0 {
				drop if run_token == "${run_token}"
				save "${dtaPath}/RunsToCheckStatus.dta", replace
				}
			
			* Eliminamos de RunsToDownload
			capture use "${dtaPath}/RunsToCheckStatus.dta", replace
			if _rc == 0 {
				drop if run_token == "${run_token}"
				save "${dtaPath}/RunsToCheckStatus.dta", replace
				}
		 	}
		
		* Restauramos estado de la base
		restore

	}

}

}

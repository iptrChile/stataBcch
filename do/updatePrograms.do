*! version 0.1 16 Julio 2016

* Programa realiza la accion que corresponde en parseHub
* Esto puede ser iniciar un run, cargar los detalles de un
* run a resultados r(), cancelar un run, o descargar el set de 
* datos y enviarlos a la carpeta correspondiente. 

* Eventualmente podd’amos incorporar que el do obtenga
* el listado de los œltimos 20 runs y llevarlos a la 
* carpeta que corresponda

* parseHubRunStart. Inicia un nuevo run en parseHub
////////////////////////////////////////////////////////////
capture program drop parseHubRunStart
program def parseHubRunStart, rclass
version 12.0
syntax [anything], APIkey(string) PRToken(string) [STUrl(string) STTemplate(string) STValue(string) EMail]

	* Definicion de local macros con informacion de run por correr
	local baseurl = "https://www.parsehub.com/api/v2/projects/`prtoken'/run "
	local adapikey = `"-X POST -d "api_key=`apikey'" "'
	if "`sturl'" != "" local adsturl = `"-d "start_url=`sturl'" "'
	if "`sttemplate'" != "" local adsttemplate = `"-d "start_template=`sttemplate'" "'
	if "`stvalue'" != "" local adstvalue = `"-d "start_value_override=`stvalue'" "'
	if "`email'" != "" local ademail = `"-d "send_email=1" "'

	* Establecimiento de url definitiva para contactar a parseHub
  	local curlCode = `"`baseurl'`adapikey'`adsturl'`adsttemplate'`adstvalue'`ademail'"'

	* Solicitud de parseHub + guardar log de respuesta en /apiCall
	ashellrc curl `curlCode'
		
end

* parseHubRunUpdate. Actualiza informacion de un run
////////////////////////////////////////////////////////////
capture program drop parseHubRunUpdate
program def parseHubRunUpdate, rclass
version 12.0
syntax [anything], APIkey(string) PRToken(string)

	* Definicion de local macros con informacion de run por correr
	*local baseurl = "-X GET https://www.parsehub.com/api/v2/runs/`prtoken'/run"
	*local adapikey = `"?api_key=`apikey'" "'

	* Establecimiento de url definitiva para contactar a parseHub
  	*local curlCode = `"`baseurl'`adapikey'"'

	* Solicitud de parseHub + guardar log de respuesta en /apiCall
	quietly ashellrc curl -X GET "https://www.parsehub.com/api/v2/runs/`prtoken'?api_key=`apikey'"

end

* parseHubRunCancel. Cancela un run en parseHub
////////////////////////////////////////////////////////////
capture program drop parseHubRunCancel
program def parseHubRunCancel, rclass
version 12.0
syntax [anything], APIkey(string) PRToken(string)

	* Definicion de local macros con informacion de run por correr
	local baseurl = "https://www.parsehub.com/api/v2/runs/`prtoken'/cancel "
	local adapikey = `"-X POST -d "api_key=`apikey'" "'

	* Establecimiento de url definitiva para contactar a parseHub
  	local curlCode = `"`baseurl'`adapikey'"'

	* Solicitud de parseHub + guardar log de respuesta en /apiCall
	ashellrc curl `curlCode'
		
end

* parseHubRunDownload. Descarga un run desde parseHub
////////////////////////////////////////////////////////////
capture program drop parseHubRunDownload
program def parseHubRunDownload, rclass
version 12.0
syntax [anything], APIkey(string) PRToken(string) Format(string) FOLder(string) FILEname(string)

		* Cargamos informaci—n de la fecha del run
		preserve
		quietly capture use "${dtaPath}/ApiCallsLog.dta", replace
		if _rc == 0 {
			quietly capture drop start_stata
			quietly gen start_stata = Clock(start_time, "YMD#hms")
			format %tC start_stata
			quietly drop if start_stata == .
			quietly collapse (min) start_stata, by(run_token)
			quietly keep if run_token == "`prtoken'"
			if [_N] == 1 {
				local timeStamp = string(year(dofc(start_stata[1]))) + "-" + string(month(dofc(start_stata[1])),"%02.0f") + "-" + string(day(dofc(start_stata[1])),"%02.0f") + " "
			}
		}
		restore

	* Solicitud de parseHub + guardar log de respuesta en /apiCall
	quietly !curl -o '`folder'/`timeStamp'`filename'.`format'' -X GET "https://www.parsehub.com/api/v2/runs/`prtoken'/data?api_key=`apikey'&format=`format'"

	* Chequeamos integridad del archivo
		if "`format'" == "csv" {
			quietly ashell zgrep 'Too much data' '`folder'/`timeStamp'`filename'.`format''
			local downdata = r(o1)
			if "`downdata'" == "Too much data. Use JSON instead." {
				quietly !rm -f  '`folder'/`timeStamp'`filename'.`format''
				parseHubRunDownload, api("${apiKey}") prt("${runToDownload}") f("json") fol("${csvPath}") file("${runToDownload}")
				}
			}
		else if "`format'" == "json" {
			* Formato in2csv via bash file
			quietly !${doPath}/json2csv.sh "${csvPath}" "`timeStamp'`filename'" "${varJsonTrad}" "${varMainJsonTrad}"
			quietly !rm -f  "${csvPath}" "`timeStamp'`filename'.json.gz"
			
			* Formato in2csv via Stata (no funciona por referencia bash)
			*!mv '`folder'/`timeStamp'`filename'.`format'' '`folder'/`timeStamp'`filename'.`format'.gz'
			*!in2csv '`folder'/`timeStamp'`filename'.`format'.gz' > '`folder'/`timeStamp'`filename'.csv' -k ${varMainJsonTrad}
			*!rm -f  '`folder'/`timeStamp'`filename'.`format''
			
			* Formato jsonv
			*!cat '`folder'/`timeStamp'`filename'.`format'' | jsonv ${varJsonTrad} ${varMainJsonTrad} > '`folder'/`timeStamp'`filename'.csv'
			}

		* Eliminamos de listado
		preserve
			quietly capture use "${dtaPath}/RunsToDownload.dta", replace
			quietly drop if run_token == "${runToDownload}"	 & format == "${frmtToDownload}"
			quietly save "${dtaPath}/RunsToDownload.dta", replace
		restore

		* Agregamos a RunsDownloaded
		preserve
			quietly capture use "${dtaPath}/RunsDownloaded.dta", replace
			if _rc == 601 {
				clear
				quietly gen str240 run_token = ""
				format %25s run_token
				}
			local nobs2 = [_N] +1
			quietly set obs `nobs2'
			quietly replace run_token = "`prtoken'" in `nobs2'
			dropDuplicates run_token
			quietly save "${dtaPath}/RunsDownloaded.dta", replace
		restore

end

* parseHubRunList. Descarga listado de runs desde parseHub
////////////////////////////////////////////////////////////
capture program drop parseHubRunList
program def parseHubRunList, rclass
version 12.0
syntax [anything], APIkey(string) PRToken(string) OFFset(integer) [id(integer 0)]

	* Mensaje
	di "[parseHubRunList] 		Generando URL para consulta..."

	* Definicion de local macros con informacion de run por correr
	local baseurl = "https://www.parsehub.com/api/v2/projects/`prtoken'"
	local adapikey = "?api_key=`apikey'&offset=`offset'"

	* Establecimiento de url definitiva para contactar a parseHub
  	local curlCode = `"`baseurl'`adapikey'"'

	* Mensaje
	di "[parseHubRunList] 		Realizando consulta..."

	* Solicitud de parseHub + guardar log de respuesta en /apiCall
	quietly ashrunlist curl -X GET "`curlCode'"

	* Trabajamos el ID si no se entreg—
	if "`id'" == "0" {
		preserve
			quietly capture use "${dtaPath}/RunList.dta", replace
			quietly capture collapse (max) id
			quietly capture local id = id[1] +1
			if _rc == 111 {
				local id = 1
			}
		restore
	}
	
	* Cargamos TempRunList para identificar cantidad de runs
	preserve
		quietly capture use "${dtaPath}/TempRunList.dta", replace
		local nobs = [_N]

		* Mensaje
		di "[parseHubRunList] 		Resultado entreg— `nobs' runs..."
	
		quietly gen id = `id' 
		quietly gen offset = `offset'
		quietly capture append using "${dtaPath}/RunList.dta"
		quietly save "${dtaPath}/RunList.dta", replace
		
		if "`offset'" == "0" & "`id'" != "1" {
			quietly keep if id == `id' - 1 & offset == 0
			quietly merge 1:1 run_token using ${dtaPath}/TempRunList.dta
			quietly keep if _merge == 3

				* Mensaje
				di "[parseHubRunList] 		De los cuales `=20-[_N]' son nuevos..."
			
			if [_N] == 20 {
				local ngo = 0
				}
		}
		else {
			local ngo = 1
		}
		
	restore
	
	* Si hay n = 20 sigo en el ciclo con offset de 20 adicionales
	if "`nobs'" == "20" & "`ngo'" == "1" {
		local noffset = `offset'+20	
		local roffset = `noffset'/20
		
		* Mensaje
		di "[parseHubRunList] 		Continua ciclo de descarga, parte `roffset'..."
		
		parseHubRunList, api(`apikey') prt(`prtoken') off(`noffset') id(`id')
	}
		
end

* parseHubFileCreation. Descarga listado de runs desde parseHub
////////////////////////////////////////////////////////////
capture program drop parseHubFileCreation
program def parseHubFileCreation, rclass
version 12.0
syntax [anything]

	* Mensaje
	di "[parseHubFileCreation] 	Chequeando integridad de estructura de archivos..."
	
	local fileList = "RunsToDownload RunsToCheckStatus RunsToKill"
	
	foreach file of local fileList {
			di "[parseHubFileCreation] 		Verificando `file'..."
			onFailCreateDTA, file("`file'")			
		}

	quietly clear
	
	* Mensaje
	di "[parseHubFileCreation] 	Integridad verificada"
	

end

* onFailCreateDTA. Crea DTA si no logra abrir el archivo
////////////////////////////////////////////////////////////
capture program drop onFailCreateDTA
program def onFailCreateDTA, rclass
version 12.0
syntax [anything], FILE(string)

	quietly capture use "${dtaPath}/`file'.dta", replace
		if _rc == 601 {
			quietly clear
			quietly gen str240 run_token = ""
			format %25s run_token
			quietly if "`file'" == "RunsToDownload" gen str10 format = "json"
			quietly drop if [_n] > 0
			quietly save "${dtaPath}/`file'.dta", replace 
			* Mensaje
			di "[onFailCreateDTA] 			`file' generado..."
			}

end

* encodeApiCallsLog. Actualiza Detalles de RunList
* en base a apiCalls ya realizadas
////////////////////////////////////////////////////////////
capture program drop encodeApiCallsLog
program def encodeApiCallsLog, rclass
version 12.0
syntax [anything] 

		* Cargamos archivo de apiCalls
		capture use "${dtaPath}/apiCallsLog.dta", replace
	
		* Definimos labels con prioridad, donde la mayor es la 
		* m‡s relevante de saber
		label define apistatus 1 `"running"', modify
		label define apistatus 2 `"complete"', modify
		label define apistatus 3 `"cancelled"', modify
		label define apistatus 4 `"error"', modify

		* Se codifica la variable status que es la que interesa
		encode status, generate(encStatus) label(apistatus)
		
		* Guardamos la info en archivo nuevo
		collapse (max) encStatus, by(run_token)
		label values encStatus "apistatus"
		quietly save "${dtaPath}/tempMostRecentApiCall.dta", replace 


end

* updateRunListDetails. Actualiza Detalles de RunList
* en base a apiCalls ya realizadas
////////////////////////////////////////////////////////////
capture program drop updateRunListDetails
program def updateRunListDetails, rclass
version 12.0
syntax [anything] 
	
	* Primero llevaremos la informaci—n m‡s reciente en el
	* historico de apiCalls a un archivo temporal
	
		* Mensaje
		di "[updateRunListDetails] 	Identificando status de runs previamente consultados..."
		encodeApiCallsLog

	* Segundo reducimos el hist—rico de runList para 
	* identificar los runs a consultar
	
		* Mensaje
		di "[updateRunListDetails] 	Cargando lista actualizada de runs..."
	
		* Cargamos archivo de runLists
		capture use "${dtaPath}/RunList.dta", replace
		quietly dropDuplicates run_token
		keep run_token

		* Mensaje
		di "[updateRunListDetails] 	Guardando lista combinada..."

		* Guardamos la info en archivo especial
		quietly save "${dtaPath}/tempRunList.dta", replace 

	* Tercero, mezclamos la informaci—n
		quietly merge 1:1 run_token using "${dtaPath}/tempMostRecentApiCall.dta"

	* Cuarto, guardamos status de runs actualizado
		quietly save "${dtaPath}/UpdatedRunStatus.dta", replace 

	* Cleanup
		quietly !rm -f "${dtaPath}/tempMostRecentApiCall.dta"
		quietly !rm -f "${dtaPath}/tempRunList.dta"

		* Mensaje
		di "[updateRunListDetails] 	... {it:listo!}"

end

* updateApiCallsLog. Actualiza informaci—n en el apiCallsLog
* en base a ApiCalls ya descargads
////////////////////////////////////////////////////////////
capture program drop updateApiCallsLog
program def updateApiCallsLog, rclass
version 12.0
syntax [anything]

	* Mensaje
	di "[updateApiCallsLog] 	Mapeando updates a agregar a la base de datos..."	

	* Identificamos y actualizamos lo que haya que procesar
	identifyToProcess, path(${apiCallPath}) ext(tmp) db(apicall) 

	* Cargamos archivo con detalle de apis a guardar
	quietly capture use "${dtaPath}/apicallToProcess.dta", replace
	
	* Chequeamos si existen archivos a procesar
	if _rc == 0 & [_N] > 0 {

		* Mensaje
		di "[updateApiCallsLog] 	... existen updates, procedo a cargarlos."	

		* Cargamos numero de archivos a local macro
		local nobs = [_N]

		* Loop para cada archivo a cargar
		forvalues fnum = 1/`nobs' {

		* Codigo para testear sin hacer el loop completo. Eliminar al final del test
		*capture use "${dtaPath}/apicallToProcess.dta", replace
		*local fnum 1

		* Cargamos nombre de archivo a procesar
		global fileName = files[`fnum']

		* Mensaje
		di "[updateApiCallsLog] 	Cargando log de ${fileName}..."	

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
		quietly insheetjson `varToStore' using "${apiCallPath}/${fileName}", topscalars replace col(`varToStore')
		if "`r(status)'" != "" {
			global status `r(status)'
			global run_token `r(run_token)'
			global data_ready `r(data_ready)'
			* Mensaje
			di "[updateApiCallsLog] 	   {it:... datos ok, token: $run_token}"	
		}
		else {
			quietly insheetjson run_token using "${apiCallPath}/${fileName}", topscalars replace col(run_token)
			global run_token `r(run_token)'
			global status "cancelled"
			quietly replace status = "cancelled" in 1
			quietly replace data_ready = "0" in 1
			* Mensaje
			di "[updateApiCallsLog] 	   {it:... run cancelado, token: $run_token}"	
		}
		* Mensaje
		di "[updateApiCallsLog] 	   {it:... generando timelog}"	
		quietly gen stata_timelog = Clock(word(subinstr(substr("${fileName}",26,.),"."," ",.),1),"DMYhms#")
		format stata_timelog %tC
		
		* Integramos a base de datos general
		quietly capture append using "${dtaPath}/ApiCallsLog.dta"
		if _rc == 601 {
			* No hay problema, significa que es el primer dato a guardar
			}
		quietly save "${dtaPath}/ApiCallsLog.dta", replace
		* Mensaje
		di "[updateApiCallsLog] 	   {it:... e incorporando a base de datos.}"	
			
		* Eliminamos dato de apicallToProcess.dta
		quietly capture use "${dtaPath}/apicallToProcess.dta", replace
		quietly drop if files == "${fileName}"
		quietly save "${dtaPath}/apicallToProcess.dta", replace
		
		* Agregamos el dato a apicallProcFilelist.dta y guardamos
		quietly capture use "${dtaPath}/apicallProcFilelist.dta", replace
		if _rc == 601 {
			clear
			quietly gen str55 files = ""
			}
		local nobs2 = [_N] +1
		quietly set obs `nobs2'
		quietly replace files = "${fileName}" in `nobs2'
		quietly save "${dtaPath}/apicallProcFilelist.dta", replace		

		restore

		}
		
	}

	* Mensaje
	di "[updateApiCallsLog] 	Ciclo de actualizaci—n finalizado."	


end

* updateRunsToDo. Actualiza informaci—n en los libros 
* particulares de informaci—n
////////////////////////////////////////////////////////////
capture program drop updateRunsToDo
program def updateRunsToDo, rclass
version 12.0
syntax [anything]

	* Mensaje
	di "[updateRunsToDo] 		Cargando archivo de estados actualizado..."	

	** Primero cargamos archivo UpdatedRunStatus.dta
	quietly capture use "${dtaPath}/UpdatedRunStatus.dta", replace
	
	* Guardamos foto del archivo
	quietly preserve

		* Mensaje
		di "[updateRunsToDo] 		Agregando runs a monitoreo..."	

		* Caso 1. encStatus = 1, running. Se agrega a RunsToCheckStatus
		quietly keep if encStatus == 1 | encStatus == .
		* Loop y agregamos archivos
		if [_N] > 0 {
			local nobs = [_N]
			forvalues j = 1/`nobs' {
				local rtk = run_token[`j']
				agregaMaestro, runtoken("`rtk'") file("CheckStatus")
			}
		}
		quietly restore
		quietly preserve

		* Mensaje
		di "[updateRunsToDo] 		Agregando runs a descarga..."	
		
		* Caso 2. encStatus = 2, complete. Se agrega a RunsToDownload
		quietly keep if encStatus == 2 
		quietly keep run_token
		dropDuplicates run_token
		quietly capture merge 1:1 run_token using "${dtaPath}/RunsDownloaded.dta"
		quietly capture keep if _merge == 1
		quietly keep run_token
		quietly capture merge 1:1 run_token using "${dtaPath}/RunsToDownload.dta"
		quietly capture keep if _merge == 1
		quietly keep run_token
		* Loop y agregamos archivos
		if [_N] > 0 {
			local nobs = [_N]
			forvalues j = 1/`nobs' {
				local rtk = run_token[`j']
				agregaMaestro, runtoken("`rtk'") file("Download")
				}
		}

	* Restauramos foto del archivo	
	quietly restore

	* Mensaje
	di "[updateRunsToDo] 		{it:... listo!}"	

end

* agregaMaestro. Actualiza informaci—n en los libros 
* particulares de informaci—n
////////////////////////////////////////////////////////////
capture program drop agregaMaestro
program def agregaMaestro, rclass
version 12.0
syntax [anything], runtoken(string) file(string)

	* Mensaje
	di "[agregaMaestro] 		Agregando token `runtoken' a RunsTo`file'"
	
	preserve
		quietly capture use "${dtaPath}/RunsTo`file'.dta", replace
		if _rc == 601 {
			clear
			quietly gen str240 run_token = ""
			format %25s run_token
			quietly if "`file'" == "Download" gen str10 format = "json"
			}
		quietly drop if run_token == "`runtoken'"
		local nobs = [_N] +1
		quietly set obs `nobs'
		quietly replace run_token = "`runtoken'" in `nobs'
		quietly if "`file'" == "Download" replace format = "json" in `nobs'
		quietly save "${dtaPath}/RunsTo`file'.dta", replace
	restore

end

* checkStatusRuns. Calls ParseHub para actualizar informacion 
* de runs en observacion
////////////////////////////////////////////////////////////
capture program drop checkStatusRuns
program def checkStatusRuns, rclass
version 12.0
syntax [anything]

	* Mensaje
	di "[checkStatusRuns] 		Iniciando chequeo de status pendientes..."
	
	* 1. RunsToCheckStatus
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

	* Mensaje
	di "[checkStatusRuns] 		Seteando tiempo minimo de espera entre consultas en $pollingLimit minutos... {it:ok}"
	
	* 2. Actualizacion de parametros de polling

	* Mensaje
	di "[checkStatusRuns] 		Procesando historial de consultas previas..."

	capture use "${dtaPath}/ApiCallsLog.dta", replace
	if _rc == 0 {
		quietly capture drop minutes_elapsed act_status
		quietly gen minutes_elapsed = minutes(Clock("$S_DATE $S_TIME","DMYhms#")-stata_timelog)	
		quietly egen act_status = max(status == "complete" | status == "cancelled"), by(run_token)
		quietly replace act_status = 0 if act_status == .
		quietly collapse (min) minutes_elapsed, by(run_token act_status)
		quietly save "${dtaPath}/tempUpdatedLog.dta", replace
		}

	* 3. Cargamos archivo con detalle de apis a guardar

	* Mensaje
	di "[checkStatusRuns] 		Iniciando ciclo de consultas nuevas..."

	clear
	quietly capture use "${dtaPath}/RunsToCheckStatus.dta", replace
	if _rc == 0 & [_N] > 0 {
		* Eliminados duplicados del proceso
		dropDuplicates run_token
		
		* Mezclamos con la info que acabamos de preparar
		quietly capture merge 1:1 run_token using ${dtaPath}/tempUpdatedLog.dta
		quietly capture keep if minutes_elapsed >= ${pollingLimit} & act_status != 1
		
		* Se inicia el ciclo
		local nobs = [_N]
		if `nobs' > 0 {
		forvalues casenum = 1/`nobs' {
			preserve
			local runToCheck = run_token[`casenum']
			* Mensaje
			di "[checkStatusRuns] 		   {it:consultando run: `runToCheck'...}"

			* Realizamos solicitud
			parseHubRunUpdate, api("${apiKey}") prt("`runToCheck'")
			restore
			}
 		}	
	}
	
	* Mensaje
	di "[checkStatusRuns] 		... ciclo de consultas finalizado."

end

* updateRunsToKill. Identifica runsToKill en base a info reciente
////////////////////////////////////////////////////////////
capture program drop updateRunsToKill
program def updateRunsToKill, rclass
version 12.0
syntax [anything]

	* Mensaje
	di "[updateRunsToKill] 		Iniciando chequeo de status..."

	* Codificamos y abrimos base de apiCalls
	encodeApiCallsLog
	quietly capture use "${dtaPath}/tempMostRecentApiCall.dta", replace

	* Identificamos runs que estŽn corriendo
	quietly keep if encStatus == 1
	quietly save "${dtaPath}/tempRunningRuns.dta", replace

	* Mensaje
	di "[updateRunsToKill] 		... chequeando tiempo en proceso y paginas vistas ..."

	* Generamos running time, pages parsed
	capture use "${dtaPath}/apiCallsLog.dta", replace
	quietly collapse (max) stata_timelog, by(run_token start_time)
	quietly gen stata_start =  Clock(start_time, "YMD#hms")-msofhours(3)
	format %tC stata_start
	quietly drop if stata_start == .
	quietly gen minutes_running = minutes(stata_timelog-stata_start)	
	quietly capture merge 1:m run_token start_time stata_timelog using ${dtaPath}/apiCallsLog.dta, keepusing(pages) keep(3)
	quietly gen npages = real(pages)
	quietly keep run_token minutes_running npages
	quietly save "${dtaPath}/tempRunningStats.dta", replace

	* Mensaje
	di "[updateRunsToKill] 		... identificando outliers ..."

	* Mezclamos info
	capture use "${dtaPath}/tempRunningRuns.dta", replace
	quietly capture merge 1:1 run_token using ${dtaPath}/tempRunningStats.dta, keep(1)
	quietly keep if minutes_running > 30 & npages == 1
	quietly keep run_token

	* Se inicia el ciclo
	local nobs = [_N]
	if `nobs' > 0 {
	
	* Mensaje
	di "[updateRunsToKill] 		... `nobs' casos identificados. Agregando a libro:"	
	
	forvalues casenum = 1/`nobs' {
		local runToCheck = run_token[`casenum']
		agregaMaestro, runtoken("`runToCheck'") file("Kill")
		}
	}
	else {
	* Mensaje
	di "[updateRunsToKill] 		... sin casos identificados ..."		
	}

	* Mensaje
	di "[updateRunsToKill] 		{it:... revisi—n finalizada.}"

end

* KillRuns. Avisa a ParseHub de detener run
////////////////////////////////////////////////////////////
capture program drop KillRuns
program def KillRuns, rclass
version 12.0
syntax [anything]

	* Mensaje
	di "[KillRuns] 			Inicializando m—dulo de cancelaci—n de runs..."

	* Cargamos archivo con detalle de apis a cancelar
	quietly capture use "${dtaPath}/RunsToKill.dta", replace
	if _rc == 0 & [_N] > 0 {

		dropDuplicates run_token
		local nobs = [_N]
		if `nobs' > 0 {

			* Mensaje
			di "[KillRuns] 			Runs a finalizar: `nobs'..."

			forvalues casenum = 1/`nobs' {
				global runToCancel = run_token[`casenum']
				* Mensaje
				di "[KillRuns] 			   ... solicitando cancelaci—n de $runToCancel ..."
				* Realizamos solicitud
				quietly parseHubRunCancel, api("${apiKey}") prt("${runToCancel}")
				}
			* Eliminamos de listado
			preserve
			quietly capture use "${dtaPath}/RunsToKill.dta", replace
			quietly drop if run_token == "${runToCancel}"
			quietly save "${dtaPath}/RunsToKill.dta", replace
			restore
			}

			* Mensaje
			di "[KillRuns] 			{it:... ciclo finalizado.}"
			
 		}
 		else {

			* Mensaje
			di "[KillRuns] 			{it:... nada que cancelar.}" 		
 		
 		}

end

* DownloadRuns. Descarga Runs
////////////////////////////////////////////////////////////
capture program drop DownloadRuns
program def DownloadRuns, rclass
version 12.0
syntax [anything]

	* Mensaje
	di "[DownloadRuns] 		Inicializando m—dulo de descarga de runs..."

	* Cargamos archivo con detalle de apis a descargar
	quietly capture use "${dtaPath}/RunsToDownload.dta", replace
	if _rc == 0 & [_N] > 0 {
		* Eliminados duplicados del proceso
		dropDuplicates run_token format
		
		* Eliminamos archivos ya descargados
		quietly capture merge 1:1 run_token using ${dtaPath}/RunsDownloaded.dta
		quietly capture drop if _merge >= 2
	
		* Iniciamos ciclo de descargas si hay > 0 observaciones
		local nobs = [_N]
		if `nobs' > 0 {
		
		* Mensaje
		di "[DownloadRuns] 		Runs a descargar: `nobs'..."
		
		forvalues casenum = 1/`nobs' {
			global runToDownload = run_token[`casenum']
			global frmtToDownload = format[`casenum']
			* Realizamos solicitud
			* Mensaje
			di "[DownloadRuns] 		... descargando run $runToDownload (`casenum' de `nobs') ..."
			parseHubRunDownload, api("${apiKey}") prt("${runToDownload}") f("${frmtToDownload}") fol("${csvPath}") file("${runToDownload}")
			}
		
		* Mensaje
		di "[DownloadRuns] 		{it:... ciclo finalizado.}"

 		}
 		else {
 		* Mensaje
		di "[DownloadRuns] 		{it:... nada que descargar.}" 		
 		}
	}
 	else {
 	* Mensaje
	di "[DownloadRuns] 		{it:... nada que descargar.}" 		
 	}
end

* Ashellrc. Programa para correr como Shell, pero guardando
* el output del terminal a un archivo de texto
////////////////////////////////////////////////////////////
capture program drop ashellrc
program def ashellrc, rclass
version 8.0
syntax anything (name=cmd)

	cd $localPath
	display `"We will run command: `cmd'"'	
	display "We will capture the standard output of this command into"
	display "string variables r(o1),r(o2),...,r(os) where s = r(no)."
	local stamp = string(uniform())
	local stamp = reverse("`stamp'")
	local stamp = regexr("`stamp'","\.",".tmp")
	local fname = "`stamp'"
	shell `cmd' >> `fname'
	tempname fh
	global tmpName `fname'
	local linenum =0
	file open `fh' using "`fname'", read
	file read `fh' line
 	while r(eof)==0 {
    	local linenum = `linenum' + 1
    	scalar count = `linenum'
    	return local o`linenum' = `"`line'"'
    	return local no = `linenum'
    	file read `fh' line
   		}
  	file close `fh'
	
	preserve
  		clear
  		insheetjson using `fname', topscalars replace
  	restore

  	local updname = "`r(run_token)'_"+subinstr(subinstr("$S_DATE $S_TIME",":","_",.)," ","_",.)
  	shell mv `fname' ${projPath}apiCall/`updname'.tmp
	cd ${projPath}

end

* AshRunList. Programa para correr como Shell, pero guardando
* el output del terminal a un archivo de texto
////////////////////////////////////////////////////////////
capture program drop ashrunlist
program def ashrunlist, rclass
version 8.0
syntax anything (name=cmd)

	cd $localPath
	display `"We will run command: `cmd'"'
  	display "We will capture the standard output of this command into"
  	display "string variables r(o1),r(o2),...,r(os) where s = r(no)."
  	local stamp = string(uniform())
  	local stamp = reverse("`stamp'")
  	local stamp = regexr("`stamp'","\.",".tmp")
  	local fname = "`stamp'"
  	shell `cmd' >> `fname'
  	tempname fh
  	global tmpName `fname'
	
  	preserve
	  	clear
	  	gen str240 run_token=""
	  	format %25s run_token
	  	insheetjson run_token using `fname', tableselector(run_list) columns(run_token) replace flatten
	  	save "${dtaPath}/TempRunList.dta", replace
  	restore
  
  	shell rm -f `fname'
  	cd ${projPath}

end

* IdentifyToProcess. Lista los archivos de una carpeta e 
* identifica aquellos que no han sido procesados (basado en
* un dta de inventario de procesados) generando listado de 
* archivos para procesar.
////////////////////////////////////////////////////////////
capture program drop identifyToProcess
program def identifyToProcess, rclass
version 12.0
syntax [anything], PATHoriginal(string) EXTfile(string) DBstorage(string)

	* Guardamos estado de la base
	preserve
	
	* Levantamiento de archivos en directorio original
	clear
	quietly gen files = ""

	local filelist: dir "`pathoriginal'" files "*.`extfile'", respectcase
	local num=0
	local appendlist

	foreach file of local filelist {
	   quietly set obs `++num'
	   quietly replace files = "`file'" if [_n] == `num'
	}
	
	* Guardar en base temporal 
	if $version != 12 {
	quietly saveold "${dtaPath}/`dbstorage'TempFilelist.dta", replace
	}
	else {
	quietly save "${dtaPath}/`dbstorage'TempFilelist.dta", replace
	}
	
	* Contrastamos la lista de procesados y la temporal
	clear
	quietly capture use "${dtaPath}/`dbstorage'ProcFilelist.dta", replace
	if _rc == 601 {
		quietly use "${dtaPath}/`dbstorage'TempFilelist.dta"	
	}	
	else {
		quietly merge 1:1 files using ${dtaPath}/`dbstorage'TempFilelist.dta
	}
	quietly capture keep if _merge == 2
	quietly capture drop _merge
	quietly capture di _rc

	* Solo se guarda lo que no est‡ procesado
	if $version != 12 {
	quietly saveold "${dtaPath}/`dbstorage'ToProcess.dta", replace
	}
	else {
	quietly save "${dtaPath}/`dbstorage'ToProcess.dta", replace
	}

	* Restauramos la base
	quietly restore

end

* dropDuplicates. Eliminamos duplicados del dataset
////////////////////////////////////////////////////////////
capture program drop dropDuplicates
program def dropDuplicates, rclass
version 12
syntax varlist

		capture drop varObsDuplicadas
		bysort `varlist': gen varObsDuplicadas=_n
		quietly keep if varObsDuplicadas==1
		quietly drop varObsDuplicadas

end

*! version 0.1 16 Julio 2016

* Programa realiza la accion que corresponde en parseHub
* Esto puede ser iniciar un run, cargar los detalles de un
* run a resultados r(), cancelar un run, o descargar el set de 
* datos y enviarlos a la carpeta correspondiente. 

* Eventualmente podd’amos incorporar que el do obtenga
* el listado de los œltimos 20 runs y llevarlos a la 
* carpeta que corresponda

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

	* Procesamos todo lo que haya que procesar y agregar a bases
	* Esto incluye: 
		* Chequear listado de apicallToProcess.dta
		* Cargar detalle en ApiCallsLog.dta
		* Eliminar item de apicallToProcess.dta
		* Incluir item en apicallProcFilelist.dta
		* Para runs inicializados, agregar item en RunToCheckStatus
		* ... (varios otros comportamientos generales
	quietly do "${doPath}/processApiCall.do"
		
end

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
	ashellrc curl -X GET "https://www.parsehub.com/api/v2/runs/`prtoken'?api_key=`apikey'"

	* Procesamos todo lo que haya que procesar y agregar a bases
	* Esto incluye: 
		* Chequear listado de apicallToProcess.dta
		* Cargar detalle en ApiCallsLog.dta
		* Eliminar item de apicallToProcess.dta
		* Incluir item en apicallProcFilelist.dta
		* Para runs inicializados, agregar item en RunToCheckStatus
		* ... (varios otros comportamientos generales
	do "${doPath}/processApiCall.do"
		
end

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

	* Procesamos todo lo que haya que procesar y agregar a bases
	* Esto incluye: 
		* Chequear listado de apicallToProcess.dta
		* Cargar detalle en ApiCallsLog.dta
		* Eliminar item de apicallToProcess.dta
		* Incluir item en apicallProcFilelist.dta
		* Para runs inicializados, agregar item en RunToCheckStatus
		* ... (varios otros comportamientos generales
	do "${doPath}/processApiCall.do"
		
end

capture program drop parseHubRunDownload
program def parseHubRunDownload, rclass
version 12.0
syntax [anything], APIkey(string) PRToken(string) Format(string) FOLder(string) FILEname(string)

		* Cargamos informaci—n de la fecha del run
		preserve
		capture use "${dtaPath}/ApiCallsLog.dta", replace
		if _rc == 0 {
			capture drop start_stata
			gen start_stata = Clock(start_time, "YMD#hms")
			format %tC start_stata
			drop if start_stata == .
			collapse (min) start_stata, by(run_token)
			keep if run_token == "`prtoken'"
			if [_N] == 1 {
				local timeStamp = string(year(dofc(start_stata[1]))) + "-" + string(month(dofc(start_stata[1])),"%02.0f") + "-" + string(day(dofc(start_stata[1])),"%02.0f") + " "
				di "`timeStamp'"
			}
		}
		restore

	* Solicitud de parseHub + guardar log de respuesta en /apiCall
	!curl -o '`folder'/`timeStamp'`filename'.`format'' -X GET "https://www.parsehub.com/api/v2/runs/`prtoken'/data?api_key=`apikey'&format=`format'"

	* Chequeamos integridad del archivo
		if "`format'" == "csv" {
			ashell zgrep 'Too much data' '`folder'/`timeStamp'`filename'.`format''
			local downdata = r(o1)
			if "`downdata'" == "Too much data. Use JSON instead." {
				!rm -f  '`folder'/`timeStamp'`filename'.`format''
				parseHubRunDownload, api("${apiKey}") prt("${runToDownload}") f("json") fol("${csvPath}") file("${runToDownload}")
				}
			}
		else if "`format'" == "json" {
			!${doPath}/json2csv.sh "${csvPath}" "`timeStamp'`filename'" "${varJsonTrad}" "${varMainJsonTrad}"
			
			*!mv '`folder'/`timeStamp'`filename'.`format'' '`folder'/`timeStamp'`filename'.`format'.gz'
			*!in2csv '`folder'/`timeStamp'`filename'.`format'.gz' > '`folder'/`timeStamp'`filename'.csv' -k ${varMainJsonTrad}
			*!rm -f  '`folder'/`timeStamp'`filename'.`format''
			
			*!cat '`folder'/`timeStamp'`filename'.`format'' | jsonv ${varJsonTrad} ${varMainJsonTrad} > '`folder'/`timeStamp'`filename'.csv'
			}
		* Eliminamos de listado
		preserve
			capture use "${dtaPath}/RunsToDownload.dta", replace
			drop if run_token == "${runToDownload}"	 & format == "${frmtToDownload}"
			save "${dtaPath}/RunsToDownload.dta", replace
		restore
		* Agregamos a RunsDownloaded
		preserve
			capture use "${dtaPath}/RunsDownloaded.dta", replace
			if _rc == 601 {
				clear
				gen str240 run_token = ""
				format %25s run_token
				}
			local nobs2 = [_N] +1
			set obs `nobs2'
			replace run_token = "`prtoken'" in `nobs2'
			capture drop varObsDuplicadas
			bysort *: gen varObsDuplicadas=_n
			keep if varObsDuplicadas==1
			drop varObsDuplicadas
			save "${dtaPath}/RunsDownloaded.dta", replace
		restore

end

capture program drop parseHubRunList
program def parseHubRunList, rclass
version 12.0
syntax [anything], APIkey(string) PRToken(string) OFFset(integer) [id(integer 0)]

	* Definicion de local macros con informacion de run por correr
	local baseurl = "https://www.parsehub.com/api/v2/projects/`prtoken'"
	local adapikey = "?api_key=`apikey'&offset=`offset'"

	* Establecimiento de url definitiva para contactar a parseHub
  	local curlCode = `"`baseurl'`adapikey'"'

	* Solicitud de parseHub + guardar log de respuesta en /apiCall
	ashrunlist curl -X GET "`curlCode'"

	* Trabajamos el ID si no se entreg—
	if "`id'" == "0" {
		preserve
			capture use "${dtaPath}/RunList.dta", replace
			capture collapse (max) id
			capture local id = id[1] +1
			if _rc == 111 {
				local id = 1
			}
			di `id'	
		restore
	}
	
	* Cargamos TempRunList para identificar cantidad de runs
	preserve
		capture use "${dtaPath}/TempRunList.dta", replace
		local nobs = [_N]	
		gen id = `id' 
		gen offset = `offset'
		capture append using "${dtaPath}/RunList.dta"
		save "${dtaPath}/RunList.dta", replace
		
		if "`offset'" == "0" & "`id'" != "1" {
			keep if id == `id' - 1 & offset == 0
			merge 1:1 run_token using ${dtaPath}/TempRunList.dta
			keep if _merge == 3
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
		parseHubRunList, api(`apikey') prt(`prtoken') off(`noffset') id(`id')
	}
		
end

*! version 0.1 16 Julio 2016

* Programa realiza la accion que corresponde en parseHub
* Esto puede ser iniciar un run, cargar los detalles de un
* run a resultados r(), cancelar un run, o descargar el set de 
* datos y enviarlos a la carpeta correspondiente. 

* Eventualmente poddamos incorporar que el do obtenga
* el listado de los ltimos 20 runs y llevarlos a la 
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

		* Cargamos informacin de la fecha del run
		preserve
		if _rc == 0 {
			format %tC start_stata
			if [_N] == 1 {
				local timeStamp = string(year(dofc(start_stata[1]))) + "-" + string(month(dofc(start_stata[1])),"%02.0f") + "-" + string(day(dofc(start_stata[1])),"%02.0f") + " "




////////////////////////////////////////////////////////////

* Ashellrc. Programa para correr como Shell, pero guardando
* el output del terminal a un archivo de texto
////////////////////////////////////////////////////////////
capture program drop ashellrc
program def ashellrc, rclass
version 8.0
syntax anything (name=cmd)

	cd $localPath


end

* AshRunList. Programa para correr como Shell, pero guardando
* el output del terminal a un archivo de texto
////////////////////////////////////////////////////////////
capture program drop ashrunlist
program def ashrunlist, rclass
version 8.0
syntax anything (name=cmd)

	cd $localPath
  

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
	gen files = ""

	local filelist: dir "`pathoriginal'" files "*.`extfile'", respectcase
	local num=0
	local appendlist

	foreach file of local filelist {
	   quietly set obs `++num'
	   quietly replace files = "`file'" if [_n] == `num'
	}
	
	* Guardar en base temporal 
	if $version != 12 {
	saveold "${dtaPath}/`dbstorage'TempFilelist.dta", replace
	}
	else {
	save "${dtaPath}/`dbstorage'TempFilelist.dta", replace
	}
	
	* Contrastamos la lista de procesados y la temporal
	clear
	capture use "${dtaPath}/`dbstorage'ProcFilelist.dta", replace
	if _rc == 601 {
		use "${dtaPath}/`dbstorage'TempFilelist.dta"	
	}	
	else {
		merge 1:1 files using ${dtaPath}/`dbstorage'TempFilelist.dta
	}
	capture keep if _merge == 2
	capture drop _merge
	capture di _rc

	* Solo se guarda lo que no est� procesado
	if $version != 12 {
	saveold "${dtaPath}/`dbstorage'ToProcess.dta", replace
	}
	else {
	save "${dtaPath}/`dbstorage'ToProcess.dta", replace
	}

	* Restauramos la base
	restore

end

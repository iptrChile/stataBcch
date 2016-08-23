// Cargamos lista de archivos en carpeta a tempFileList
***************************************************
clear
gen files = ""

local filelist: dir "${csvPath}" files "*.csv", respectcase
local num=0
local appendlist

foreach file of local filelist {
   quietly set obs `++num'
   *display as text in smcl  "working on file number {it:`num'}, `file'..."
   quietly replace files = "`file'" if [_n] == `num'
   *display as text in smcl  "... finished working on file number {it:`num'}"
   *save `file`num''
}

if $version != 12 {
saveold "${dtaPath}/tempFileList.dta", replace
}
else {
save "${dtaPath}/tempFileList.dta", replace
}

// Contrastamos la lista de procesados y la temporal
***************************************************
clear
capture use "${dtaPath}/procFileList.dta", replace
if _rc == 601 {
	use "${dtaPath}/tempFileList.dta"	
	}
	else {
	merge 1:1 files using ${dtaPath}/tempFileList.dta
	}
capture keep if _merge == 2
capture drop _merge
capture di _rc

if $version != 12 {
saveold "${dtaPath}/tempFileListToProccess.dta", replace
}
else {
save "${dtaPath}/tempFileListToProccess.dta", replace
}

// Procesamos los archivos en la temporal que no est‡n
// en la lista de procesados
***************************************************
if [_N] > 0 {

	local nobs = [_N]

	di "N es mayor que 0, es `nobs'"

	*forvalues fnum = 1/`nobs' {

		local fnum = 1
		global fileName = files[`fnum']
		di "Iniciando importaci—n de archivo nœmero {it:`fnum'}: {bf: ${fileName}}"

		preserve
			
			clear
			
			* Variables de estado para cada punto del proceso se liberan
			global importFileResult = ""
			global encodeDbResult = ""
			global appendMasterResult = ""
			global processStatus = ""
			
			* Importamos el archivo y lo guardamos en base temporal
			do "${doPath}/importFile.do"

			* Encoding de base temporal
			if "${importFileResult}" == "ok" {
				do "${doPath}/encodeDb.do"			
				}
			else {
				global processStatus = "Error 09. Importaci—n no es correcta, motivo desconocido"
			}
						
			* Agregar a base master
			if "${encodeDbResult}" == "ok" {
				do "${doPath}/appendMaster.do"
				global processStatus = "Procesamiento finalizado OK"
				}
			else {
				global processStatus = "Error 10. Encoding no es correcto, motivo desconocido"
			}
						
			* Agregamos nombre del archivo a lista de procesados
			clear
			capture use "${dtaPath}/procFileList.dta", replace
			if _rc == 601 {
				use "${dtaPath}/tempFileList.dta"
			}
			else {
				local nproc = [_N] + 1
				set obs `nproc'
				quietly replace files = "${fileName}" if [_n] == `nproc'
			}

			if $version != 12 {
				saveold "${dtaPath}/procFileList.dta", replace
			}
			else {
				save "${dtaPath}/procFileList.dta", replace
			}
			
			* WebHook con los resultados del proceso
			*!curl -v -H "Accept: application/json" -H "Content-Type: application/json" -X POST -d '{"proyecto":"${projectVer}","archivo":"${fileName}","status":"${processStatus}"}' "${urlWebHook}"
			di `"{"proyecto":"${projectVer}","archivo":"${fileName}","status":"${processStatus}"}"'
				
		restore

	*}

}

* Suite de funciones de ParseHub. 
////////////////////////////////////////////////////////////
do "${doPath}/parseHub.do"

* Ashellrc. Programa para correr como Shell, pero guardando
* el output del terminal a un archivo de texto
////////////////////////////////////////////////////////////
capture program drop ashellrc
program def ashellrc, rclass
version 8.0
syntax anything (name=cmd)

/*
 This little program immitates perl's backticks.
 Author: Nikos Askitas
 Date: 04 April 2007
 Modified and tested to run on windows. 
 Date: 05 February 2009
*/

* Run program 

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

  local updname = "`r(run_token)'."+subinstr(subinstr("$S_DATE $S_TIME",":","_",.)," ","_",.)
  shell mv `fname' ${projPath}apiCall/`updname'.tmp

if("$S_OS"=="Windows"){
 *shell del `fname'
}
else{
 *shell rm `fname'
}

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

	* Solo se guarda lo que no est‡ procesado
	if $version != 12 {
	saveold "${dtaPath}/`dbstorage'ToProcess.dta", replace
	}
	else {
	save "${dtaPath}/`dbstorage'ToProcess.dta", replace
	}

	* Restauramos la base
	restore

end

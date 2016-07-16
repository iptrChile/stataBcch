////////////////////////////////////////////////////
//// Author:	Ruben Catalan
//// Date:		26 Junio 2016
//// Proyect:	Demo BCentral.
//// dofile:	Ciclo Stata para data de Falabella
////			2 objetivos, generación de base histórica,
////			actualización de info de encoding
////////////////////////////////////////////////////	  

set more off

// Define variables de sistema 
***************************************************
global version `c(version)'
global opsys `c(os)'
global hostname `c(hostname)'
global machinetype `c(machine_type)'  
global usrname `c(username)'  

// Define directorios base 
***************************************************
if "$opsys" == "Unix" {
        global sharedPath `"/home/`c(username)'/Dropbox/iptr-shared"'
        global localPath `"/home/`c(username)'/iptr-local"'
}
else if "$opsys" == "MacOSX" {
        if "$usrname" == "ruben" {
                global sharedPath `"/users/$usrname/Dropbox/Proyectos/iptr-shared"'
                global localPath `"/users/$usrname/iptr-local"'
        }
        else if "$usrname" == "victormartinez" {
                global sharedPath `"/users/$usrname/Dropbox/iptr-shared"'
                global localPath `"/users/$usrname/iptr-local"'

        }
        else {
                global sharedPath `"/users/$usrname/Dropbox/iptr-shared"'
                global localPath `"/users/$usrname/iptr-local"'
        }
		
}
else {
di "No se pudo definir basepath para el proceso"
exit
}

di "En $opsys - $hostname el directorio a utilizar es $basePath"
cd $basePath


// Identificar MetaParámetros del Proyecto
***************************************************
* Nombre proyecto principal
global projName "stataBcch"
global lclProjectPath "${localPath}/prod/${projName}/"
global shrProjectPath "${sharedPath}/prod/${projName}/"

* Cargamos archivos para parámetros
use "${shrProjectPath}/dta/param.dta", replace

* doPath archivo principal
global doPath "${lclProjectPath}/do/"

// Cargamos parámetros para cada proyecto específico
***************************************************
local nobs = [_N]
local metaVariables = "projectVer tipoAmbiente varsImport varsUtf varsToEncode varsPrice varsDicc varsDrop varsKey reshapeLongNeed reshapeLongRename reshapeLongByproduct reshapeLongBypEncode varsDropIfEmpty urlWebHook decimal miles shortFrmt"

	* Diccionario
	**************
	* En el siguiente loop cargaremos todas las variables definidas arriba
	* projectVer tipoAmbiente : 
	* 					  Definimos nombre y ambiente de proyecto en que estamos trabajando
	* varsImport 		: Nombre de todas las variables a ser importadas
	* varsUtf 			: Variables a corregir problemas de importacion por encoding
	* varsToEncode 		: Variables a encodear hard por Stata
	* varsPrice 		: Variables string a llevar a númericas
	* varsDicc 			: Variables para desarrollo de diccionario 
	* varsDrop 			: Variables para eliminar (idealmente guardadas en el diccionario,
	* 					  y no vitales para el desarrollo del proyecto  
	* varsKey 			: Variables para generar key id (sólo un key id por base) 
	* reshapeLongNeed, reshapeLongRename, 
	* reshapeLongByproduct, reshapeLongBypEncode :
	* 					  Variables para saber si hay que hacer reshape (poner prefijo variable wide)
	* varsDropIfEmpty 	:Variables para drop si están vacías (después del reshape) 
	* urlWebHook		: URL Webhook 

forvalues projNum = 1/`nobs' {
	
	if `projNum' == 1 {   /* Eventualmente nos echaremos este if para correr todos los proyectos */
	
	foreach var of varlist `metaVariables' { 
	
		global `var' = `var'[`projNum']
		di "${`var'}"
		
	}

	// Identificar Rutas del Proyecto
	***************************************************
	global projPath "${sharedPath}/${tipoAmbiente}/${projectVer}/"
	global lblPath "${projPath}/lbl/"
	global csvPath "${projPath}/csvOutput/"
	global dtaPath "${projPath}/dta/"
	global texPath "${projPath}/tex/"
	global pngPath "${projPath}/png/"
	global epsPath "${projPath}/eps/"
	global pdfPath "${projPath}/pdf/"
	global plotPath "${projPath}/plot/"
	global apiCallPath "${projPath}/apiCall/"
	
	* Seteamos directorio de trabajo
	cd ${projPath}

	// 0. Instalamos Software e Inicializamos Stata
	***************************************************
	*do "${doPath}/installAdo.do"
	*do "${doPath}/updatePrograms.do"
	*do "${doPath}/chkDirStructure.do"

	// 1. Barrido de directorio e importación de 
	//    archivos nuevos
	***************************************************
	*do "${doPath}/actMaster.do"

	do "${doPath}/loadBasePrincipalExtended.do"  * Análisis de bases

	// 2. Realizamos Cálculos
	***************************************************
	*use "${dtaPath}/basePrincipal.dta", clear 
	*do "${doPath}/recodeDb.do"                 
	*do "${doPath}/encodeDb.do"
	*do "${doPath}/calcMaster.do"
	
	// 3. Generamos Gráficos y Archivos Tex
	***************************************************
	*do "${doPath}/genOutput.do"

	}

}
	
// 4. Salida
***************************************************
* exit, STATA clear

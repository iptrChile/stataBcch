
// Archivo chequea estructura de directorios y si
// no existen los crea
***************************************************
	
	local fileType = "proj lbl xsc dta tex png eps pdf plot apiCall"
	
	foreach fld of local fileType {
	
		confirmdir ${`fld'Path}
		if `r(confirmdir)' != 0 {
			mkdir ${`fld'Path}
		}
	
	}

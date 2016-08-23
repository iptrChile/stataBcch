
// Archivo chequea estructura de variables y si
// existen bajo otro nombre, renombra
***************************************************
		
	foreach var of varlist * {

		if "`var'" == "subcat" rename subcat sbcat
		if "`var'" == "nom" rename nom prod
		if "`var'" == "idcomercio" rename idcomercio idprod
		if "`var'" == "marca_url" rename marca_url prod_url
		if "`var'" == "produrl" rename produrl prod_url
		if "`var'" == "internet" rename internet pr_internet
		if "`var'" == "normal" rename normal pr_normal
		if "`var'" == "destac" rename destac pr_dest

	}

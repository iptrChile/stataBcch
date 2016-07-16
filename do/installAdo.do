
// Instalaci—n ADOs necesarios para el funcionamiento del do
***************************************************

capture net install confirmdir, from(http://fmwww.bc.edu/RePEc/bocode/c)			/* Utility para identificar si existe directorio */
capture net install texdoc, from(http://fmwww.bc.edu/RePEc/bocode/t)
capture net install sjlatex, from(http://www.stata-journal.com/production)
capture net install ashell, from(http://fmwww.bc.edu/RePEc/bocode/a)
ssc install libjson, replace
capture net install insheetjson, from(http://fmwww.bc.edu/RePEc/bocode/i)

// Inicializaci—n de Stata
***************************************************
clear all
set more off

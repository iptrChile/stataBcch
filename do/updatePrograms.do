////////////////////////////////////////////////////
//// Date:		26 Junio 2016
//// Programa:	ashellrc.
//// dofile:	corre comandos en el shell pero permite
////			guardar el output de estos en un tmp
////////////////////////////////////////////////////

*! version 1.0 05February2009

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

* Codigo para eliminar el archivo temporal creado
*if("$S_OS"=="Windows"){
 *shell del `fname'
*}
*else{
 *shell rm `fname'
*}

end


*! version 1.0 05February2009

capture program drop jsontomacro
program def jsontomacro, rclass
version 8.0
syntax anything (name=cmd)



capture insheetjson using "${apiCallPath}/tyTFVuu3Ch3A1k4boCtbFFuo.tmp", showresponse topscalars
return list








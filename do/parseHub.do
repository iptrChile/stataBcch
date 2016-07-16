
* Definimos par‡metros de run a correr
  local case = ""
  * opciones runStart, runDetails, runCancel, getData 
  local apiKey = ""
  local projectToken = ""
  local runToken = ""
  local startUrl = ""
  local startTemplate = ""
  local startValueOverride = ""
  local sendEmail = ""
  local dataFormat = ""
  local baseUrlC1 = "https://www.parsehub.com/api/v2"
  local baseUrlC2 = "/projects/`projectToken'"
  local baseUrlC3 = "/runs/`runToken'"

  if "`case'"= "runStart" {
  	local curlCode = "`baseUrlC1'`baseUrlC2'/run -X POST -d api_key=`apiKey' -d start_url =`startUrl' -d start_template=`startTemplate' -d start_value_override=`startValueOverride' -d send_email=`sendEmail"
  }
  elseif "`case'"= "runDetails" {
  	local curlCode = "-X GET `baseUrlC1'`baseUrlC3'/run?api_key=`apiKey'"
  }
  elseif "`case'"= "runCancel" {
  	local curlCode = "`baseUrlC1'`baseUrlC3'/cancel -X POST -d api_key=`apiKey'"
  }
  elseif "`case'"= "getData" {
  	local curlCode = "-X GET `baseUrlC1'`baseUrlC2'/data?api_key=`apiKey'?format=`dataFormat'"
  }
  else {
  	local curlCode = ""
  }

* Corremos apiCall
  ashellrc curl `curlCode'
  

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
	
  preserve
  clear
  insheetjson using `fname', topscalars replace
  restore

  shell mv `fname' apiCall/`r(run_token)'.tmp

if("$S_OS"=="Windows"){
 *shell del `fname'
}
else{
 *shell rm `fname'
}

end

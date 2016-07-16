*** program here
*! chewfile version 0.9.1 May2009 by roywada@hotmail.com
* version 0.9 Aug2008 by roywada@hotmail.com
program define chewfile
version 8.0
syntax using/, [output(string) first(numlist max=1) last(numlist max=1) clear]
local parse ","
if "`first'"=="" & "`last'"=="" {
 local first 1
 local last .
}
if "`string'"=="string" {
 local str3 "str3"
}
if "`clear'"=="clear" {
 clear
 qui set obs 1
}
if `"`output'"'=="" {
 tempfile dump
 local output `dump'
}

tempname fh outout
local linenum = 0
file open `fh' using `"`using'"', read
qui file open `outout' using `"`output'"', write replace
file read `fh' line
while r(eof)==0 {
local linenum = `linenum' + 1
 if `linenum'==1 | `linenum'>=`first' & `linenum'<=`last' {
 *display %4.0f `linenum' _asis `"`macval(line)'"'
 file write `outout' `"`macval(line)'"' _n
 
 if "`clear'"=="clear" {
  tokenize `"`macval(line)'"', parse(`"`parse'"')
  local num 1
  while "``num''"~="" {
   if `"``num''"'~=`"`parse'"' {
    cap gen str3 var`num'=""
    if _rc~=0 {
     qui set obs `=`=_N'+1'
     cap gen str3 var`num'=""
    }
    cap replace var`num'="``num''" in `linenum'
    if _rc~=0 {
     qui set obs `=`=_N'+1'
     cap replace var`num'="``num''" in `linenum'
    }
   }
   local num=`num'+1
  }
 }
}
file read `fh' line
}
file close `fh'
file close `outout'
end

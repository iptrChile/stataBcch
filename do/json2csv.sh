#!/bin/bash

PATH=$PATH:/usr/local/bin
export PATH

# Version programa jsonv
#mv "$1/$2.json" "$1/$2.json.gz"
#gunzip "$1/$2.json.gz"
#cat "$1/$2.json" | jsonv "$3" "$4" > "$1/$2.csv"
#rm -f "$1/$2.json" 
#rm -f "$1/$2.json.gz"

# Version programa in2csv
mv "$1/$2.json" "$1/$2.json.gz"
in2csv "$1/$2.json.gz" > "$1/$2.csv" -k $4
set more off

* Archivo realiza proceso de solicitudes a parseHub que son necesarias para 
* realizar el proceso recurrente y/ o chequeos y descargas pendientes en 
* los libros de cada caso. 

* El archivo sigue el siguiente orden logico: 
	* 1. Chequea estado de todos los items cargados en RunsToCheckStatus
	* 2. Cancela todos los runs que estŽn incluidos en RunsToKill
	* 3. Descarga todos los archivos que estŽn guardados en RunsToDownload
	
* Desde el punto de los temas a considerar en Do
////////////////////////////////////////////////////////////
* apicallsToProcess -> Cargamos info en ApiCallsLog
* RunsToCheckStatus -> cargamos info desde parseHub
* RunsToDownload -> descargamos los archivos que ya estŽn listos
* RunsToKill -> Cancelamos runs que est‡n con problemas

* Hacemos un loop de todos los RunsToCheckStatus. En el proceso de hacer esto 
* se va a cargar informaci—n nueva o no considerada previamente en los 3 libros
* Esto va a disparar automaticamente los apicallsToProcess, asi que no me 
* preocupo de ese ciclo. 

* En el processApiCall hay que identificar el o los trigger que llevan a 
* incluir un run en RunsToKill.  

* 1. Chequeamos estructura de archivos
////////////////////////////////////////////////////////////
parseHubFileCreation

* 2. Descargamos RunList Actualizado (listado de todos los
* runs del proyecto, o aquellos m‡s recientes si ya tengo
* historia suficiente).
////////////////////////////////////////////////////////////
parseHubRunList, api($apiKey) prt($prToken) off(0)

* 3. Cargamos informacion de apiCalls a archivo historico,
* actualizamos los detalles de RunList, y definimos acciones
* a seguir dependiendo de este resultado
////////////////////////////////////////////////////////////
updateApiCallsLog
updateRunListDetails
updateRunsToDo

* 4. Descargamos status actualizado de runs por chequear
////////////////////////////////////////////////////////////
checkStatusRuns

* 5. Nuevo ciclo, con la informaci—n nueva recien descargada
////////////////////////////////////////////////////////////
updateApiCallsLog
updateRunListDetails
updateRunsToDo

* 6. Identificamos runs a Cancelar y los cancelamos
////////////////////////////////////////////////////////////
updateRunsToKill
KillRuns

* 7. Descargamos Runs
////////////////////////////////////////////////////////////
DownloadRuns

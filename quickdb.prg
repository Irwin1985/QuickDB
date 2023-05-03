**************************************************
*-- Class:        quickdb
*-- ParentClass:  custom
*-- BaseClass:    custom
*-- Time Stamp:   01/01/23 08:28:10 PM
*
Define Class quickdb As Custom
	Hidden oViews
	oViews = .Null.
	Hidden oGroupViews
	oGroupViews = .Null.
	Hidden oConnection
	oConnection = .Null.
	Hidden nHandle
	nHandle = 0
	Hidden oProvider
	oProvider = .Null.
	Hidden oRegEx
	oRegEx = .Null.
	Version = '0.0.1'

	Procedure Init
		With This
			.oViews = Createobject("Collection")
			.oGroupViews = Createobject("Collection")
			.oRegEx = Createobject("VBScript.RegExp")
			.oRegEx.IgnoreCase = .T.
			.oRegEx.Global = .T.
		Endwith
	Endproc

	Procedure Connect
		Lparameters tcDriver, tcServer, tcUser, tcPwd, tcDatabase, tnPort

		This.oConnection = Createobject('Empty')
		AddProperty(This.oConnection, 'Driver', tcDriver)
		AddProperty(This.oConnection, 'Server', tcServer)
		AddProperty(This.oConnection, 'Database', tcDatabase)
		AddProperty(This.oConnection, 'Uid', tcUser)
		AddProperty(This.oConnection, 'Pwd', tcPwd)
		AddProperty(This.oConnection, 'Port', Transform(tnPort))

		SQLSetprop(0, 'ConnectTimeOut', 15)
		SQLSetprop(0,"DispLogin",3)
		CursorSetProp("MapBinary",.T.,0)

		If This.nHandle > 0
			Messagebox("Ya existe una conexión activa, ciérrela con Disconnect() e intente nuevamente.", 48, "QuickDB")
			Return
		Endif

		Local lResult, lcConnectionString
		Try
			With This
				* Create a connection object
				.loadProvider()
				lcConnectionString = .oProvider.getConnectionString(.oConnection)
				lResult = .T.
				.nHandle = Sqlstringconnect(lcConnectionString, .T.)

				If This.nHandle > 0
					.applyConnectionSettings()
				Else
					this.showError()
					lResult = .F.
				Endif
			Endwith
		Catch To loEx
			This.fmtError(loEx)
		Endtry

		Return lResult
	Endproc

	Procedure fmterror
		Lparameters toError

		Local msg
		msg = Padr("Error:", 20, Space(1)) + Alltrim(Str(toError.ErrorNo))
		msg = msg + Chr(13) + Padr("LineNo:", 20, Space(1)) + Alltrim(Str(toError.Lineno))
		msg = msg + Chr(13) + Padr("Message:", 20, Space(1)) + Alltrim(toError.Message)
		msg = msg + Chr(13) + Padr("Procedure:", 20, Space(1)) + Alltrim(toError.Procedure)
		msg = msg + Chr(13) + Padr("Details:", 20, Space(1)) + Alltrim(toError.Details)
		msg = msg + Chr(13) + Padr("StackLevel:", 20, Space(1)) + Alltrim(Str(toError.StackLevel))
		msg = msg + Chr(13) + Padr("LineContents:", 20, Space(1)) + Alltrim(toError.LineContents)
		msg = msg + Chr(13) + Padr("UserValue:", 20, Space(1)) + Alltrim(toError.UserValue)

		Messagebox(msg, 16, "QuickDB Error")
	Endproc

	Hidden Procedure applyConnectionSettings
		* Habilitar Buffering
		Set Multilocks On
		* Habilitar Transacciones Manuales en VFP
		*SQLSetprop(This.nHandle, 'Transactions', 2)
		* Aplicar Rollback al desconectar
		SQLSetprop(This.nHandle, 'DisconnectRollback', .T.)
		* Mostrar Errores sql nativos
		SQLSetprop(This.nHandle, 'DispWarnings', .T.)
		* Conjuntos de resultado retornados sincrónicamente
		SQLSetprop(This.nHandle, 'Asynchronous', .F.)
		* SQLEXEC retorna los resultados en una sola vez
		SQLSetprop(This.nHandle, 'BatchMode', .T.)
		* Tiempo en minutos para que una conexión no usada se desactive (0 = nunca)
		SQLSetprop(This.nHandle, 'IdleTimeout', 0)
		* Tamaño del paquete de datos usado por la conexión (4096)
		*SQLSetprop(This.nHandle, 'PacketSize', 4096)
		* El tiempo de espera, en segundos, antes de retornar un error general
		SQLSetprop(This.nHandle, 'QueryTimeOut', 0)
		* El tiempo, en milisegundos, hasta que VFP verifique que la instrucción SQL se completó
		SQLSetprop(This.nHandle, 'WaitTime', 100)

	Endproc

	Hidden Procedure loadProvider
		This.oProvider = .Null.

		Dimension laProviders[6, 2]
		laProviders[1,1] = "MySQL\s+ODBC\s+\d\.\d{1,2}\s+[(ANSI\s)|(Unicode)]*Driver"
		laProviders[1,2] = "MySQL"

		laProviders[2,1] = "MariaDB\s+ODBC\s+\d\.\d{1,2}\s+Driver"
		laProviders[2,2] = "MariaDB"

		laProviders[3,1] = "Firebird/InterBase\(r\)\s+driver"
		laProviders[3,2] = "Firebird"

		laProviders[4,1] = "PostgreSQL\s+ANSI"
		laProviders[4,2] = "PostgreSQL"

		laProviders[5,1] = "SQL\s+Server"
		laProviders[5,2] = "SqlServer"

		laProviders[6,1] = "SQLite3\s+ODBC\s+Driver"
		laProviders[6,2] = "SQLite3"

		Local i
		For i = 1 To Alen(laProviders, 1)
			If This.testRegEx(laProviders[i,1], This.oConnection.Driver)
				This.oProvider = Createobject(laProviders[i,2])
				Exit
			Endif
		Endfor

		If Isnull(This.oProvider)
			Messagebox("Proveedor desconocido: '" + This.oConnection.Driver + "'", 16, "QuickDB Error")
		Endif
	Endproc

	Procedure closeAll
		Try
			Local i, loView, lcAlias
			lcAlias = Alias()
			For i = 1 To This.oViews.Count
				loView = This.oViews.Item(i)
				If Used(loView.Alias)
					Select (loView.Alias)
					If loView.SendUpdates
						Tablerevert(.T.) && Revert pending changes
					Endif
					Use
				Endif
				Release loView
			Endfor
			If !Empty(lcAlias) And Used(lcAlias)
				Select (lcAlias)
			Endif
			This.oViews = Createobject('Collection')		&& Reset all created views.
			This.oGroupViews = Createobject('Collection')	&& Reset all created groups.
		Catch
		Endtry
	Endproc

	Procedure disconnect
		Try
			This.CloseAll()
		Catch
		Endtry

		Try
			SQLDisconnect(This.nHandle)
			This.nHandle = 0
		Catch
		Endtry
	Endproc

	Procedure Open
		Lparameters tcSelectCmd, tcAlias, tcGroup

		Try
			Local i, lcField, lcPrimaryKey, lcSqlTableName, lcDataBase, lcSchema, lnIndex, lcOldDatabase, loView as CursorAdapter, lcUpdaTableFieldList, lcUpdateNameList

			This.parseQueryInfo(tcSelectCmd, @lcDataBase, @lcSchema, @lcSqlTableName)
			If !Empty(lcDataBase)
				lcOldDatabase = This.oConnection.Database
				This.oConnection.Database = lcDataBase
			Endif
			lcPrimaryKey = This.getPrimaryKey(lcSqlTableName)

			If Empty(tcAlias)
				tcAlias = lcSqlTableName
			Endif
			
			If !Used(tcAlias)
				loView = Createobject('CursorAdapter')
				loView.DataSourceType = 'ODBC'
				loView.Datasource = This.nHandle
				loView.Alias = tcAlias
				loView.SelectCmd = tcSelectCmd
				loView.Tables = lcSqlTableName
				loView.KeyFieldList = lcPrimaryKey
				loView.SendUpdates = .T.

				* Traer solo estructura para extraer información de las columnas.
				loView.Nodata = .T.
				If !loView.CursorFill()
					this.showError()
				Endif
				Select (tcAlias)
				Store '' To lcUpdaTableFieldList, lcUpdateNameList
				For i = 1 To Afields(laFields)
					lcField = laFields[i,1]
					If i > 1
						lcUpdaTableFieldList = lcUpdaTableFieldList + ', '
						lcUpdateNameList = lcUpdateNameList + ', '
					Endif
					lcUpdaTableFieldList = lcUpdaTableFieldList + lcField
					lcUpdateNameList = lcUpdateNameList + lcField + Space(1) + lcSqlTableName + '.' + lcField
				Endfor

				loView.UpdatableFieldList = lcUpdaTableFieldList
				loView.UpdateNameList = lcUpdateNameList
				loView.Nodata = .F.
				If !loView.CursorFill()
					this.showError()
					llReturn = .F.
				EndIf		

				=CursorSetProp("FetchSize", -1, tcAlias)
				* Esperar hasta completar todos los registros para eviar error 'Connection is Busy'
				Do While SQLGetprop(This.nHandle, "ConnectBusy")
					Wait Window "Recuperando información de la tabla actual, espere..."  Nowait
					=Inkey(0.3, "H")
				Enddo
				Wait Clear
				Go top in (tcAlias)
				
				* Aplicar índices
				This.ApplyIndex(lcSqlTableName, tcAlias)
				=CursorSetProp("Buffering", 5)

				This.oViews.Add(loView, Lower(tcAlias))

				If !Empty(tcGroup)
					This.addViewToGroup(Lower(tcGroup), Lower(tcAlias))
				Endif
				If !Empty(lcOldDatabase)
					This.oConnection.Database = lcOldDatabase
				Endif
				llReturn = .T.
			Else
				Messagebox("Ya existe una vista abierta con este mismo nombre en la sesión actual.", 16, "QuickDB")
				llReturn = .F.
			Endif
		Catch To loEx
			llReturn = .F.
			This.fmtError(loEx)
		Endtry
		Return llReturn
	Endproc


	Procedure Close
		Lparameters tcAlias

		If Empty(tcAlias)
			tcAlias = Alias()
		Endif

		If !Used(tcAlias)
			Return .F.
		Endif

		Local lnIndex, lcAlias, loView

		* Intentamos buscar como Vista
		lnIndex = This.oViews.GetKey(Lower(tcAlias))
		If Empty(lnIndex)
			Return .F.
		Endif
		loView = This.oViews.Item(lnIndex)
		Select (tcAlias)

		If loView.SendUpdates
			=Tablerevert(.T.) && just in case there's pending changes.
		Endif
		Use

		* Release the cursorAdapter allocated in global scope.
		This.oViews.Remove(lnIndex)
		Release loView

		Return .T.
	Endproc

	Procedure Query
		Lparameters tcSelectCmd, tcAlias, tcGroup

		Try
			Local loView
			If !Used(tcAlias)
				loView = Createobject('CursorAdapter')
				loView.DataSourceType = 'ODBC'
				loView.Datasource = This.nHandle
				loView.Alias = tcAlias
				loView.SelectCmd = tcSelectCmd
				loView.SendUpdates = .F.
				If !loView.CursorFill()
					this.showError()
				Endif

				=CursorSetProp("FetchSize", -1, tcAlias)
				Do While SQLGetprop(This.nHandle, "ConnectBusy")
					Wait Window "Recuperando información de la tabla actual, espere..."  Nowait
					=Inkey(0.3, "H")
				Enddo
				Wait Clear

				This.oViews.Add(loView, Lower(tcAlias))
				If !Empty(tcGroup)
					This.addViewToGroup(Lower(tcGroup), Lower(tcAlias))
				Endif
			Else
				Messagebox("Ya existe un cursor con este mismo nombre en la sesión actual.", 16, "QuickDB")
			Endif
		Catch To loEx
			This.fmtError(loEx)
		Endtry
		Return loView
	Endproc

	Hidden Procedure addviewtogroup
		Lparameters tcGroup, tcAlias

		Local lnIndex, loViews As Collection
		lnIndex = This.oGroupViews.GetKey(Lower(tcGroup))
		If Empty(lnIndex)
			loViews = Createobject('Collection')
		Else
			loViews = This.oGroupViews.Item(lnIndex)
			This.oGroupViews.Remove(lnIndex)
		Endif
		Try
			loViews.Add(tcAlias)
			This.oGroupViews.Add(loViews, tcGroup)
		Catch
			* View already saved.
		Endtry
	Endproc

	Procedure saveGroup
		Lparameters tcGroup

		If Empty(tcGroup)
			Return .F.
		Endif
		Local lnIndex, loViews, i, lOk, loView, lcScript, lcAlias, lnOldTransactionSeting
		lnIndex = This.oGroupViews.GetKey(Lower(tcGroup))
		If Empty(lnIndex)
			Return .F.
		Endif

		lcScript = 'set datasession to ' + Alltrim(Str(Set("Datasession"))) + Chr(13) + Chr(10)
		loViews = This.oGroupViews.Item(lnIndex)
		If Empty(loViews.Count)
			Return .F.
		Endif

		lnOldTransactionSeting = SQLGetprop(This.nHandle, "Transactions")
		SQLSetprop(This.nHandle, "Transactions", 2) && Change to manual transactions

		Begin Transaction
		This.beginTransaction()

		For i=1 To loViews.Count
			lcAlias = loViews.Item(i)
			loView = This.oViews.Item(lcAlias)
			If !loView.SendUpdates
				Loop && Ignore cursor
			Endif
			lcScript = lcScript + "select " + loView.Alias + Chr(13) + Chr(10)
			lcScript = lcScript + "=TableRevert(.T.) " + Chr(13) + Chr(10)
			Select (loView.Alias)
			lOk = Tableupdate(2, .F., loView.Alias)
			If !lOk
				Exit
			Endif
		Endfor

		If lOk
			This.endTransaction()
			End Transaction
		Else
			this.showError()
			This.cancelTransaction()
			Rollback
			=Execscript(lcScript)
		Endif
		SQLSetprop(This.nHandle, "Transactions", lnOldTransactionSeting)

		Return lOk
	Endproc

	Procedure closeGroup
		Lparameters tcGroup

		If Empty(tcGroup)
			Return .F.
		Endif
		Local lnIndex, loViews, i, loView, lcAlias
		lnIndex = This.oGroupViews.GetKey(Lower(tcGroup))
		If Empty(lnIndex)
			Return .F.
		Endif

		loViews = This.oGroupViews.Item(lnIndex)
		If Empty(loViews.Count)
			Return .F.
		Endif

		For i=1 To loViews.Count
			lcAlias = loViews.Item(i)
			loView = This.oViews.Item(lcAlias)
			Select (loView.Alias)
			If loView.SendUpdates
				TableRevert(.t.)
			Endif
			Use
			Release loView
		Endfor

		Return .t.
	Endproc

	Procedure Save
		Lparameters tcAlias

		If Empty(tcAlias)
			tcAlias = Alias()
		Endif
		Local lnOldTransactionSeting, lnIndex, lOk, loView

		lnOldTransactionSeting = SQLGetprop(This.nHandle, "Transactions")
		SQLSetprop(This.nHandle, "Transactions", 2) && Change to manual transactions

		lnIndex = This.oViews.GetKey(Lower(tcAlias))
		If Empty(lnIndex)
			Return .F.
		Endif

		loView = This.oViews.Item(lnIndex)
		If !loView.SendUpdates
			Return .F.
		Endif

		Begin Transaction
		This.beginTransaction()
		Select (loView.Alias)
		lnOk = Tableupdate(2, .F., loView.Alias)
		If lnOk
			This.endTransaction()
			End Transaction
		Else
			This.cancelTransaction()
			Rollback
		Endif

		SQLSetprop(This.nHandle, "Transactions", lnOldTransactionSeting)

		Return lOk
	Endproc

	Procedure begintransaction
		Local lcQuery
		* Setear la base de datos
		lcQuery = "use " + This.oConnection.Database
		This.SQLExec(lcQuery)

		* Consultar el comando para iniciar la transacción
		lcQuery = This.oProvider.getBeginTransactionCommand()

		This.SQLExec(lcQuery)

		Return .T.
	Endproc

	Procedure endtransaction
		Local lcQuery
		* Setear la base de datos
		lcQuery = "use " + This.oConnection.Database
		This.SQLExec(lcQuery)

		* Consultar el comando para finalizar la transacción (commit)
		lcQuery = This.oProvider.getEndTransactionCommand()
		This.SQLExec(lcQuery)

		Return .T.
	Endproc

	Procedure canceltransaction
		Local lcQuery
		* Setear la base de datos
		lcQuery = "use " + This.oConnection.Database
		This.SQLExec(lcQuery)

		* Consultar el comando para revertir la transacción (rollback)
		lcQuery = This.oProvider.getRollbackCommand()
		This.SQLExec(lcQuery)
	Endproc

	Hidden Procedure parsequeryinfo
		Lparameters tcSelectCmd, tcDatabase, tcSchema, tcTable

		Local loResult, loItem, loSubMatch, lcDatabase, lcSchema, lcTable
		This.oRegEx.Pattern = "from\s+(\w+)\.?(\w+)?\.?(\w+)?"
		loResult = This.oRegEx.Execute(tcSelectCmd)
		Store '' To lcDatabase, lcSchema, lcTable

		If Type('loResult') == 'O' And loResult.Count == 1
			loItem = loResult.Item[0]
			If Type('loItem') == 'O' And Type('loItem.SubMatches') == 'O'
				Do Case
				Case !Isnull(loItem.SubMatches[0]) And Isnull(loItem.SubMatches[1]) And Isnull(loItem.SubMatches[2]) && Solo tabla
					lcTable = loItem.SubMatches[0]

				Case !Isnull(loItem.SubMatches[0]) And Isnull(loItem.SubMatches[1]) And !Isnull(loItem.SubMatches[2]) && Base de datos + Tabla
					lcDatabase = loItem.SubMatches[0]
					lcTable = loItem.SubMatches[2]

				Case !Isnull(loItem.SubMatches[0]) And !Isnull(loItem.SubMatches[1]) And Isnull(loItem.SubMatches[2]) && Esquema + Tabla
					lcSchema = loItem.SubMatches[0]
					lcTable = loItem.SubMatches[1]

				Case !Isnull(loItem.SubMatches[0]) And !Isnull(loItem.SubMatches[1]) And !Isnull(loItem.SubMatches[2]) && Base de datos + Esquema + Tabla
					lcDatabase = loItem.SubMatches[0]
					lcSchema = loItem.SubMatches[1]
					lcTable = loItem.SubMatches[2]
				Endcase
			Endif
		Endif
		tcDatabase = lcDatabase
		tcSchema = lcSchema
		tcTable = lcTable

		Return .T.
	Endproc

	Procedure getprimarykey
		Lparameters tcTableName

		Local lcQuery
		* Setear la base de datos
		lcQuery = "use " + This.oConnection.Database
		This.SQLExec(lcQuery)

		* Consultar el campo clave
		lcQuery = This.getPrimaryKeyCommand(tcTableName)
		If !This.SQLExec(lcQuery, "qPrimaryKey")
			Return
		Endif
		lcKeyField = Alltrim(Strtran(qPrimaryKey.pkField, Chr(0)))
		Use In qPrimaryKey

		Return lcKeyField
	Endproc

	Procedure applyIndex
		Lparameters tcTableName, tcAlias

		Local lcQuery, lcMacro, lcFilter, lcIndexName, lcIndexKeys
		lcMacro = ''
		* Setear la base de datos
		lcQuery = "use " + This.oConnection.Database
		This.SQLExec(lcQuery)

		lcQuery = This.oProvider.getTableIndex()
		lcFilter = This.oProvider.getIndexFilter()

		lcQuery = Strtran(lcQuery, '@DB_NAME', Alltrim(This.oConnection.Database))
		lcQuery = Strtran(lcQuery, '@TBL_NAME', tcTableName)

		This.SQLExec(lcQuery, "QuickDbCurIndex")
		Select QuickDbCurIndex
		Scan For &lcFilter
			lcIndexName = Alltrim(Strtran(Strtran(Alltrim(QuickDbCurIndex.index_name), Chr(0)), Space(1)))
			lcIndexKeys = Alltrim(Strtran(Strtran(Alltrim(QuickDbCurIndex.index_keys), Chr(0)), Space(1)))

			Select (tcAlias)
			try
				Index On &lcIndexKeys Tag &lcIndexName Additive
			Catch 
			endtry
		Endscan

		Use In QuickDbCurIndex

		Select (tcAlias)
	Endproc

	Procedure SQLExec
		Lparameters tcSQLCommand, tcCursorName

		** SQLite3 no tiene el comando USE... para direccionar la base de datos...
		If Left(tcSQLCommand, 3) == 'use' And This.oProvider.Name == 'sqlite3' && HCM
			Return .T. && HCM
		Endif         && HCM

		If Empty(tcCursorName)
			tcCursorName = Sys(2015)
		Endif

		Local lnResult
		lnResult = 0
		Try
			lnResult = SQLExec(This.nHandle, tcSQLCommand, tcCursorName)
		Catch To loEx
			This.fmtError(loEx)
		Endtry

		If lnResult <= 0
			=Aerror(sqlerror)
			Messagebox(sqlerror[2], 16, "Error de comunicación")
		Endif

		Return lnResult > 0
	Endproc

	Hidden Procedure getprimarykeycommand
		Lparameters tcTableName

		Local lcQuery
		lcQuery = This.oProvider.getTablePrimaryKey()
		lcQuery = Strtran(lcQuery, '@DB_NAME', Alltrim(This.oConnection.Database))
		lcQuery = Strtran(lcQuery, '@TBL_NAME', tcTableName)

		Return lcQuery
	Endproc

	Procedure tableExists
		Lparameters tcTableName

		Local lcQuery, lcSchema

		* Setear la base de datos
		lcQuery = "use " + This.DbProp.Database
		This.SQLExec(lcQuery)

		* Consultar el campo clave
		lcQuery = This.provider.tableExists()
		lcQuery = Strtran(lcQuery, '@DB_NAME', Alltrim(This.DbProp.Database))
		lcQuery = Strtran(lcQuery, '@TBL_NAME', tcTableName)

		If !This.SQLExec(lcQuery, "qTableExists")
			Return .F.
		Endif

		lcSchema = Alltrim(Strtran(qTableExists.TABLE_SCHEMA, Chr(0)))

		Use In qTableExists

		Return !Empty(lcSchema)
	Endproc

	Hidden Procedure testRegEx
		Lparameters tcPattern, tcTest

		This.oRegEx.Pattern = tcPattern
		Return This.oRegEx.test(tcTest)
	Endproc

	Procedure Destroy
		This.CloseAll()
	EndProc
	
	Procedure showError
		Local array laError[2]
		AError(laError)
		Messagebox("ERROR: " + Alltrim(Str(laError[1])) + Chr(13) + Chr(10) + "MESSAGE:" + Transform(laError[2]), 16, "QuickDB")
	EndProc
Enddefine
*
*-- EndDefine: quickdb
**************************************************

**************************************************
*-- Class:        baseengine (c:\a1\quickdb\quickdb.vcx)
*-- ParentClass:  custom
*-- BaseClass:    custom
*-- Time Stamp:   01/01/23 07:12:06 PM
*
Define Class baseengine As Custom

	Procedure getconnectionstring
		Lparameters toConnection

		* default connection string
		Local lcStringConnect, lcDriver

		lcStringConnect = "DRIVER=" + toConnection.Driver + ";SERVER=" + toConnection.Server + ";UID=" + toConnection.Uid + ";PWD=" + toConnection.pwd
		If !Empty(toConnection.port)
			lcStringConnect = lcStringConnect + ";PORT=" + toConnection.port
		Endif
		If !Empty(toConnection.Database)
			lcStringConnect = lcStringConnect + ";DATABASE=" + toConnection.Database
		Endif

		Return lcStringConnect
	Endproc

	Procedure tableexists
		* Abstract
	Endproc

	Procedure gettableindex
		* Abstract
	Endproc

	Procedure getindexfilter
		* Abstract
	Endproc

	Procedure gettableprimarykey
		* Abstract
	Endproc

	Procedure acceptqueryoperator
		* Abstract
	Endproc

	Procedure getbegintransactioncommand
		* Abstract
	Endproc

	Procedure getendtransactioncommand
		* Abstract
	Endproc

	Procedure getrollbackcommand
		* Abstract
	Endproc

Enddefine
*
*-- EndDefine: baseengine
**************************************************


* ==================================================== *
* SQL SERVER
* ==================================================== *
Define Class SQLServer As BaseEngine

	Procedure tableexists
		Local lcScript
		TEXT to lcScript noshow
					SELECT TABLE_SCHEMA FROM INFORMATION_SCHEMA.TABLES
					 WHERE TABLE_CATALOG = '@DB_NAME'
					 AND  TABLE_NAME = '@TBL_NAME'
		ENDTEXT

		Return lcScript
	Endproc

	Procedure gettableindex
		Return "EXEC sp_helpindex '@TBL_NAME'"
	Endproc


	Procedure getindexfilter
		Return " left(Alltrim(index_description), 12) == 'nonclustered'"
	Endproc


	Procedure gettableprimarykey
		Local lcScript
		TEXT to lcScript noshow
					SELECT K.COLUMN_NAME AS PKFIELD FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE K
					   INNER JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS TC
					   ON K.TABLE_CATALOG = TC.TABLE_CATALOG
					   AND K.TABLE_SCHEMA = TC.TABLE_SCHEMA
					   AND K.CONSTRAINT_NAME = TC.CONSTRAINT_NAME
					   WHERE TC.CONSTRAINT_TYPE = 'PRIMARY KEY' AND K.TABLE_NAME = '@TBL_NAME';
		ENDTEXT

		Return lcScript
	Endproc

	Procedure getbegintransactioncommand
		Return 'BEGIN TRANSACTION'
	Endproc


	Procedure getendtransactioncommand
		Return 'IF @@TRANCOUNT > 0 COMMIT'
	Endproc


	Procedure getrollbackcommand
		Return 'IF @@TRANCOUNT > 0 ROLLBACK'
	Endproc


Enddefine

* ==================================================== *
* MySQL
* ==================================================== *
Define Class MySQL As BaseEngine

	Procedure tableexists
		Local lcScript
		TEXT to lcScript noshow
			SELECT table_schema
			FROM information_schema.tables
			WHERE table_schema = '@DB_NAME'
			    AND table_name = '@TBL_NAME'
			LIMIT 1
		ENDTEXT
		Return lcScript
	Endproc


	Procedure gettableindex
		Local lcScript
		TEXT to lcScript noshow
			SELECT DISTINCT
			    index_name, column_name as index_keys
			FROM INFORMATION_SCHEMA.STATISTICS
			WHERE TABLE_SCHEMA = '@DB_NAME' and table_name = '@TBL_NAME'
		ENDTEXT
		Return lcScript
	Endproc


	Procedure getindexfilter
		Return " !empty(index_name)"
	Endproc


	Procedure gettableprimarykey
		Local lcScript
		TEXT to lcScript noshow
			SELECT COLUMN_NAME AS PKFIELD
			FROM INFORMATION_SCHEMA.COLUMNS
			WHERE TABLE_SCHEMA = '@DB_NAME'
			  AND TABLE_NAME = '@TBL_NAME'
			  AND COLUMN_KEY = 'PRI'
		ENDTEXT
		Return lcScript
	Endproc

	Procedure getbegintransactioncommand
		Return 'START TRANSACTION;'
	Endproc


	Procedure getendtransactioncommand
		Return 'COMMIT;'
	Endproc


	Procedure getrollbackcommand
		Return 'ROLLBACK;'
	Endproc

Enddefine

* ==================================================== *
* MySQL
* ==================================================== *
Define Class MariaDB As MySQL
	* Same Implementation
Enddefine

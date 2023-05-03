clear all
release all
close databases all

set default to justpath(sys(16))
set procedure to ..\QuickDB.prg additive
set Multilocks on

local loDB
loDB = createobject("QuickDB")
loDB.Connect("SQL Server Native Client 11.0", "PC-IRWIN\SQLIRWIN", "sa", "Subifor2012", "virfijos")

public _codigo
_codigo = 587
_screen.tag = "587"

loDB.Open("Select * from gsocios where codigo = ?_screen.tag", "vSocios")
select vSocios
browse

_screen.tag = "11"
requery()

replace nombre with "JESICA SAFLA"

tableupdate(.t., .t.)

browse

loDB.Close()

loDB.Disconnect()
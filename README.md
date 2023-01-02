# QuickDB
Conector sencillo para bases de datos remotas.

## Ejemplo de uso

```xBase
Local loDB
loDb = NewObject('QuickDB', 'c:\ruta\del\prg\quickdb.prg')

// Crear una conexión contra un servidor remoto
loDb.Connect("MySQL ODBC 8.0 ANSI Driver", "localhost", "root", "1234", "sampleDB")

// Abrir una vista actualizable
loDb.Open("SELECT * FROM Personas", "vPersonas")

// Hacer cualquier operación sobre la vista
SELECT Personas
REPLACE nombre WITH "Peter"

// Guardar los cambios en la base de datos
loDb.Save('Personas')

release loDB
```

## Agrupando vistas

El siguiente ejemplo abre una serie de vistas por grupo y aplica operaciones sobre un grupo en particular.

```xBase
Local loDB
loDb = NewObject('QuickDB', 'c:\ruta\del\prg\quickdb.prg')

// Crear una conexión contra un servidor remoto
loDb.Connect("MySQL ODBC 8.0 ANSI Driver", "localhost", "root", "1234", "sampleDB")

// Abrir las vistas por grupo
loDb.Open("SELECT * FROM Facturas", "vFacturas", "GrupoFacturacion")
loDb.Open("SELECT * FROM DetalleFacturas", "vDetalle", "GrupoFacturacion")
loDb.Open("SELECT * FROM Pagos", "vPagos", "GrupoFacturacion")

loDb.Open("SELECT * FROM Impuestos", "vImpuestos", "GrupoAdmin")
loDb.Open("SELECT * FROM Retenciones", "vRetenciones", "GrupoAdmin")

// Guardar los cambios de un grupo
loDb.SaveGroup('GrupoFacturacion')

// Cerrar las vistas de un grupo
loDb.CloseGroup('GrupoAdmin')

// Cerrar todas las vistas
loDb.CloseAll()

release loDB
```

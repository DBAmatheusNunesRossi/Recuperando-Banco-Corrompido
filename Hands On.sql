/*********************************************
 Autor: Matheus Nunes Rossi
 
 Hands On: Recuperando banco corrompido
**********************************************/
USE master
go


/*******************************
 Cria banco VendasDB e corrompe
********************************/
DROP DATABASE IF exists VendasDB
go

CREATE DATABASE VendasDB
go

-- IF EXISTS só a partir do SQL Server 2016
DROP TABLE IF exists VendasDB.dbo.Cliente

CREATE TABLE VendasDB.dbo.Cliente (
	ClienteID int not null primary key,Nome char(900),Telefone varchar(20)
)
go

INSERT VendasDB.dbo.Cliente VALUES 
(1,'Jose','1111-1111'),
(2,'Maria','2222-2222'),
(3,'Ana','3333-3333'),
(4,'Paula','1111-1111'),
(5,'Marcio','2222-2222'),
(6,'Erick','3333-3333'),
(7,'Luana','1111-1111'),
(8,'Mario','2222-2222'),
(9,'Carla','3333-3333'),
(10,'Marina','3333-3333')
go

CREATE UNIQUE INDEX ixu_Cliente_Nome ON VendasDB.dbo.Cliente (Nome)
go

SELECT * 
FROM VendasDB.dbo.Cliente -- 10 linhas

-- Backup FULL e Backup Log do banco 
BACKUP DATABASE VendasDB TO DISK = 'C:\MSSQL\Backups\FULL\VendasDB.bak' WITH format, compression


/************************************
 Corrompendo um Data Page
*************************************/
DBCC IND (VendasDB, 'Cliente', -1)

ALTER DATABASE VendasDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE
DBCC WRITEPAGE ('VendasDB', 1, 505, 4000, 1, 0x45, 1)
ALTER DATABASE VendasDB SET MULTI_USER WITH NO_WAIT

SELECT * 
FROM VendasDB.dbo.Cliente 
WHERE Nome = 'Jose' -- OK

SELECT * 
FROM VendasDB.dbo.Cliente 
WHERE Nome = 'Carla'

SELECT * 
FROM VendasDB.dbo.Cliente 

/***************************
Msg 824, Level 24, State 2, Line 67
SQL Server detected a logical consistency-based I/O error: incorrect checksum (expected: 0x13322275; actual: 0x13324675). 
It occurred during a read of page (1:505) in database ID 7 at offset 0x000000003f2000 in file 'C:\MSSQL\Data\VendasDB.mdf'.  
Additional messages in the SQL Server error log or operating system error log may provide more detail. 
This is a severe error condition that threatens database integrity and must be corrected immediately. 
Complete a full database consistency check (DBCC CHECKDB). This error can be caused by many factors; 
for more information, see SQL Server Books Online.
***************************/

-- TRUNCATE TABLE msdb..suspect_pages
SELECT * 
FROM msdb..suspect_pages -- Onde ocorreu o erro?

-- Verifica a integridade
DBCC CHECKDB (VendasDB) WITH NO_INFOMSGS


/*******************
 Restore de Pagina
********************/
RESTORE DATABASE VendasDB PAGE = '1:505'
FROM DISK = 'C:\MSSQL\Backups\FULL\VendasDB.bak' WITH NORECOVERY

BACKUP LOG VendasDB TO DISK = 'C:\MSSQL\Backups\LOG\VendasDB_01.trn' WITH FORMAT, COMPRESSION 

RESTORE LOG VendasDB FROM DISK = 'C:\MSSQL\Backups\LOG\VendasDB_01.trn' WITH RECOVERY

SELECT * 
FROM VendasDB.dbo.Cliente -- 10 linhas

-- Exclui banco
DROP DATABASE IF exists VendasDB





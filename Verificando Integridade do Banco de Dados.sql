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
BACKUP LOG VendasDB TO DISK = 'C:\MSSQL\Backups\LOG\VendasDB_01.trn' WITH format, compression


/***********************************************************************************
DBCC IND - Lista as páginas de um objeto no banco de dados
DBCC IND ( { 'dbname' | dbid }, { 'objname' | objid }, { nonclustered indid | 1 | 0 | -1 | -2 } [, partition_number] )

1° parâmetro: nome do banco, se passar zero pega o banco corrente

2° parâmetro: nome da tabela

3° parâmetro: index_id (-1 mostra tudo)

SELECT [name] as NomeIndice, index_id, [type], type_desc 
FROM sys.indexes WHERE [object_id] = object_id('Cliente')

4° parâmetro: opcional, indica o número da partição (partition_id)

PageFID: número do arquivo de dados onde a página está.
PagePID: número da página dentro do arquivo de dados.
IAMFIND: número do arquivo de dados que contém a página do IAM que armazena o endereço da página
IAMFPID: número da página do IAM que armazena o endereço da página

PageType:
1  - Data Page
2  - Index Page
10 - IAM Page

IndexLevel: zero nível folha
***********************************************************************************/

DBCC TRACEON (2588) -- Habilita o uso do DBCC HELP
DBCC HELP ('IND')

DBCC IND (VendasDB,'Cliente',-1)


/*********************************************
 Corrompendo Data Page
**********************************************/
-- Utilizar DBCC PAGE
DBCC TRACEON (2588) -- Habilita o uso do DBCC HELP
DBCC HELP ('PAGE')

DBCC TRACEON(3604) -- Habilita o uso do DBCC PAGE
DBCC PAGE(VendasDB, 1, 265, 3) --WITH NO_INFOMSGS, TABLERESULTS 


/*********************************************************
 ATENÇÃO muito cuidado!
 - Escreve direto nas páginas de arquivos de dados.
 - Não gera escrita no Transaction Log e não tem ROLLBACK.
 - Utilizado apenas para estudo, demonstrações e testes. 
**********************************************************/
DBCC HELP ('WRITEPAGE') -- dbcc WRITEPAGE ({'dbname' | dbid}, fileid, pageid, {offset | 'fieldname'}, length, data [, directORbufferpool])

ALTER DATABASE VendasDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE 
DBCC WRITEPAGE ('VendasDB', 1, 265, 4000, 1, 0x45, 1)
ALTER DATABASE VendasDB SET MULTI_USER WITH NO_WAIT

SELECT * 
FROM VendasDB.dbo.Cliente 
WHERE Nome = 'Jose' -- OK

SELECT * 
FROM VendasDB.dbo.Cliente 
WHERE Nome = 'Carla'-- Erro, cai a conexão

/**************
Msg 824, Level 24, State 2, Line 111
SQL Server detected a logical consistency-based I/O error: incorrect checksum (expected: 0x6a972275; actual: 0x6a974675).
It occurred during a read of page (1:265) in database ID 7 at offset 0x00000000212000 in file 'C:\MSSQL\Data\VendasDB.mdf'.  
Additional messages in the SQL Server error log or operating system error log may provide more detail. 
This is a severe error condition that threatens database integrity and must be corrected immediately. 
Complete a full database consistency check (DBCC CHECKDB). This error can be caused by many factors; 
for more information, see SQL Server Books Online.
**************/

--- TRUNCATE TABLE msdb..suspect_pages
SELECT * 
FROM msdb..suspect_pages

-- Verifica a integridade
DBCC CHECKDB (VendasDB) WITH NO_INFOMSGS;

-- Corrige a inconsistência
ALTER DATABASE VendasDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE
DBCC CHECKDB (VendasDB, REPAIR_ALLOW_DATA_LOSS)
ALTER DATABASE VendasDB SET  MULTI_USER WITH NO_WAIT

SELECT * 
FROM VendasDB.dbo.Cliente


/*********************************************
 Corrompendo Indice
**********************************************/
DBCC IND (VendasDB, 'Cliente', -1)

ALTER DATABASE VendasDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE
DBCC WRITEPAGE ('VendasDB', 1, 312, 4000, 1, 0x45, 1)
ALTER DATABASE VendasDB SET  MULTI_USER WITH NO_WAIT

DBCC CHECKDB (VendasDB) WITH NO_INFOMSGS

ALTER DATABASE VendasDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE
DBCC CHECKDB (VendasDB,REPAIR_ALLOW_DATA_LOSS)
ALTER DATABASE VendasDB SET  MULTI_USER WITH NO_WAIT

SELECT * 
FROM VendasDB.dbo.Cliente

-- Exclui banco
DROP DATABASE If exists VendasDB




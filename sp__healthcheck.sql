CREATE OR ALTER PROCEDURE [sp__healthcheck] AS

SET NOCOUNT ON;

PRINT 'Versão atual da instância SQL Server                                       '
PRINT '---------------------------------------------------------------------------'
PRINT 'Sugestão: Verificar última versão em=https://sqlserverbuilds.blogspot.com/ '
PRINT '                                                                           '

SELECT
	CASE 
		WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion')) LIKE '8%' THEN 'SQL Server 2000'
		WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion')) LIKE '9%' THEN 'SQL Server 2005'
		WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion')) LIKE '10.0%' THEN 'SQL Server 2008'
		WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion')) LIKE '10.5%' THEN 'SQL Server 2008 R2'
		WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion')) LIKE '11%' THEN 'SQL Server 2012'
		WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion')) LIKE '12%' THEN 'SQL Server 2014'
		WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion')) LIKE '13%' THEN 'SQL Server 2016'     
		WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion')) LIKE '14%' THEN 'SQL Server 2017' 
		WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion')) LIKE '15%' THEN 'SQL Server 2019' 
		WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion')) LIKE '16%' THEN 'SQL Server 2022' 
	ELSE 'unknown'
	END AS [SQL Server Version],
	SERVERPROPERTY('ProductLevel') AS [Product Level],
	SERVERPROPERTY('Edition') AS [Product Edition],
	SERVERPROPERTY('ProductVersion') AS [Product Version],
	SERVERPROPERTY('ProductUpdateLevel') AS [Last Update Applied];
	
PRINT 'Configuração do IFI (Instant File Inicialization)                          '
PRINT '---------------------------------------------------------------------------'
PRINT 'Sugestão: Instant File Initialization Enabled=Y                            '
PRINT '                                                                           '

SELECT 
	@@SERVERNAME [Server Name] ,
    service_account [Service Name],
    instant_file_initialization_enabled [Instant File Initialization Enabled]
FROM  sys.dm_server_services;

PRINT 'Configuração do LPM (Lock Page in Memory)                                  '
PRINT '---------------------------------------------------------------------------'
PRINT 'Sugestão: SQL Memory Model=LOCK PAGES                                      '
PRINT '                                                                           '

SELECT 
	@@SERVERNAME [Server Name], 
	sql_memory_model_desc [SQL Memory Model]
FROM sys.dm_os_sys_info;

PRINT 'Configuração do DAC (Dedicated Administrator Connection)                   '
PRINT '---------------------------------------------------------------------------'
PRINT 'Sugestão: Remote Admin Connections=1 (Habilitado)                          '
PRINT '                                                                           '

SELECT 
    name [Configuration Name],
    CASE 
		WHEN value=0 THEN 'Disabled'
		WHEN value=1 THEN 'Enabled'
	END [Value]
FROM 
    sys.configurations
WHERE 
    name = 'remote admin connections';
	
PRINT 'Configuração do memória da instância SQL Server                            '
PRINT '---------------------------------------------------------------------------'
PRINT 'Sugestão: Conceder 75% da memória disponível ao SQL Server                 '
PRINT '                                                                           '

SELECT 
	total_physical_memory_kb/1024 [System Physical Memory (MB)]
FROM sys.dm_os_sys_memory

SELECT
    name [Configuration Name],
    value [Value]
FROM 
    sys.configurations
WHERE 
    name in ('min server memory (MB)','max server memory (MB)');

DECLARE 
	@NUMA_COUNT INT,
	@CPU_COUNT INT,
	@MAX_DEGREE VARCHAR(10),
	@SQLSERVER_VERSION VARCHAR(10)

SELECT @NUMA_COUNT=
	COUNT(DISTINCT memory_node_id)
FROM sys.dm_os_nodes 
WHERE memory_node_id<>64 
AND node_state_desc='ONLINE';

SELECT @CPU_COUNT=
	cpu_count
FROM sys.dm_os_sys_info

SELECT @SQLSERVER_VERSION=
	CASE 
		WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion')) LIKE '8%' THEN '2000'
		WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion')) LIKE '9%' THEN '2005'
		WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion')) LIKE '10%' THEN '2008' 
		WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion')) LIKE '11%' THEN '2012'
		WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion')) LIKE '12%' THEN '2014'
		WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion')) LIKE '13%' THEN '2016'    
		WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion')) LIKE '14%' THEN '2017'
		WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion')) LIKE '15%' THEN '2019'
		WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion')) LIKE '16%' THEN '2022' 
	END

IF ((SELECT cpu_count FROM sys.dm_os_sys_info WHERE @NUMA_COUNT = 1 AND @SQLSERVER_VERSION < 2016) <= 8 )
	SET @MAX_DEGREE = @CPU_COUNT
IF ((SELECT cpu_count FROM sys.dm_os_sys_info WHERE @NUMA_COUNT > 1 AND @SQLSERVER_VERSION < 2016) > 16 )
	SET @MAX_DEGREE = @CPU_COUNT/2
IF ((SELECT cpu_count FROM sys.dm_os_sys_info WHERE @NUMA_COUNT = 1 AND @SQLSERVER_VERSION >= 2016) <= 8 )
	SET @MAX_DEGREE = @CPU_COUNT
IF ((SELECT cpu_count FROM sys.dm_os_sys_info WHERE @NUMA_COUNT > 1 AND @SQLSERVER_VERSION >= 2016) <= 16 )
	SET @MAX_DEGREE = @CPU_COUNT
IF ((SELECT cpu_count FROM sys.dm_os_sys_info WHERE @NUMA_COUNT > 1 AND @SQLSERVER_VERSION >= 2016) > 16 )
	SET @MAX_DEGREE = @CPU_COUNT/2
	
PRINT 'Configuração de paralelismo da instância SQL Server                        '
PRINT '---------------------------------------------------------------------------'
PRINT '1º Sugestão: cost threshold for parallelism=100                            '
PRINT '2º Sugestão: max degree of parallelism='+@MAX_DEGREE+'                     '
PRINT '                                                                           '

SELECT 
	cpu_count [Processor Count]
FROM sys.dm_os_sys_info

SELECT
    name [Configuration Name],
    value [Value]
FROM 
    sys.configurations
WHERE 
    name in ('max degree of parallelism','cost threshold for parallelism');

PRINT 'Status atual do usuáro SA                                                  '
PRINT '---------------------------------------------------------------------------'
PRINT 'Sugestão: Is Disabled=1                                                    '
PRINT '                                                                           '

SELECT 
    name [Username],
    CASE 
		WHEN is_disabled=0 THEN 'No'
		WHEN is_disabled=1 THEN 'Yes'
	END [Is Disabled?]
FROM 
    sys.server_principals
WHERE 
    name = 'sa';	

DECLARE @COMPATIBILITY_LEVEL VARCHAR(10)
SELECT @COMPATIBILITY_LEVEL=
	CASE 
		WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion')) LIKE '8%' THEN '80'
		WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion')) LIKE '9%' THEN '90'
		WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion')) LIKE '10.0%' THEN '100'
		WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion')) LIKE '10.5%' THEN '100'
		WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion')) LIKE '11%' THEN '110'
		WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion')) LIKE '12%' THEN '120'
		WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion')) LIKE '13%' THEN '130'    
		WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion')) LIKE '14%' THEN '140'
		WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion')) LIKE '15%' THEN '150'
		WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion')) LIKE '16%' THEN '160' 
	END

PRINT 'Nível de compatibilidade dos databases                                     '
PRINT '---------------------------------------------------------------------------'
PRINT 'Sugestão: Compatibility Level='+@COMPATIBILITY_LEVEL+'                     '
PRINT '                                                                           '

select 
	name [Database Name], 
	compatibility_level [Compatibility Level]
from sys.databases

PRINT 'Configuração de auto close dos databases                                   '
PRINT '---------------------------------------------------------------------------'
PRINT 'Sugestão: Auto Close=0 (Desabilitado)                                      '
PRINT '                                                                           '

select 
	name [Database Name], 
	CASE 
		WHEN is_auto_close_on=0 THEN 'No'
		WHEN is_auto_close_on=1 THEN 'Yes'
	END [Is Auto Close?]
from sys.databases

PRINT 'Configuração de auto shrink dos databases                                  '
PRINT '---------------------------------------------------------------------------'
PRINT 'Sugestão: Auto Shrink=0 (Desabilitado)                                     '
PRINT '                                                                           '

select 
	name [Database Name], 
	CASE 
		WHEN is_auto_shrink_on=0 THEN 'No'
		WHEN is_auto_shrink_on=1 THEN 'Yes'
	END [Is Auto Shrink?]
from sys.databases

PRINT 'Configuração de verificação de páginas dos databases                       '
PRINT '---------------------------------------------------------------------------'
PRINT 'Sugestão: Page Verify Option=CHECKSUM                                      '
PRINT '                                                                           '

select 
	name [Database Name], 
	page_verify_option_desc [Page Verify Option] 
from sys.databases

PRINT 'Detalhamento da última checagem de integridade dos databases               '
PRINT '---------------------------------------------------------------------------'
PRINT '                                                                           '

CREATE TABLE #last_checkdb (
    DatabaseName NVARCHAR(128),
    LastCheckDBTime DATETIME
);
DECLARE @SqlCommand NVARCHAR(MAX);
SET @SqlCommand = '
    BEGIN
		USE [?] INSERT INTO #last_checkdb (DatabaseName, LastCheckDBTime) SELECT DB_NAME() ''Database'', CONVERT(VARCHAR,DATABASEPROPERTYEX(DB_NAME(),''LastGoodCheckDbTime'')) ''LastGoodCheckDb''
    END
    ';
EXEC sp_MSforeachdb @command1 = @SqlCommand;
SELECT 
	DatabaseName [Database Name],
	LastCheckDBTime [Last CheckDB Time]
FROM #last_checkdb;
DROP TABLE #last_checkdb;

PRINT 'Detalhamento dos backups dos databases                                     '
PRINT '---------------------------------------------------------------------------'
PRINT '                                                                           '
  
SELECT 
	d.name [Database Name],
	d.recovery_model_desc [Recovery Model],
	MAX(CASE WHEN [type] = 'D' THEN b.backup_finish_date ELSE NULL END) [Last Full Backup],
	MAX(CASE WHEN [type] = 'I' THEN b.backup_finish_date ELSE NULL END) [Last Differential Backup],
	MAX(CASE WHEN [type] = 'L' THEN b.backup_finish_date ELSE NULL END) [Last Log Backup]
FROM sys.databases d
LEFT OUTER JOIN msdb.dbo.backupset b 
	ON b.database_name = d.name
WHERE 
	d.name <> 'tempdb'
	AND d.state_desc = 'ONLINE'
GROUP BY 
	d.name, 
	d.recovery_model_desc, 
	d.log_reuse_wait_desc
ORDER BY 
	d.recovery_model_desc, 
	d.name  

PRINT 'Localização dos arquivos de dados dos databases de sistema                 '
PRINT '---------------------------------------------------------------------------'
PRINT 'Sugestão: Armazenar fora do disco C:                                       '
PRINT '                                                                           '

SELECT 
    DB_NAME(database_id) [Database Name],
    name [File Name],
    physical_name [File Path]
FROM 
    sys.master_files
WHERE
	DB_NAME(database_id) IN ('master','model','msdb','tempdb')


PRINT 'Detalhamento do database temporário                                        '
PRINT '---------------------------------------------------------------------------'
PRINT 'Sugestão: Equalizar a quantidade de arquivos com a quantidade de CPU       '
PRINT 'OBS: Caso o servidor tenha mais de 8 CPU, usar apenas 8 arquivos de temp   '
PRINT '                                                                           '

SELECT 
	cpu_count [Processor Count]
FROM sys.dm_os_sys_info

SELECT 
    DB_NAME(database_id) [Database Name],
    name [File Name],
    physical_name [File Path],
    CASE 
        WHEN is_percent_growth = 0 THEN CONCAT((growth/64)/2,' MB')
        WHEN is_percent_growth = 1 THEN CONCAT(growth,' %')
        ELSE 'Unknown'
    END [Growth],
	CASE 
        WHEN max_size = -1 THEN 'Unlimited'
        WHEN max_size = 268435456 THEN '2 TB'
        WHEN max_size = 0 THEN 'Limited'
		ELSE CONCAT((max_size/64)/2,' MB')
    END [Max Size]
FROM 
    sys.master_files
WHERE
	DB_NAME(database_id) = 'tempdb'
	AND type_desc = 'ROWS'
	
PRINT 'Detalhamento dos arquivos de dados dos databases                           '
PRINT '---------------------------------------------------------------------------'
PRINT 'Sugestão: Crescimento a cada 128MB                                         '
PRINT '                                                                           '

SELECT 
    DB_NAME(database_id) [Database Name],
    name [File Name],
    physical_name [File Path],
    CASE 
        WHEN is_percent_growth = 0 THEN CONCAT((growth/64)/2,' MB')
        WHEN is_percent_growth = 1 THEN CONCAT(growth,' %')
        ELSE 'Unknown'
    END [Growth],
	CASE 
        WHEN max_size = -1 THEN 'Unlimited'
        WHEN max_size = 268435456 THEN '2 TB'
        WHEN max_size = 0 THEN 'Limited'
		ELSE CONCAT((max_size/64)/2,' MB')
    END [Max Size]
FROM 
    sys.master_files

PRINT 'Latência de escrita e leitura dos discos de dados e logs                   '
PRINT '---------------------------------------------------------------------------'
PRINT '                                                                           '

SELECT
	CASE 
		WHEN num_of_reads = 0 THEN 0 
		ELSE (io_stall_read_ms / num_of_reads) 
	END [Read Latency],
	CASE
		WHEN num_of_writes = 0 THEN 0 
		ELSE (io_stall_write_ms / num_of_writes) 
	END [Write Latency],
	CASE 
		WHEN (num_of_reads = 0 AND num_of_writes = 0) THEN 0 
		ELSE (io_stall/(num_of_reads + num_of_writes)) 
	END [Latency],
	CASE 
		WHEN (num_of_reads = 0 AND num_of_writes = 0) THEN 'N/A' 
		ELSE 
			CASE WHEN (io_stall / (num_of_reads + num_of_writes)) < 2 THEN 'Excellent'
				WHEN (io_stall / (num_of_reads + num_of_writes)) < 6 THEN 'Very good'
				WHEN (io_stall / (num_of_reads + num_of_writes)) < 11 THEN 'Good'
				WHEN (io_stall / (num_of_reads + num_of_writes)) < 21 THEN 'Poor'
				WHEN (io_stall / (num_of_reads + num_of_writes)) < 101 THEN 'Bad'
				WHEN (io_stall / (num_of_reads + num_of_writes)) < 501 THEN 'Very Bad!'
				ELSE 'Very Bad!!'
		END 
	END [Latency Desc], 
	LEFT (mf.physical_name, 2) [Drive],
	DB_NAME (vfs.database_id) [Database Name],
	mf.physical_name [Physical Name]
FROM
	sys.dm_io_virtual_file_stats (NULL,NULL) AS vfs
	JOIN sys.master_files AS mf
		ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id
ORDER BY [Latency] DESC

SET NOCOUNT OFF;
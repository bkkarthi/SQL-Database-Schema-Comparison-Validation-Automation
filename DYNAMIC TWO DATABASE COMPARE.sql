
DROP  TABLE ##t1
DROP  TABLE ##t2
DROP  TABLE ##tt1
DROP  TABLE ##tt2
DROP TABLE ##temp1
DROP TABLE ##temp2
DROP TABLE ##T23
DROP TABLE ##T24
DROP TABLE ##TMP3
--DROP TABLE ##temp2

DECLARE @DATABASE1 VARCHAR(60)='Google_APP_BETA'
DECLARE @DATABASE2 VARCHAR(60)='Google_CONSOLE_BETA'
DECLARE @SQL NVARCHAR(MAX)

SET @SQL='SELECT 
    t.name AS TableName,
    c.name AS ColumnName,
    ty.name AS DataType,
    c.max_length AS MaxLength,
	c.precision as precision ,
	c.scale as scale
INTO ##t1 FROM '+ @DATABASE1 +'.sys.tables t
INNER JOIN '+ @DATABASE1 +'.sys.columns c ON t.object_id = c.object_id
INNER JOIN '+ @DATABASE1 +'.sys.types ty ON c.user_type_id = ty.user_type_id
WHERE t.type = ''U''  
ORDER BY t.name, c.column_id;'
EXEC (@SQL)

SET @SQL='SELECT 
    t.name AS TableName,
    c.name AS ColumnName,
    ty.name AS DataType,
    c.max_length AS MaxLength,
	c.precision as precision ,
	c.scale as scale
INTO ##t2 FROM '+ @DATABASE2 +'.sys.tables t
INNER JOIN '+ @DATABASE2 +'.sys.columns c ON t.object_id = c.object_id
INNER JOIN '+ @DATABASE2 +'.sys.types ty ON c.user_type_id = ty.user_type_id
WHERE t.type = ''U''  
ORDER BY t.name, c.column_id;'
EXEC (@SQL)

--THE table not in Google_APP_BETA
SET @SQL='SELECT NAME AS [TABLE NOT IN '+@DATABASE1+']  into ##tt1  FROM '+@DATABASE2+'.sys.tables AS T1 WHERE NOT EXISTS (SELECT NAME FROM '+ @DATABASE1 +'.sys.tables AS T2  WHERE T1.NAME=T2.NAME )
AND name not like ''%20%'' and name not like ''%temp%''and name not like ''%bkp%'''
EXEC (@SQL)

--THE table not in Google_CONSOLE_BETA
SET @SQL='SELECT NAME AS [TABLE NOT IN '+@DATABASE2+'] into ##tt2 FROM  '+@DATABASE1+'.sys.tables AS T1 WHERE NOT EXISTS (SELECT NAME FROM '+@DATABASE2+'.sys.tables AS T2  WHERE T1.NAME=T2.NAME )
AND name not like ''%20%'' and name not like ''%temp%''and name not like ''%bkp%'' and name not like ''test%'' and len(name)>2 and name not like ''%test'''
EXEC (@SQL)

--SELECT * FROM #tt2
SET @SQL=';WITH '+@DATABASE2+' AS (
    SELECT [TABLE NOT IN '+@DATABASE1+'], 
           ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM ##tt1
),
'+@DATABASE1+' AS (
    SELECT [TABLE NOT IN '+@DATABASE2+'],
           ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM ##tt2
)
SELECT 
    c.[TABLE NOT IN '+@DATABASE1+'],
    a.[TABLE NOT IN '+@DATABASE2+']
FROM '+@DATABASE2+' c
FULL OUTER JOIN  '+@DATABASE1+' a ON c.rn = a.rn;'

EXEC (@SQL)


--the column not in Google_CONSOLE_BETA
SET @SQL='SELECT DISTINCT '''+@DATABASE1+''' as name, T1.TABLENAME,T1.COLUMNNAME,T1.DataType,T1.MaxLength,t1.precision,t1.scale  into ##temp1 FROM ##T1 AS T1 
INNER JOIN ##T2 AS T2 ON T1.TABLENAME = T2.TABLENAME WHERE 
NOT EXISTS (SELECT  T3.TABLENAME,T3.COLUMNNAME FROM ##T2 AS T3 WHERE T1.TABLENAME = T3.TABLENAME 
AND T1.COLUMNNAME = T3.COLUMNNAME)'
--select * from #TEMP1
EXEC (@SQL)

SET @SQL = '
SELECT *,
       ''ALTER TABLE '' + TABLENAME + 
       '' ADD '' + COLUMNNAME + 
       '' '' + DataType + 
       CASE 
           WHEN DataType = ''varchar'' OR DataType = ''Nvarchar'' OR DataType = ''Nchar'' OR DataType = ''char''  THEN ''('' + 
                CASE WHEN MaxLength = ''-1'' THEN ''MAX'' 
                     ELSE CONVERT(VARCHAR(20), MaxLength)
                END + '')''
		  WHEN DATATYPE=''NUMERIC'' OR DATATYPE=''FLOAT'' OR DATATYPE=''DECIMAL'' 
		  THEN ''(''+ CONVERT(VARCHAR(20),PRECISION) +'',''+CONVERT(VARCHAR(20),SCALE)+'')''
           ELSE ''''
       END AS [ALTER IN '+@DATABASE2+']
INTO ##T23 
FROM ##temp1'
EXEC (@SQL)


--the column not in Google_APP_BETA
SET @SQL='SELECT DISTINCT '''+@DATABASE2+''' as name,T1.TABLENAME,T1.COLUMNNAME,T1.DataType,T1.MaxLength,t1.precision,t1.scale  INTO ##TEMP2 FROM ##T2 AS T1 
INNER JOIN ##T1 AS T2 ON T1.TABLENAME = T2.TABLENAME WHERE 
NOT EXISTS (SELECT T3.TABLENAME,T3.COLUMNNAME FROM ##T1 AS T3 WHERE T1.TABLENAME = T3.TABLENAME 
AND T1.COLUMNNAME = T3.COLUMNNAME) '
--select * from #TEMP2
EXEC (@SQL)

SET @SQL='SELECT *
,''ALER TABLE ''+TABLENAME+'' ADD ''+ COLUMNNAME+'' ''+DataType+CASE 
           WHEN DataType = ''varchar'' OR DataType = ''Nvarchar'' OR DataType = ''Nchar'' OR DataType = ''char'' THEN ''('' + 
                CASE WHEN MaxLength = ''-1'' THEN ''MAX'' 
                     ELSE CONVERT(VARCHAR(20), MaxLength)
                END + '')''
		  WHEN DATATYPE=''NUMERIC'' OR DATATYPE=''FLOAT'' OR DATATYPE=''DECIMAL'' 
		  THEN ''(''+ CONVERT(VARCHAR(20),PRECISION) +'',''+CONVERT(VARCHAR(20),SCALE)+'')''
           ELSE ''''
       END  AS [ALTER IN '+@DATABASE1+'] INTO ##T24
FROM ##TEMP2'
EXEC (@SQL)

--mismatching datatype  
SET @SQL = '
SELECT ''' + @DATABASE1 + ''' AS T1_DATABASE_NAME,
    t1.TABLENAME AS T1_TABLENAME,
    t1.COLUMNNAME AS T1_COLUMNNAME,
    t1.DATATYPE AS T1_DATATYPE,
    t1.[MaxLength] AS [T1_MaxLength],
	t1.precision as t1_precision,
	t1.scale as t1_scale,
    ''' + @DATABASE2 + ''' AS T2_DATABASE_NAME,
    t2.TABLENAME AS T2_TABLENAME,
    t2.COLUMNNAME AS T2_COLUMNNAME,
    t2.DATATYPE AS T2_DATATYPE,
    t2.[MaxLength] AS T2_MaxLength,
	t2.precision as t2_precision,
	t2.scale as t2_scale
FROM ##T1 AS t1 
INNER JOIN ##T2 AS t2 ON t1.TABLENAME = t2.TABLENAME AND t1.COLUMNNAME = t2.COLUMNNAME
WHERE t1.DATATYPE != t2.DATATYPE OR t1.[MaxLength] != t2.[MaxLength]
UNION ALL 
SELECT *, ''' + @DATABASE2 + ''', TABLENAME, '''', '''', '''','''','''' FROM ##TEMP1
UNION ALL
SELECT ''' + @DATABASE1 + ''', TABLENAME, '''', '''', '''','''','''', * FROM ##TEMP2'
EXEC (@SQL)

SET @SQL = ';
WITH CTE_DB2 AS (
    SELECT [ALTER IN ' + @DATABASE2 + '], 
           ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM ##T23
),
CTE_DB1 AS (
    SELECT [ALTER IN ' + @DATABASE1 + '],
           ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM ##T24
)
SELECT 
    a.[ALTER IN ' + @DATABASE1 + '],
    c.[ALTER IN ' + @DATABASE2 + ']    
FROM CTE_DB2 c
FULL OUTER JOIN CTE_DB1 a ON c.rn = a.rn;'
EXEC (@SQL)


--mismatching  size 
SET @SQL='SELECT ''' + @DATABASE1 + '''  T1_NAME,
t1.TABLENAME AS T1_TABLENAME,t1.COLUMNNAME AS T1_COLUMNNAME,t1.DATATYPE AS T1_DATATYPE,t1.[MaxLength] AS [T1_MaxLength],
''' + @DATABASE2 + ''' NAME,
t2.TABLENAME,t2.COLUMNNAME,t2.DATATYPE,t2.[MaxLength]
INTO ##TMP3 FROM ##T1 AS t1 INNER JOIN ##T2 AS t2 ON t1.TABLENAME=t2.TABLENAME AND t1.COLUMNNAME=t2.COLUMNNAME AND t1.DATATYPE=t2.DATATYPE
WHERE t1.[MaxLength]!=t2.[MaxLength]'
EXEC (@SQL)

--select * from ##TMP3
----ALTER mismatching size
SET @SQL = 'SELECT ''ALTER TABLE '' + TABLENAME + '' ALTER COLUMN '' + COLUMNNAME + '' '' + DataType + ''('' + 
    CASE WHEN [T1_MaxLength] = ''-1'' THEN ''MAX'' 
    ELSE CAST([T1_MaxLength] AS VARCHAR(20)) 
    END + '')'' AS [ALTER IN ' + @DATABASE2 + ' FOR MISMATCHING SIZE] 
FROM ##TMP3'
EXEC (@SQL)



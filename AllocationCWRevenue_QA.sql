--Declare variable for testing
IF OBJECT_ID('tempdb..#tableVar') IS NOT NULL
BEGIN
DROP TABLE #tableVar
END
GO

DECLARE @FiscalYearPeriod DATE;
DECLARE @FiscalYearPeriodMA VARCHAR(7);
SET @FiscalYearPeriod = '2023-02-01';
SET @FiscalYearPeriodMA = '2023002';

SELECT @FiscalYearPeriod AS FiscalYearPeriodDt,
@FiscalYearPeriodMA AS FiscalYearPeriodMA
INTO #tableVar



--STEP 1: Get total CarWash Revenue 
IF OBJECT_ID('tempdb..#table1') IS NOT NULL
BEGIN
DROP TABLE #table1
END
GO

SELECT CONVERT(date, (RIGHT([FiscalYearPeriod],2)+'/01/'+LEFT([FiscalYearPeriod],4))) AS FiscalYearPeriod	
,'Alloc-CWRevenue-'+[G/LAccount] AS Account
,Material
,SUM([AmountInFreelyDefinedCurrency4]*-1) AS Amount
INTO #table1
FROM [STG].[ZCCVMA3B] t1
 JOIN [SPR].[vwProfitCenter] t2
ON t1.[ProfitCenter] = t2.[PROFIT_CTR]
JOIN #tableVar t 
	ON t1.[FiscalYearPeriod] = t.FiscalYearPeriodMA --FOR TESTING ONLY
WHERE t2.[PCA_HIEND] In ('PM202211', 'PM202212', 'PM202213', 'PM202221') 
AND [G/LAccount] IN ('0041100010', '0041177080')  
AND [PostingDate] BETWEEN [__activation_datetime] AND [__deactivation_datetime]
GROUP BY [FiscalYearPeriod]
,[G/LAccount]
,Material


--STEP 2: Get Outlet Car Wash Ratio By FiscalYearPeriod By Material 
IF OBJECT_ID('tempdb..#table2') IS NOT NULL
BEGIN
DROP TABLE #table2
END
GO

SELECT CASE WHEN LEN(site_id) = 1 THEN ('00000'+ CONVERT(VARCHAR,site_id)) 
			WHEN LEN(site_id) = 2 THEN ('0000'+ CONVERT(VARCHAR,site_id)) 
			WHEN LEN(site_id) = 3 THEN ('000'+ CONVERT(VARCHAR,site_id)) 
			WHEN LEN(site_id) = 4 THEN ('00'+ CONVERT(VARCHAR,site_id)) 
			WHEN LEN(site_id) = 5 THEN ('0'+ CONVERT(VARCHAR,site_id)) 
			ELSE CONVERT(VARCHAR,site_id) END  AS Outlet
,CONVERT(DATE, (CONVERT(VARCHAR, MONTH([serverUtcTime])) + '/01/'+ CONVERT(VARCHAR, YEAR([serverUtcTime])))) AS [FiscalYearPeriod]
,COUNT(givenwash) AS CWCount
INTO #table2
FROM ccm.fulfills t1
JOIN #tableVar t 
	ON CONVERT(DATE,t1.[serverUtcTime]) = t.FiscalYearPeriodDt --FOR TESTING ONLY
WHERE givenwash <> 9 -- given wash code = 'Vacuum'
GROUP BY site_id
,CONVERT(DATE, (CONVERT(VARCHAR, MONTH([serverUtcTime])) + '/01/'+ CONVERT(VARCHAR, YEAR([serverUtcTime])))) 


--STEP 3: Get total count of CarWash by fiscal year period for total C-Stores
IF OBJECT_ID('tempdb..#table3') IS NOT NULL
BEGIN
DROP TABLE #table3
END
GO

SELECT FiscalYearPeriod
,SUM(CWCount) AS TotalCWCount
INTO #table3
FROM #table2 t1
JOIN #tableVar t 
	ON t1.FiscalYearPeriod = t.FiscalYearPeriodDt --FOR TESTING ONLY
GROUP BY FiscalYearPeriod


--STEP 4: Get Outlet Car Wash Ratio By FiscalYearPeriod By Material 
IF OBJECT_ID('tempdb..#table4') IS NOT NULL
BEGIN
DROP TABLE #table4
END
GO

SELECT t1.Outlet
,t1.[FiscalYearPeriod]
,CONVERT(DECIMAL(38,15),t1.CWCount) / t2.TotalCWCount AS CWRatio
INTO #table4
FROM #table2 t1
JOIN #table3 t2 
	ON t1.FiscalYearPeriod = t2.FiscalYearPeriod


--STEP 5: get Outlet Car Wash Revenue by FiscalYearPeriod By Material 
IF OBJECT_ID('tempdb..#table5') IS NOT NULL
BEGIN
DROP TABLE #table5
END
GO

SELECT t1.FiscalYearPeriod
	   ,t1.Outlet
	   ,t2.Account
	   ,t2.Material
	   ,t1.CWRatio * t2.Amount AS Amount
INTO #table5
FROM #table4 t1
JOIN #table1 t2 ON t1.FiscalYearPeriod = t2.FiscalYearPeriod


SELECT *
FROM #table5
ORDER BY Outlet, Account

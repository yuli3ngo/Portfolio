--Declare variable for testing
IF OBJECT_ID('tempdb..#tableVar') IS NOT NULL
BEGIN
DROP TABLE #tableVar
END
GO

DECLARE @FiscalYearPeriodMA VARCHAR(7);
SET @FiscalYearPeriodMA = '2022007';

SELECT @FiscalYearPeriodMA AS FiscalYearPeriodMA
INTO #tableVar


--STEP 0: Get unique journal ledger records from the Margin Analysis table
IF OBJECT_ID('tempdb..#table0') IS NOT NULL
BEGIN
DROP TABLE #table0
END
GO

SELECT CONVERT(DATE, (CONVERT(VARCHAR, MONTH([PostingDate])) + '/01/'+ CONVERT(VARCHAR, YEAR([PostingDate])))) AS FiscalYearPeriod	-- Convert date from YYYY0MM to MM/01/YYYY
,RIGHT(t1.[ProfitCenter],6) AS Outlet
,[Industry]
,[PostingDate]
,[G/LAccount] 
,[Ledger]
,[LedgerDocumentNumber]
,[DocumentLine]
,[ProductHierarchyLevel2]
,[Material] 
,[TimeStamp]
,[AmountInFreelyDefinedCurrency4]*-1 AS Amount							
,CASE WHEN ([ItemIsReversingAnotherItem] = 'X' OR [ItemIsReversed] = 'X')  THEN [QuantityACDOCAMSL]	 -- Reversal logic to correct incorrect quantiy ammount in this field, when the GL item is being reversed 
		ELSE [QuantityL15NotACDOCA] END *-1 AS Quantity -- L15 = fuel quantity in Canadian Litre
INTO #table0
FROM [STG].[ZCCVMA3B] t1 --This view is coming from ACDOCA in SAP S4 (Suncor journal entry)
JOIN [SPR].[vwProfitCenter] t2 -- This is a snapshot table of profit centre area
	ON t1.[ProfitCenter] = t2.[PROFIT_CTR]
JOIN #tableVar t 
	ON t1.[FiscalYearPeriod] = t.FiscalYearPeriodMA --FOR TESTING ONLY
WHERE t2.[PCA_HIEND] In ('PM202222', 'PM202223', 'PM202232', 'PM202233', 'PM202242','PM202243') -- Profit centre area for retail outlet (see below)	   
AND t1.[Industry] IN  ('1102', '1105', '1106', '0007', '2104', '2112', '1110', '2113', '1108') -- Industry is class of trade for retail
AND [PostingDate] BETWEEN [__activation_datetime] AND [__deactivation_datetime]

/*
Insert defintions from above
*/

--STEP 00: Get the last calendar date of the fiscal year period (EOM) 
IF OBJECT_ID('tempdb..#table00') IS NOT NULL
BEGIN
DROP TABLE #table00
END
GO

DECLARE @FiscalYearPeriod DATE
SET @FiscalYearPeriod = (SELECT DISTINCT FiscalYearPeriod FROM #TABLE0)
SELECT @FiscalYearPeriod AS FiscalYearStartDate
,EOMONTH(@FiscalYearPeriod) AS FiscalYearEndDate
INTO #table00


--STEP 1: Get total fuel volumes by fiscal year period for total DL (dealers) 
IF OBJECT_ID('tempdb..#table1') IS NOT NULL
BEGIN
DROP TABLE #table1
END
GO

SELECT [FiscalYearPeriod] -- now in the format of MM/01/YYYY
	  ,SUM(Quantity) AS Quantity -- Fuel volume in litres
INTO #table1
FROM #table0 
WHERE [G/LAccount] = '0040102000' -- GL Account for Fuel Transaction
GROUP BY [FiscalYearPeriod]


--STEP 2: Get total fuel volumes by fiscal year period by COT (industry) 
IF OBJECT_ID('tempdb..#table2') IS NOT NULL
BEGIN
DROP TABLE #table2
END
GO

SELECT [FiscalYearPeriod]
	  ,Industry
	  ,SUM(Quantity) AS QuantityByCOT
INTO #table2
FROM #Table0 
WHERE [G/LAccount] = '0040102000'
GROUP BY [FiscalYearPeriod]
 ,Industry


--STEP 3: Get total Card Fees Recoveries by GL Account
IF OBJECT_ID('tempdb..#table3') IS NOT NULL
BEGIN
DROP TABLE #table3
END
GO

SELECT CONVERT(DATE, (CONVERT(VARCHAR, MONTH([PostingDate])) + '/01/'+ CONVERT(VARCHAR, YEAR([PostingDate])))) AS FiscalYearPeriod	
,'Alloc-CardRecoveries'+[G/LAccount] AS Account
,SUM([AmountInFreelyDefinedCurrency4]*-1) AS Amount
INTO #table3
FROM [STG].[ZCCVMA3B] t1
JOIN [SPR].[vwProfitCenter] t2
	ON t1.[ProfitCenter] = t2.[PROFIT_CTR]
JOIN #tableVar t 
	ON t1.[FiscalYearPeriod] = t.FiscalYearPeriodMA --FOR TESTING ONLY
WHERE t2.[PCA_HIEND] In ('PM202231') 
AND [G/LAccount] IN ('0063630020', '0063630530', '0063630540', '0063630520', '0063630510')  
AND [PostingDate] BETWEEN [__activation_datetime] AND [__deactivation_datetime]
GROUP BY CONVERT(DATE, (CONVERT(VARCHAR, MONTH([PostingDate])) + '/01/'+ CONVERT(VARCHAR, YEAR([PostingDate]))))
,[G/LAccount]


--STEP 4a: Calculate fuel volume ratio for each DL COT: step2 / step1 
IF OBJECT_ID('tempdb..#table4') IS NOT NULL
BEGIN
DROP TABLE #table4
END
GO

SELECT t1.[FiscalYearPeriod]
	  ,t1.Industry
	  ,CONVERT(DECIMAL(38,15), t1.QuantityByCOT)/t2.Quantity AS COTFuelRatio
INTO #table4
FROM #table2 t1
JOIN #table1 t2
ON t1.[FiscalYearPeriod] = t2.[FiscalYearPeriod]


--STEP 4b: Calculate Card Fees Recoveries amount for each dealers' COT: step3 * step4a
IF OBJECT_ID('tempdb..#table5') IS NOT NULL
BEGIN
DROP TABLE #table5
END
GO

SELECT t1.[FiscalYearPeriod]
	   ,t1.[Industry]
	   ,t2.Account
       ,CONVERT(DECIMAL(38,15),t1.[COTFuelRatio]) * t2.[Amount] AS COTCardRecoveries
INTO #table5
FROM #table4 t1
JOIN #table3 t2
ON t1.[FiscalYearPeriod] = t2.[FiscalYearPeriod]


--STEP 5a:get fuel volume for each DL outlet excl. Rtl Equity Prtnrship 
IF OBJECT_ID('tempdb..#table6') IS NOT NULL
BEGIN
DROP TABLE #table6
END
GO

SELECT [FiscalYearPeriod]
	   ,[Industry]
	   ,[Outlet]
	   ,SUM(Quantity) AS QuantityByOutlet
INTO #table6
FROM #Table0
WHERE [G/LAccount] = '0040102000'
AND [Industry] <> '1106'
GROUP BY [FiscalYearPeriod]
	     ,[Industry]
	     ,[Outlet]


--STEP 5b.1: Get fuel volume ratio for each DL outlet excl. Rtl Equity Prtnrship: step5a / step2
IF OBJECT_ID('tempdb..#table7') IS NOT NULL
BEGIN
DROP TABLE #table7
END
GO

SELECT t1.[FiscalYearPeriod]
	  ,t1.[Industry]
	  ,t1.[Outlet]
	  ,CONVERT(DECIMAL(38,15),t1.[QuantityByOutlet])/t2.QuantityByCOT AS OutletFuelRatio
INTO #table7
FROM #table6 t1
JOIN #table2 t2
ON t1.[FiscalYearPeriod] = t2.[FiscalYearPeriod]
AND t1.[Industry] = t2.[Industry]


--STEP 5b.2: Calculate Card Fees Recoveries amount for each DL outlet excl. Rtl Equity Prtnrship: step5b * step4b
IF OBJECT_ID('tempdb..#table8') IS NOT NULL
BEGIN
DROP TABLE #table8
END
GO

SELECT t1.[FiscalYearPeriod] 
	  ,t2.Account
	  ,t1.[Outlet]
	  ,CONVERT(DECIMAL(38,15),t1.OutletFuelRatio) * t2.[COTCardRecoveries] AS Amount
INTO #table8
FROM #table7 t1
JOIN #table5 t2
ON t1.[FiscalYearPeriod] = t2.[FiscalYearPeriod]
AND t1.[Industry] = t2.[Industry]


--STEP 6a.1: Get Retail Partnership Outlet Information from [SPR].[vwDimSite]
-- ** Current error: SAP Hana B/W only contains 43 retail partnership sites, which is not the correct # because SAP only contains sites retail partnership sites with fuel quantity 
-- Cadeko site partnerships do not have site level volumes, only aggregate for the partnership which are assigned to 1 site.  
-- To get correct total retail partnership sites, we will use dim_site table where the criteria used is COT is shown below
IF OBJECT_ID('tempdb..#table9') IS NOT NULL
BEGIN
DROP TABLE #table9
END
GO

SELECT *
INTO #table9
FROM [SPR].[vwDimSite],  #table00
WHERE [Class of Trade] ='1106'
AND [Status Desc] = 'ACTIVE DL'
AND [Sales Group] = 186
AND [Street] NOT LIKE '%455 des Entrepreneurs%'
AND FiscalYearEndDate BETWEEN [Effective Start Date] AND [Effective End Date]


--STEP 6a.2: Get Number of Retail Partnership Outlet Count
-- This # will be used as a divider for COT retail parntership additive ammount
IF OBJECT_ID('tempdb..#table10') IS NOT NULL
BEGIN
DROP TABLE #table10
END
GO

SELECT COUNT([Outlet No]) AS RtlPartnershipCt
INTO #table10
FROM #table9


--STEP 6b.1: Calculate Card Fees Recoveries amount per outlet under COT Rtl Equity Prtnrship
-- Calculate each outlets additive ammount by dividing additive ammount from step 10 with # of outlets from step 15
-- ############# question: why for retail partnership are we not using fuel quantity, but # of sites?
-- ############# answer: Retail partnership pickup the fuel from terminal and distributes to their sites without Suncor knowing the volume that will be delivered to each site
-- ############# Because they pickup, we don't know which site receive it
IF OBJECT_ID('tempdb..#table11') IS NOT NULL
BEGIN
DROP TABLE #table11
END
GO

SELECT t2.[FiscalYearPeriod]
	  ,t2.[Account]
	  ,t1.RtlPartnershipCt
	  ,CONVERT(DECIMAL(38,15), t2.COTCardRecoveries) /t1.RtlPartnershipCt AS RtlPartnerCardRecoveries
INTO #table11
FROM #table10 t1, #table5 t2
WHERE t2.[Industry] = 1106


--STEP 6b.2: Assign Card Fees Recoveries amount to each outlet under COT Rtl Equity Prtnrship
-- Assign outlet additive ammount from step 12 to each retail partnership outlet
IF OBJECT_ID('tempdb..#table12') IS NOT NULL
BEGIN
DROP TABLE #table12
END
GO

SELECT t1.[FiscalYearPeriod] --[DimDateSitePerformanceSID]
	  ,t1.Account --[DimAccountSitePerformanceSID]
	  ,t2.[Outlet No] AS Outlet--[DimSitesPerformanceSID]
	  ,t1.RtlPartnerCardRecoveries AS Amount
INTO #table12
FROM #table11 t1, #table9 t2


Select [FiscalYearPeriod] --[DimDateSitePerformanceSID]
	  ,Account --[DimAccountSitePerformanceSID]
	  ,Outlet --[DimSitesPerformanceSID]
	  ,Amount
From #table8
UNION
Select [FiscalYearPeriod] --[DimDateSitePerformanceSID]
	  ,Account --[DimAccountSitePerformanceSID]
	  ,Outlet --[DimSitesPerformanceSID]
	  ,Amount
From #table12
order by [FiscalYearPeriod], [Outlet], Account

SELECT *
FROM #table3

SELECT *
FROM #table5

SELECT *
FROM #table8

SELECT *
FROM #table12
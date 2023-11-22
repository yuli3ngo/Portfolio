--STEP 0: Get unique journal ledger records from the Margin Analysis table
IF OBJECT_ID('tempdb..#table0') IS NOT NULL
BEGIN
DROP TABLE #table0
END
GO

SELECT CONVERT(date, (RIGHT([FiscalYearPeriod],2)+'/01/'+LEFT([FiscalYearPeriod],4))) AS FiscalYearPeriod	-- Convert date from YYYY0MM to MM/01/YYYY
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
WHERE t2.[PCA_HIEND] In ('PM202222', 'PM202223', 'PM202232', 'PM202233', 'PM202242','PM202243') -- Profit centre area for retail outlet (see below)	   
AND t1.[Industry] IN  ('2107', '2108', '1102', '1105', '1106', '0007', '2104', '2112', '1110', '2113', '1108') -- Industry is class of trade for retail
AND t1.[ProductHierarchyLevel2] IN ('3001031010', '3001031020', '3001031030', '3001031040')  -- Which are '31010', '31020', '31030', '31040' in Margin Analysis GUI
AND t1.[FiscalYearPeriod] = '2023001' --- Sample date for testing only

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


--STEP 1: Get Retail total fuel volumes by fiscal year period by product and material for all sites
IF OBJECT_ID('tempdb..#table1') IS NOT NULL
BEGIN
DROP TABLE #table1
END
GO

SELECT [FiscalYearPeriod] -- now in the format of MM/01/YYYY
	  ,[ProductHierarchyLevel2] -- Product Heirarchy code standard of fuel grade in SAP S/4 (Ben will send table)
	  ,[Material] -- Material code standard in SAP S/4 (ask Ben)
	  ,SUM(Quantity) AS Quantity -- Fuel volume in litres
INTO #table1
FROM #table0 
WHERE [G/LAccount] = '0040102000' -- GL Account for Fuel Transaction
GROUP BY [FiscalYearPeriod]
	  ,[ProductHierarchyLevel2]
	  ,[Material]


--STEP 2a-2d: Multiply total fuel by product with 2 for super & premium, 1.5 for mid-grade
-- Multiplier in the 2, 1.5, 1 are refering to the cost of chemical additives used to acheive fuel octane grade
IF OBJECT_ID('tempdb..#table2') IS NOT NULL
BEGIN
DROP TABLE #table2
END
GO

SELECT [FiscalYearPeriod]
	  ,[ProductHierarchyLevel2]
	  ,SUM(CASE WHEN [ProductHierarchyLevel2] IN ('3001031040') THEN (Quantity*1.67) -- 40 = Ultra
	            WHEN [ProductHierarchyLevel2] IN ('3001031030') THEN (Quantity*1.55) -- 30 = Super clean/Premium
			    WHEN [ProductHierarchyLevel2] = '3001031020' THEN (Quantity*1.27) -- 20 = Mid-grade fuel
			    ELSE Quantity END) AS MultipliedQuantity -- 3001031010 = Regular grade no multiplier
INTO #table2
FROM #table1 
GROUP BY [FiscalYearPeriod]
	  ,[ProductHierarchyLevel2]


--STEP 2e-2i: Get Retail Product Fuel Ratio
-- Multiple fuel quantity by product, divided by sum of fuel quantity for all product to get the ratio by product.

IF OBJECT_ID('tempdb..#table3') IS NOT NULL
BEGIN
DROP TABLE #table3
END
GO

WITH TotalMultipliedQuantity AS
(
SELECT [FiscalYearPeriod]
	  ,SUM(MultipliedQuantity) AS totMultipliedQuantity
FROM #table2 
GROUP BY [FiscalYearPeriod]
)

SELECT t1.[FiscalYearPeriod]
	  ,t1.[ProductHierarchyLevel2]
	  ,CONVERT(DECIMAL(25,15), t1.MultipliedQuantity)/t2.totMultipliedQuantity AS RetailFuelRatio
INTO #table3
FROM #table2 t1
JOIN TotalMultipliedQuantity t2
ON t1.[FiscalYearPeriod] = t2.[FiscalYearPeriod]



--STEP 3: Get total additive
-- Use GL 0058090020 COS-Adj-Additives to get total retail additive
IF OBJECT_ID('tempdb..#table4') IS NOT NULL
BEGIN
DROP TABLE #table4
END
GO

SELECT CONVERT(date, (RIGHT([FiscalYearPeriod],2)+'/01/'+LEFT([FiscalYearPeriod],4))) AS FiscalYearPeriod	
,'Alloc-'+[G/LAccount] AS Account
,SUM([AmountInFreelyDefinedCurrency4]*-1) AS Amount
INTO #table4
FROM [STG].[ZCCVMA3B] t1
JOIN [SPR].[vwProfitCenter] t2 -- This is a snapshot table of profit centre area
ON t1.[ProfitCenter] = t2.[PROFIT_CTR]
WHERE t2.[PCA_HIEND] In ('PM202211', 'PM202212', 'PM202213', 'PM202221', 'PM202231','PM202241') 
AND [G/LAccount] IN ('0058090020')  ---COS-Adj-Additives
AND  [FiscalYearPeriod] = '2023001'  --for testing only
GROUP BY [FiscalYearPeriod]
,[G/LAccount]



--STEP 4: Get Retail Product Additive
-- Use Ratio by product in step 3 and multiple by total ammount of additive in step 4 to get additive ammount by product
IF OBJECT_ID('tempdb..#table5') IS NOT NULL
BEGIN
DROP TABLE #table5
END
GO

SELECT t1.[FiscalYearPeriod]
	  ,t1.[ProductHierarchyLevel2] 
	  ,t2.Account
	  ,t1.RetailFuelRatio * t2.Amount AS RetailProdAddictive
INTO #table5
FROM #table3 t1
JOIN #table4 t2
ON t1.[FiscalYearPeriod] = t2.[FiscalYearPeriod]



--STEP 5a: Get FuelRatio For Retail Material 
-- Calculate fuel ratio for material by dividing material quantity with product quantity from table 1
IF OBJECT_ID('tempdb..#table6') IS NOT NULL
BEGIN
DROP TABLE #table6
END
GO

WITH TotalFuelByProduct AS
(
SELECT [FiscalYearPeriod]
	  ,[ProductHierarchyLevel2]
	  ,SUM(Quantity) AS QuantityByProduct
FROM #table1
GROUP BY [FiscalYearPeriod]
	  ,[ProductHierarchyLevel2]
)

SELECT t1.[FiscalYearPeriod]
	  ,t1.[ProductHierarchyLevel2]
	  ,t1.[Material]
      ,t1.Quantity
      ,t2.QuantityByProduct
	  ,CONVERT(DECIMAL(25,15), t1.Quantity)/t2.QuantityByProduct AS MaterialFuelRatio
INTO #table6
FROM #table1 t1
JOIN TotalFuelByProduct t2
ON t1.[FiscalYearPeriod] = t2.[FiscalYearPeriod]
AND t1.[ProductHierarchyLevel2] = t2.[ProductHierarchyLevel2]


--STEP 5b: Get Additive For Retail Material 
-- Use ratio from step 6 and multiply with product additive from step 5 to get additive by material
IF OBJECT_ID('tempdb..#table7') IS NOT NULL
BEGIN
DROP TABLE #table7
END
GO

SELECT t1.[FiscalYearPeriod]
	  ,t2.Account
	  ,t1.[ProductHierarchyLevel2]
	  ,t1.[Material]
	  ,MaterialFuelRatio * RetailProdAddictive AS RetailMaterialAddictive
INTO #table7
FROM #table6 t1
JOIN #table5 t2
ON t1.[FiscalYearPeriod] = t2.[FiscalYearPeriod]
AND t1.[ProductHierarchyLevel2] = t2.[ProductHierarchyLevel2]


--STEP 6a: Get COT total fuel  
-- Calculate fuel volume by class of trade, using GL = 0040102000 (Fuel)
IF OBJECT_ID('tempdb..#table8') IS NOT NULL
BEGIN
DROP TABLE #table8
END
GO

SELECT [FiscalYearPeriod]
	  ,Industry
	  ,[ProductHierarchyLevel2]
	  ,[Material]
	  ,SUM(Quantity) AS COTQuantity
INTO #table8
FROM #table0 
WHERE [G/LAccount] = '0040102000'  
GROUP BY [FiscalYearPeriod]
	  ,Industry
	  ,[ProductHierarchyLevel2]
	  ,[Material]


--STEP 6b: Get COT fuel ratio 
-- Calculate class of trade fuel ratio by dividing COT fuel quantity from step 8 with quantity from step 1
IF OBJECT_ID('tempdb..#table9') IS NOT NULL
BEGIN
DROP TABLE #table9
END
GO

SELECT t1.[FiscalYearPeriod]
	  ,t1.Industry
	  ,t1.[ProductHierarchyLevel2]
	  ,t1.[Material]
	  ,CASE WHEN Quantity = 0 THEN 0 ELSE CONVERT(DECIMAL(25,15),t1.COTQuantity) /Quantity END AS COTFuelRatio
INTO #table9
FROM #table8 t1
JOIN #table1 t2
ON t1.[FiscalYearPeriod] = t2.[FiscalYearPeriod]
AND t1.[ProductHierarchyLevel2] = t2.[ProductHierarchyLevel2]
AND t1.[Material] = t2.[Material]


--STEP 6c: Get COT Additive by ProductHierarchyLevel2 By Material

-- Multiply COT fuel ratio from step 9 with material additive ammount from step 7
IF OBJECT_ID('tempdb..#table10') IS NOT NULL
BEGIN
DROP TABLE #table10
END
GO

SELECT t1.[FiscalYearPeriod]
	  ,t1.Industry
	  ,t2.Account
	  ,t1.[ProductHierarchyLevel2]
	  ,t1.[Material]
	  ,t1.COTFuelRatio * t2.RetailMaterialAddictive AS COTAdditive
INTO #table10
FROM #table9 t1
JOIN #table7 t2
ON t1.[FiscalYearPeriod] = t2.[FiscalYearPeriod]
AND t1.[ProductHierarchyLevel2] = t2.[ProductHierarchyLevel2]
AND t1.[Material] = t2.[Material]


--STEP 7a: Get OUTLET total fuel  (excl. Retail Partnership) 
-- Calculate outlet fuel quantity using GL = 40102000 (fuel) 
IF OBJECT_ID('tempdb..#table11') IS NOT NULL
BEGIN
DROP TABLE #table11
END
GO

SELECT [FiscalYearPeriod]
	  ,Industry
	  ,Outlet
	  ,[ProductHierarchyLevel2]
	  ,[Material]
	  ,SUM(Quantity) AS OutletQuantity
INTO #table11
FROM #table0 
WHERE [G/LAccount] = '0040102000'  
AND Industry <> 1106
GROUP BY [FiscalYearPeriod]
	  ,Industry
	  ,Outlet
	  ,[ProductHierarchyLevel2]
	  ,[Material]


--STEP 7b: Get OUTLET fuelratio  
-- Divide outlet quantity from step 11 with COT fuel quantity from step 8 to get outlet fuel ratio
IF OBJECT_ID('tempdb..#table12') IS NOT NULL
BEGIN
DROP TABLE #table12
END
GO

SELECT t1.[FiscalYearPeriod]
	  ,t1.Industry
	  ,t1.Outlet
	  ,t1.[ProductHierarchyLevel2]
	  ,t1.[Material]
	  ,CASE WHEN t2.COTQuantity = 0 THEN 0 ELSE CONVERT(DECIMAL(25,15),t1.OutletQuantity)/t2.COTQuantity END AS OutletFuelRatio
INTO #table12
FROM #table11 t1
JOIN #table8 t2
ON t1.[FiscalYearPeriod] = t2.[FiscalYearPeriod]
AND t1.Industry = t2.Industry
AND t1.[ProductHierarchyLevel2] = t2.[ProductHierarchyLevel2]
AND t1.[Material] = t2.[Material]


--STEP 7c: Get OUTLET Additive  
-- Multiple outlet fuel ratio from step 12 with COT additive ammount from step 10 to get outlet additive
-- This step excludes retail partnership sites
IF OBJECT_ID('tempdb..#table13') IS NOT NULL
BEGIN
DROP TABLE #table13
END
GO

SELECT t1.[FiscalYearPeriod] --[DimDateSitePerformanceSID]
	  ,t1.Outlet --[DimSitesPerformanceSID]
	  ,t2.Account --[DimAccountSitePerformanceSID]
	  ,t1.[Material] --[DimProductSitePerformanceSID]
	  ,t1.OutletFuelRatio * t2.COTAdditive AS Amount
INTO #table13
FROM #table12 t1
JOIN #table10 t2
ON t1.[FiscalYearPeriod] = t2.[FiscalYearPeriod]
AND t1.Industry = t2.Industry
AND t1.[ProductHierarchyLevel2] = t2.[ProductHierarchyLevel2]
AND t1.[Material] = t2.[Material]


--STEP 8: Get Retail Partnership Outlet Information from [SPR].[vwDimSite]
-- ** Current error: SAP Hana B/W only contains 43 retail partnership sites, which is not the correct # because SAP only contains sites retail partnership sites with fuel quantity 
-- Cadeko site partnerships do not have site level volumes, only aggregate for the partnership which are assigned to 1 site.  
-- To get correct total retail partnership sites, we will use dim_site table where the criteria used is COT is shown below
IF OBJECT_ID('tempdb..#table14') IS NOT NULL
BEGIN
DROP TABLE #table14
END
GO

SELECT *
INTO #table14
FROM [SPR].[vwDimSite],  #table00
WHERE [Class of Trade] ='1106'
AND [Status Desc] = 'ACTIVE DL'
AND [Sales Group] = 186
AND [Street] NOT LIKE '%455 des Entrepreneurs%'
AND FiscalYearEndDate BETWEEN [Effective Start Date] AND [Effective End Date]


--STEP 8a: Get Number of Retail Partnership Outlet Count
-- This # will be used as a divider for COT retail parntership additive ammount
IF OBJECT_ID('tempdb..#table15') IS NOT NULL
BEGIN
DROP TABLE #table15
END
GO

SELECT COUNT([Outlet No]) AS RtlPartnershipCt
INTO #table15
FROM #table14


--STEP 8b: Retail Partnership Outlet Additive
-- Calculate each outlets additive ammount by dividing additive ammount from step 10 with # of outlets from step 15
-- ############# question: why for retail partnership are we not using fuel quantity, but # of sites?
-- ############# answer: Retail partnership pickup the fuel from terminal and distributes to their sites without Suncor knowing the volume that will be delivered to each site
-- ############# Because they pickup, we don't know which site receive it
IF OBJECT_ID('tempdb..#table16') IS NOT NULL
BEGIN
DROP TABLE #table16
END
GO

SELECT t1.[FiscalYearPeriod]
	  ,t1.Industry
	  ,t1.[ProductHierarchyLevel2]
	  ,t1.[Material]
	  ,SUM(t1.COTAdditive) AS COTAdditive
	  ,t2.RtlPartnershipCt
	  ,CONVERT(DECIMAL(25,15),SUM(t1.COTAdditive))/t2.RtlPartnershipCt AS RtlPartnerAdditive
INTO #table16
FROM #table10 t1, #table15 t2
WHERE t1.[Industry] = 1106
Group BY t1.[FiscalYearPeriod]
	  ,t1.Industry
	  ,t1.[ProductHierarchyLevel2]
	  ,t1.[Material]
	  ,t2.RtlPartnershipCt


--STEP 9: Retail Partnership Outlet Additive
-- Assign outlet additive ammount from step 16 to each retail partnership outlet
IF OBJECT_ID('tempdb..#table17') IS NOT NULL
BEGIN
DROP TABLE #table17
END
GO

SELECT t1.[FiscalYearPeriod] --[DimDateSitePerformanceSID]
	  ,t2.[Outlet No] AS Outlet--[DimSitesPerformanceSID]
	  ,'Alloc-0058090020' AS Account --[DimAccountSitePerformanceSID]
	  ,t1.[Material] --[DimProductSitePerformanceSID]
	  ,t1.RtlPartnerAdditive AS Amount
INTO #table17
FROM #table16 t1, #table14 t2

 
Select *
From #table13  
UNION
Select *
From #table17
order by [Outlet] , [Material]  

Select *
From #table4
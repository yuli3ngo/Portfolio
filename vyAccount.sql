USE [AdventureWorksDW2016]
GO

/****** Object:  View [dbo].[vyAccount]    Script Date: 2023-11-22 10:12:12 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE VIEW [dbo].[vyAccount]
AS


WITH tblParentAccount AS
(
SELECT [AccountKey]
	  ,CASE WHEN [AccountKey]= 47 THEN 'Taxes' 
	        WHEN [AccountKey]= 50 THEN 'Sales'  
			WHEN [AccountKey]= 51 THEN 'Sales' 
			WHEN [AccountKey]= 55 THEN 'Cost of Sales'
			ELSE [AccountDescription] END AS ParentAccountDescription
  FROM [AdventureWorksDW2016].[dbo].[DimAccount] 
)

SELECT	 t1.[AccountKey] AS [Account Key] 
		,t1.[AccountDescription] AS [Account Description]	
		,t1.[ParentAccountKey] AS [Parent Account Key]
		,CASE WHEN t1.[ParentAccountKey] = 88 AND t1.[AccountType] = 'Revenue' THEN 'Other Income'
	        WHEN t1.[ParentAccountKey] = 88 AND t1.[AccountType] = 'Expenditures' THEN 'Other Expenses'
			ELSE ParentAccountDescription END AS [Parent Account Description]
		,t1.[AccountCodeAlternateKey] AS [Account Code Alternate Key]
		,CONVERT(VARCHAR,t1.[AccountCodeAlternateKey]) + ' - ' + t1.[AccountDescription] AS [Account Code Description]
		,t1.[ParentAccountCodeAlternateKey] AS [Parent Account Code Alternate Key]
		,CASE WHEN t1.[AccountType] = 'Expenditures' AND t1.AccountKey IN (53, 54) THEN 'Revenue'
			  WHEN t1.[AccountType] = 'Expenditures' AND t1.[ParentAccountKey] = 55 THEN 'COGS'
		      WHEN t1.[AccountType] = 'Expenditures' AND t1.[ParentAccountKey] <> 55THEN 'Expenses' ELSE t1.[AccountType] END AS [Account Type]
		,t1.[Operator] 
		,t1.[ValueType] AS [Value Type]
FROM [AdventureWorksDW2016].[dbo].[DimAccount] t1
LEFT JOIN tblParentAccount t2 ON t1.[ParentAccountKey] = t2.[AccountKey] 
WHERE t1.[AccountType] IN ('Revenue','Expenditures')

  
GO



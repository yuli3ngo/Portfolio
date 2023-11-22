USE [AdventureWorksDW2016]
GO

/****** Object:  View [dbo].[vyFinance]    Script Date: 2023-11-22 9:07:40 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE VIEW [dbo].[vyFinance]
AS

SELECT [FinanceKey] AS [Finance Key]
      ,t1.[DateKey] AS [Date Key]
      ,[OrganizationKey] AS [Organization Key]
      ,[DepartmentGroupKey] AS [Department Group Key]
      ,[ScenarioKey] AS [Scenario Key]
      ,t1.[AccountKey] AS [Account Key]
      ,CASE WHEN [Operator] = '-' THEN [Amount]*-1
	   ELSE [Amount] END AS Amount
	  ,CASE WHEN [Operator] = '-' THEN ([Amount]*[AverageRate]) * -1
	   ELSE ([Amount]*[AverageRate]) END AS [Amount (USD)]
FROM [AdventureWorksDW2016].[dbo].[FactFinance] t1
  JOIN [AdventureWorksDW2016].[dbo].[vyOrganization] t2 ON t1.OrganizationKey = t2.[Organization Key]
  JOIN [dbo].[FactCurrencyRate] t3 ON t2.[Currency Key] = t3.CurrencyKey AND t1.[DateKey] = t3.DateKey
  JOIN [dbo].[DimAccount] t4 ON t1.AccountKey = t4.AccountKey

GO



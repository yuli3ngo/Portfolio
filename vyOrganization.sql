USE [AdventureWorksDW2016]
GO

/****** Object:  View [dbo].[vyOrganization]    Script Date: 2023-11-22 9:21:20 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE VIEW [dbo].[vyOrganization]
AS

WITH tblParentOrganization AS(
SELECT OrganizationKey 
,CASE WHEN OrganizationKey = 14 THEN 'North America Operations' ELSE OrganizationName END AS OrganizationName
,CASE WHEN OrganizationKey <> 14 THEN NULL ELSE OrganizationName END AS SubOrganizationName
FROM [AdventureWorksDW2016].[dbo].[DimOrganization]
)

SELECT DISTINCT t1.[OrganizationKey] AS [Organization Key]
      ,t1.[ParentOrganizationKey] AS [Parent Organization Key]
	  ,t2.[OrganizationName] AS [Parent Organization Name]
	  ,t2.[SubOrganizationName] AS [Sub Parent Organization Name]
      ,t1.[PercentageOfOwnership] AS [Percentage Of Ownership]
      ,t1.[OrganizationName] AS [Organization Name] 
      ,t1.[CurrencyKey] AS [Currency Key]
	  ,t3.[CurrencyName] AS [Currency Name]
  FROM [AdventureWorksDW2016].[dbo].[DimOrganization] t1
  JOIN tblParentOrganization t2 ON t1.ParentOrganizationKey = t2.OrganizationKey
  JOIN [AdventureWorksDW2016].[dbo].[DimCurrency] t3 ON t1.CurrencyKey = t3.CurrencyKey
 
GO



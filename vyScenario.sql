USE [AdventureWorksDW2016]
GO

/****** Object:  View [dbo].[vyScenario]    Script Date: 2023-11-22 9:46:31 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE VIEW [dbo].[vyScenario]
AS
SELECT [ScenarioKey] AS [Scenario Key] 
      ,[ScenarioName] AS [Scenario Name] 
  FROM [AdventureWorksDW2016].[dbo].[DimScenario]

GO



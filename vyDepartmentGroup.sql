USE [AdventureWorksDW2016]
GO

/****** Object:  View [dbo].[vyDepartmentGroup]    Script Date: 2023-11-22 10:11:06 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE VIEW [dbo].[vyDepartmentGroup]
AS

SELECT [DepartmentGroupKey] AS [Department Group Key]
      ,[DepartmentGroupName] AS [Department Group Name]
  FROM [AdventureWorksDW2016].[dbo].[DimDepartmentGroup]

GO



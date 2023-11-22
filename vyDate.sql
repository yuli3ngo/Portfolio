USE [AdventureWorksDW2016]
GO

/****** Object:  View [dbo].[vyDate]    Script Date: 2023-11-22 10:11:48 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE VIEW [dbo].[vyDate] AS

SELECT [DateKey] AS [Date Key]
      ,[FullDateAlternateKey] AS [Full Date]
      ,[DayNumberOfWeek] AS [Day Number of Week]
      ,[EnglishDayNameOfWeek] AS [Day Name Of Week]
      ,[WeekNumberOfYear] AS [Week Number Of Year]
      ,[EnglishMonthName] AS [English Month Name]
      ,[MonthNumberOfYear] AS [Month Number Of Year]
	  ,CONVERT(Date, CONVERT(Varchar,[CalendarYear])+'-'+CONVERT(Varchar,[MonthNumberOfYear])+'-01') AS [YYYY-MM]
      ,[CalendarQuarter] AS [Calendar Quarter]
      ,[CalendarYear] AS [Calendar Year]
	  ,[FiscalQuarter] AS [Fiscal Quarter] 
      ,[FiscalYear] AS [Fiscal Year]
      ,[FiscalSemester] AS [Fiscal Semester]
  FROM [AdventureWorksDW2016].[dbo].[DimDate]
  WHERE [FullDateAlternateKey] BETWEEN '2011-01-01' AND '2013-11-30'

GO



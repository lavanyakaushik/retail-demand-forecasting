/* =====================================================================
   Retail Demand Forecasting — Step 1a: Create tables and load raw data
   Database: RetailForecast (SQL Server 2025)
   Source:   Kaggle Rossmann Store Sales (train.csv, store.csv)
   ===================================================================== */

IF DB_ID('RetailForecast') IS NULL
    CREATE DATABASE RetailForecast;
GO

USE RetailForecast;
GO

/* ---------------------------------------------------------------------
   1. Staging tables: every column as text, so the load never fails on
      bad values. Typing and cleaning happen in step 3.
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS stg_train;
CREATE TABLE stg_train (
    Store         VARCHAR(10),
    DayOfWeek     VARCHAR(5),
    [Date]        VARCHAR(20),
    Sales         VARCHAR(20),
    Customers     VARCHAR(20),
    [Open]        VARCHAR(5),
    Promo         VARCHAR(5),
    StateHoliday  VARCHAR(5),
    SchoolHoliday VARCHAR(10)
);

DROP TABLE IF EXISTS stg_store;
CREATE TABLE stg_store (
    Store                     VARCHAR(10),
    StoreType                 VARCHAR(5),
    Assortment                VARCHAR(5),
    CompetitionDistance       VARCHAR(20),
    CompetitionOpenSinceMonth VARCHAR(10),
    CompetitionOpenSinceYear  VARCHAR(10),
    Promo2                    VARCHAR(5),
    Promo2SinceWeek           VARCHAR(10),
    Promo2SinceYear           VARCHAR(10),
    PromoInterval             VARCHAR(50)
);
GO

/* ---------------------------------------------------------------------
   2. Bulk load. FORMAT = 'CSV' handles quoted fields such as
      PromoInterval = "Jan,Apr,Jul,Oct".
      Update the paths if your files are somewhere else.
   --------------------------------------------------------------------- */
BULK INSERT stg_train
FROM 'C:\retail-demand-forecasting\data\raw\train.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', ROWTERMINATOR = '0x0a', TABLOCK);

BULK INSERT stg_store
FROM 'C:\retail-demand-forecasting\data\raw\store.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', ROWTERMINATOR = '0x0a', TABLOCK);
GO

/* ---------------------------------------------------------------------
   3. Typed tables. REPLACE(..., CHAR(13), '') strips stray carriage
      returns on the last column if the file has Windows line endings.
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS daily_sales;
CREATE TABLE daily_sales (
    Store         INT         NOT NULL,
    DayOfWeek     TINYINT     NOT NULL,
    SalesDate     DATE        NOT NULL,
    Sales         INT         NOT NULL,
    Customers     INT         NOT NULL,
    IsOpen        BIT         NOT NULL,
    Promo         BIT         NOT NULL,
    StateHoliday  CHAR(1)     NOT NULL,   -- 0 = none, a = public, b = Easter, c = Christmas
    SchoolHoliday BIT         NOT NULL,
    CONSTRAINT PK_daily_sales PRIMARY KEY (Store, SalesDate)
);

INSERT INTO daily_sales
SELECT
    CAST(Store AS INT),
    CAST(DayOfWeek AS TINYINT),
    CAST([Date] AS DATE),
    CAST(Sales AS INT),
    CAST(Customers AS INT),
    CAST([Open] AS BIT),
    CAST(Promo AS BIT),
    CAST(StateHoliday AS CHAR(1)),
    CAST(REPLACE(SchoolHoliday, CHAR(13), '') AS BIT)
FROM stg_train;

DROP TABLE IF EXISTS stores;
CREATE TABLE stores (
    Store                     INT          NOT NULL PRIMARY KEY,
    StoreType                 CHAR(1)      NOT NULL,
    Assortment                CHAR(1)      NOT NULL,   -- a = basic, b = extra, c = extended
    CompetitionDistance       INT          NULL,       -- meters to nearest competitor
    CompetitionOpenSinceMonth TINYINT      NULL,
    CompetitionOpenSinceYear  SMALLINT     NULL,
    Promo2                    BIT          NOT NULL,   -- ongoing loyalty promotion
    Promo2SinceWeek           TINYINT      NULL,
    Promo2SinceYear           SMALLINT     NULL,
    PromoInterval             VARCHAR(50)  NULL
);

INSERT INTO stores
SELECT
    CAST(Store AS INT),
    StoreType,
    Assortment,
    TRY_CAST(NULLIF(CompetitionDistance, '') AS INT),
    TRY_CAST(NULLIF(CompetitionOpenSinceMonth, '') AS TINYINT),
    TRY_CAST(NULLIF(CompetitionOpenSinceYear, '') AS SMALLINT),
    CAST(Promo2 AS BIT),
    TRY_CAST(NULLIF(Promo2SinceWeek, '') AS TINYINT),
    TRY_CAST(NULLIF(Promo2SinceYear, '') AS SMALLINT),
    NULLIF(REPLACE(PromoInterval, CHAR(13), ''), '')
FROM stg_store;
GO

/* ---------------------------------------------------------------------
   4. Sanity checks. Expected: 1,017,209 daily rows, 1,115 stores,
      dates from 2013-01-01 to 2015-07-31.
   --------------------------------------------------------------------- */
SELECT 'daily_sales' AS table_name, COUNT(*) AS row_count FROM daily_sales
UNION ALL
SELECT 'stores', COUNT(*) FROM stores;

SELECT MIN(SalesDate) AS first_date,
       MAX(SalesDate) AS last_date,
       COUNT(DISTINCT Store) AS store_count
FROM daily_sales;

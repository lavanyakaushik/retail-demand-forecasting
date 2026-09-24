/* =====================================================================
   Retail Demand Forecasting — Step 1b: Data quality checks + weekly table
   Run each numbered block on its own (highlight it, then F5) and note
   what you find. These findings go in the README.
   ===================================================================== */

USE RetailForecast;
GO

/* ---------------------------------------------------------------------
   1. Logical consistency: sales should only happen on open days.
   --------------------------------------------------------------------- */
SELECT
    SUM(CASE WHEN IsOpen = 0 AND Sales > 0 THEN 1 ELSE 0 END) AS closed_but_sales,
    SUM(CASE WHEN IsOpen = 1 AND Sales = 0 THEN 1 ELSE 0 END) AS open_but_zero_sales,
    SUM(CASE WHEN IsOpen = 0 THEN 1 ELSE 0 END)               AS closed_days,
    SUM(CASE WHEN Sales < 0 OR Customers < 0 THEN 1 ELSE 0 END) AS negative_values
FROM daily_sales;

/* ---------------------------------------------------------------------
   2. Date coverage: every store should have one row per day
      (942 days from 2013-01-01 to 2015-07-31). Stores with fewer
      rows have gaps.
   --------------------------------------------------------------------- */
SELECT days_recorded, COUNT(*) AS store_count
FROM (
    SELECT Store, COUNT(*) AS days_recorded
    FROM daily_sales
    GROUP BY Store
) AS per_store
GROUP BY days_recorded
ORDER BY days_recorded;

/* Where are the gaps? Monthly store counts show which months are missing. */
SELECT
    DATEFROMPARTS(YEAR(SalesDate), MONTH(SalesDate), 1) AS sales_month,
    COUNT(DISTINCT Store) AS stores_reporting
FROM daily_sales
GROUP BY DATEFROMPARTS(YEAR(SalesDate), MONTH(SalesDate), 1)
ORDER BY sales_month;

/* ---------------------------------------------------------------------
   3. Store attributes: missing values in the store table.
   --------------------------------------------------------------------- */
SELECT
    SUM(CASE WHEN CompetitionDistance IS NULL THEN 1 ELSE 0 END)       AS missing_comp_distance,
    SUM(CASE WHEN CompetitionOpenSinceYear IS NULL THEN 1 ELSE 0 END)  AS missing_comp_open_date,
    SUM(CASE WHEN Promo2 = 1 AND PromoInterval IS NULL THEN 1 ELSE 0 END) AS promo2_missing_interval
FROM stores;

/* ---------------------------------------------------------------------
   4. Outliers: open days with unusually high sales for that store
      (more than 3 standard deviations above the store's mean).
   --------------------------------------------------------------------- */
WITH store_stats AS (
    SELECT Store, AVG(CAST(Sales AS FLOAT)) AS mean_sales, STDEV(Sales) AS sd_sales
    FROM daily_sales
    WHERE IsOpen = 1
    GROUP BY Store
)
SELECT COUNT(*) AS high_outlier_days
FROM daily_sales d
JOIN store_stats s ON d.Store = s.Store
WHERE d.IsOpen = 1
  AND d.Sales > s.mean_sales + 3 * s.sd_sales;

/* ---------------------------------------------------------------------
   5. Weekly store-level table: the main input for EDA and forecasting.
      DayOfWeek in this data runs 1 = Monday to 7 = Sunday, so
      SalesDate minus (DayOfWeek - 1) days gives the Monday of each week.
   --------------------------------------------------------------------- */

DROP TABLE IF EXISTS weekly_store_sales;

SELECT
    d.Store,
    DATEADD(DAY, 1 - d.DayOfWeek, d.SalesDate)             AS WeekStart,
    SUM(d.Sales)                                           AS WeeklySales,
    SUM(d.Customers)                                       AS WeeklyCustomers,
    SUM(CAST(d.IsOpen AS INT))                             AS OpenDays,
    SUM(CAST(d.Promo AS INT))                              AS PromoDays,
    SUM(CASE WHEN d.StateHoliday <> '0' THEN 1 ELSE 0 END) AS StateHolidayDays,
    SUM(CAST(d.SchoolHoliday AS INT))                      AS SchoolHolidayDays,
    COUNT(*)                                               AS DaysInData,
    s.StoreType,
    s.Assortment,
    s.CompetitionDistance,
    s.Promo2
INTO weekly_store_sales
FROM daily_sales d
JOIN stores s ON d.Store = s.Store
GROUP BY d.Store, DATEADD(DAY, 1 - d.DayOfWeek, d.SalesDate),
         s.StoreType, s.Assortment, s.CompetitionDistance, s.Promo2;
GO

-- SELECT INTO makes calculated columns nullable; primary keys need NOT NULL
ALTER TABLE weekly_store_sales ALTER COLUMN Store INT NOT NULL;
ALTER TABLE weekly_store_sales ALTER COLUMN WeekStart DATE NOT NULL;
GO

ALTER TABLE weekly_store_sales ADD CONSTRAINT PK_weekly PRIMARY KEY (Store, WeekStart);
GO

/* Check: partial weeks (DaysInData < 7) occur at the start/end of the
   data and around any gaps. Flag them so models can exclude them. */
SELECT
    COUNT(*)                                          AS total_store_weeks,
    SUM(CASE WHEN DaysInData < 7 THEN 1 ELSE 0 END)   AS partial_weeks,
    MIN(WeekStart)                                    AS first_week,
    MAX(WeekStart)                                    AS last_week
FROM weekly_store_sales;
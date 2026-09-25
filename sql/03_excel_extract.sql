/* =====================================================================
   Retail Demand Forecasting — Step 4: Extract for Excel baselines
   Weekly sales for the 5 sample stores (one per demand cluster, chosen
   in Step 3), full weeks only, pivoted to one column per store.
   Expected: 133 rows, 2013-01-07 to 2015-07-20.
   ===================================================================== */

USE RetailForecast;
GO

WITH sample_weeks AS (
    SELECT WeekStart, Store, WeeklySales
    FROM weekly_store_sales
    WHERE Store IN (314, 299, 763, 259, 640)
      AND DaysInData = 7
),
promo AS (
    -- Promotions run chain-wide, so one flag per week is enough
    SELECT WeekStart, MAX(PromoDays) AS PromoDays
    FROM weekly_store_sales
    WHERE Store IN (314, 299, 763, 259, 640)
    GROUP BY WeekStart
)
SELECT
    p.WeekStart,
    p.[314] AS Store314,   -- cluster 1: weekday-focused
    p.[299] AS Store299,   -- cluster 2: summer / tourist
    p.[763] AS Store763,   -- cluster 3: Christmas-driven
    p.[259] AS Store259,   -- cluster 4: Sunday-trading
    p.[640] AS Store640,   -- cluster 5: balanced week
    pr.PromoDays
FROM sample_weeks
PIVOT (SUM(WeeklySales) FOR Store IN ([314], [299], [763], [259], [640])) AS p
JOIN promo pr ON pr.WeekStart = p.WeekStart
ORDER BY p.WeekStart;

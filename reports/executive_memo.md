# Executive Memo: Demand Forecasting & Inventory Planning

**To:** Director of Retail Operations  
**From:** Lavanya Kaushik, Data Analyst  
**Date:** September 2026  
**Subject:** Better forecasts can free €4–6M of inventory and sharpen promo spend

**Bottom line.** A machine-learning forecast (LightGBM) cuts weekly store-level forecast error by 44% compared with the current seasonal-naive method. Used for replenishment, it lets our 1,115 stores hold 37–54% less safety stock at the same 95% service target. The promotion analysis also points to a shorter promo that is worth testing.

## What we found

**1. Forecast accuracy.** Across a four-window rolling backtest (2014–15), forecast error (WAPE) fell from 11.2% to 6.3%. LightGBM also beat Excel's FORECAST.ETS on sample stores (4.9% vs 6.5%). The biggest gains come when the promo calendar shifts, which the seasonal method cannot follow. The 8 summer/tourist stores remain the hardest to forecast (8.9% error).

**2. Inventory.** At a 95% service target, safety stock falls from €19.7M to €9.0M in sales value. Tested on data the policy had not seen, it delivered 97.8% actual service, and at the same achieved service level the reduction is 37%. That frees **€4.4–6.4M of inventory at cost**, or about €0.9–1.3M a year in holding cost.

**3. Promotions.** Promo days lift sales by 37% (95% CI 36–38%), from both more shoppers (+19%) and bigger baskets (+15%). The lift is front-loaded: +65% on Monday but only +18% on Friday. A Monday–Wednesday promo would keep about 75% of the promo sales gain with 60% of the promo days. The 25 summer/tourist and Sunday-trading stores get about half the average lift, and stores 789 and 794 show none.

## Recommendations

1. **Pilot forecast-based replenishment** at a 95% service target in one region, tracking stockouts and inventory weekly against a comparison region. Chain-wide potential: €4.4–6.4M of inventory freed.
2. **Run the Monday–Wednesday promo test** that has already been designed: 2 promo weeks, 225 test stores vs 890 control stores, matched by store cluster and size. It reliably detects a 2% change in sales. Adopt the shorter promo only if the sales lost are smaller than the promo cost saved.
3. **Review promo participation** for the 25 low-response stores and for stores 789 and 794.

## Caveats and next steps

The data (Rossmann, 2013–15) records sales in euros, not units, so inventory is measured in sales value. Cost figures assume a 60% cost of goods and a 20% annual holding cost, lead time is assumed to be one week, and promo costs are not in the data. Next steps: separate holiday and regular-season safety stock, and better forecasts for summer/tourist stores.

*Explore the numbers in the interactive [Tableau dashboard](https://public.tableau.com/views/RetailDemandForecastingInventoryPlanning_17906241946120/ForecastAccuracy) and [what-if app](https://rossmann-what-if.streamlit.app).*

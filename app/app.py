"""Retail Demand Forecasting & Inventory Planning: what-if app (Step 10).

Reads the exports in tableau/data/ (built by notebooks/07_tableau_export.ipynb),
so it runs without SQL Server. Methods match Step 6 (promo lift) and Step 8 (inventory).
"""
from pathlib import Path

import numpy as np
import pandas as pd
import plotly.graph_objects as go
import streamlit as st
from scipy.stats import norm

DATA = Path(__file__).resolve().parent.parent / "tableau" / "data"
DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri"]
ALL = "All stores"
C_ACT, C_LGBM, C_NAIVE = "#3a3a3a", "#4e79a7", "#f28e2b"

st.set_page_config(page_title="Retail What-If Planner", page_icon="📦", layout="wide")


# ---------- data ----------
@st.cache_data
def load():
    acc = pd.read_csv(DATA / "forecast_accuracy.csv", parse_dates=["WeekStart"])
    lift = pd.read_csv(DATA / "promo_lift.csv")
    for m in ["LGBM", "Naive"]:
        acc[f"Err_{m}"] = (acc["WeeklySales"] - acc[f"Pred_{m}"]) / acc[f"Pred_{m}"]
    latest = acc[acc["Window"] == sorted(acc["Window"].unique())[-1]]
    stores = latest.groupby(["Store", "ClusterName"])[["Pred_LGBM", "Pred_Naive"]].mean().reset_index()
    params = {m: acc.groupby("ClusterName")[f"Err_{m}"].agg(["mean", "std"]) for m in ["LGBM", "Naive"]}
    return acc, lift, stores, params


def policy(stores, params, sl, lead, review):
    """Step 8 policy (normal method) for every store, both models."""
    out = stores[["Store", "ClusterName"]].copy()
    z, H = norm.ppf(sl), lead + review
    for m in ["LGBM", "Naive"]:
        f = stores[f"Pred_{m}"]
        bias = stores["ClusterName"].map(params[m]["mean"])
        per_week = z * stores["ClusterName"].map(params[m]["std"]) * f
        out[f"Forecast_{m}"] = f
        out[f"SS_{m}"] = per_week * np.sqrt(H)
        out[f"ROP_{m}"] = f * (1 + bias) * lead + per_week * np.sqrt(lead)
        out[f"OUT_{m}"] = f * (1 + bias) * H + per_week * np.sqrt(H)
    return out


acc, lift, stores, params = load()
eur = lambda x: f"€{x:,.0f}"
eur_m = lambda x: f"€{x / 1e6:,.2f}M"

# ---------- sidebar ----------
st.sidebar.title("📦 Retail What-If Planner")
st.sidebar.caption("Rossmann Store Sales, 1,115 stores. LightGBM weekly forecasts vs a seasonal-naive baseline.")
store_ids = sorted(stores["Store"].unique())
choice = st.sidebar.selectbox("Store", [ALL] + store_ids)
if choice != ALL:
    st.sidebar.markdown(f"**Cluster:** {stores.loc[stores['Store'] == choice, 'ClusterName'].iat[0]}")

tab_promo, tab_inv = st.tabs(["Promo what-if", "Inventory what-if"])

# ---------- promo what-if ----------
with tab_promo:
    st.header("Which weekdays should get the promo?")
    st.write("Each weekday's lift is measured by comparing promo days with the same store and weekday "
             "one week before and after, without a promo (Step 6). Pick the promo days to see the effect "
             "on Mon–Fri sales compared with today's Mon–Fri promo.")

    sel = lift if choice == ALL else lift[lift["Store"] == choice]
    d = sel.groupby("DayName")[["Pairs", "PromoSales", "CtrlSales"]].sum().reindex(DAYS)
    d["Base"] = d["CtrlSales"] / d["Pairs"]          # average non-promo day
    d["Promo"] = d["PromoSales"] / d["Pairs"]        # average promo day
    d["Lift"] = d["Promo"] / d["Base"] - 1
    if choice == ALL:                                 # chain average day = sum over stores
        n = sel["Store"].nunique()
        d[["Base", "Promo"]] *= n

    days = st.multiselect("Promo days", DAYS, default=DAYS)
    base = d["Base"].sum()
    gain_full = (d["Promo"] - d["Base"]).sum()
    gain_scn = (d.loc[days, "Promo"] - d.loc[days, "Base"]).sum() if days else 0.0
    full, scn = base + gain_full, base + gain_scn

    c1, c2, c3 = st.columns(3)
    c1.metric("Mon–Fri sales, current promo (Mon–Fri)", eur(full))
    c2.metric(f"Mon–Fri sales, scenario ({len(days)} promo days)", eur(scn),
              f"{scn / full - 1:+.1%}" if abs(scn - full) > 0.5 else None)
    c3.metric("Share of promo gain kept", f"{gain_scn / gain_full:.0%}" if gain_full else "–")
    c3.caption(f"with {len(days) / 5:.0%} of the promo days")

    fig = go.Figure()
    fig.add_bar(x=DAYS, y=d["Base"], name="No promo", marker_color="#c9c9c9")
    fig.add_bar(x=DAYS, y=[d.at[x, "Promo"] if x in days else None for x in DAYS],
                name="With promo", marker_color=C_NAIVE,
                text=[f"+{d.at[x, 'Lift']:.0%}" if x in days else "" for x in DAYS], textposition="outside")
    fig.update_layout(barmode="group", yaxis_title="Average daily sales (€)", height=380,
                      margin=dict(t=30, b=10), legend=dict(orientation="h", y=1.1))
    st.plotly_chart(fig, width="stretch")
    st.caption(f"Based on {int(d['Pairs'].sum()):,} matched promo days. Excludes weekend effects "
               "(Step 6 found Saturdays in promo weeks run about 4% lower) and promo costs.")

    if choice != ALL:
        st.subheader(f"Store {choice}: actual vs forecast")
        h = acc[acc["Store"] == choice].groupby("WeekStart")[["WeeklySales", "Pred_LGBM", "Pred_Naive"]].mean()
        h = h.reindex(pd.date_range(h.index.min(), h.index.max(), freq="W-MON"))  # gaps break lines
        fig2 = go.Figure()
        for col, name, color in [("WeeklySales", "Actual", C_ACT), ("Pred_LGBM", "LightGBM", C_LGBM),
                                 ("Pred_Naive", "Seasonal naive", C_NAIVE)]:
            fig2.add_scatter(x=h.index, y=h[col], name=name, line=dict(color=color, width=2.5 if name == "Actual" else 1.5))
        fig2.update_layout(yaxis_title="Weekly sales (€)", height=360, margin=dict(t=20, b=10),
                           legend=dict(orientation="h", y=1.1))
        st.plotly_chart(fig2, width="stretch")
        a = acc[acc["Store"] == choice]
        w = lambda m: (a["WeeklySales"] - a[f"Pred_{m}"]).abs().sum() / a["WeeklySales"].sum()
        st.caption(f"Backtest WAPE for this store: LightGBM {w('LGBM'):.1%} vs seasonal naive {w('Naive'):.1%}.")

# ---------- inventory what-if ----------
with tab_inv:
    st.header("How much safety stock does the better forecast save?")
    st.write("Safety stock covers forecast error. Error spread is measured per cluster from the "
             "4-window backtest (Step 8); change the assumptions below to see the policy update.")

    c1, c2, c3 = st.columns(3)
    sl = c1.slider("Target service level (%)", 80.0, 99.9, 95.0, 0.1, format="%.1f%%") / 100
    lead = c2.slider("Supplier lead time (weeks)", 1, 4, 1)
    review = c3.slider("Order review period (weeks)", 1, 4, 1)
    c4, c5 = st.columns(2)
    cogs = c4.slider("Cost of goods (% of sales value)", 40, 80, 60, 5, format="%d%%") / 100
    hold = c5.slider("Annual holding cost (% of inventory)", 10, 30, 20, 1, format="%d%%") / 100

    pol = policy(stores, params, sl, lead, review)
    ss_l, ss_n = pol["SS_LGBM"].sum(), pol["SS_Naive"].sum()
    freed = (ss_n - ss_l) * cogs

    st.subheader(f"All stores at {sl:.1%} service")
    m1, m2, m3, m4 = st.columns(4)
    m1.metric("Safety stock, LightGBM", eur_m(ss_l))
    m2.metric("Safety stock, seasonal naive", eur_m(ss_n))
    m3.metric("Inventory freed (at cost)", eur_m(freed))
    m3.caption(f"{1 - ss_l / ss_n:.0%} less safety stock than naive")
    m4.metric("Holding cost saved per year", eur_m(freed * hold))

    grid = np.round(np.arange(0.80, 0.9951, 0.005), 3)
    curve = [(s, policy(stores, params, s, lead, review)) for s in grid]
    fig3 = go.Figure()
    fig3.add_scatter(x=grid * 100, y=[p["SS_LGBM"].sum() / 1e6 for _, p in curve], name="LightGBM", line_color=C_LGBM)
    fig3.add_scatter(x=grid * 100, y=[p["SS_Naive"].sum() / 1e6 for _, p in curve], name="Seasonal naive", line_color=C_NAIVE)
    fig3.add_vline(x=sl * 100, line_dash="dash", line_color="grey")
    fig3.update_layout(xaxis_title="Target service level (%)", yaxis_title="Total safety stock (€M, sales value)",
                       height=360, margin=dict(t=20, b=10), legend=dict(orientation="h", y=1.1))
    st.plotly_chart(fig3, width="stretch")

    if choice == ALL:
        st.subheader("Stores needing the most safety stock")
        top = pol.nlargest(15, "SS_LGBM")
    else:
        st.subheader(f"Store {choice}")
        top = pol[pol["Store"] == choice]
    show = pd.DataFrame({
        "Store": top["Store"], "Cluster": top["ClusterName"],
        "Weekly forecast": top["Forecast_LGBM"].map(eur), "Safety stock": top["SS_LGBM"].map(eur),
        "Reorder point": top["ROP_LGBM"].map(eur), "Order-up-to level": top["OUT_LGBM"].map(eur),
        "Saved vs naive": (top["SS_Naive"] - top["SS_LGBM"]).map(eur),
    })
    st.dataframe(show, hide_index=True, width="stretch")

    st.caption("Inventory is in € sales value (Rossmann has no unit data). Safety stock = z × cluster error spread × "
               "weekly forecast × √(lead time + review period), assuming independent weekly errors. At the Step 8 "
               "settings (95%, 1-week lead time and review), totals are €9.0M vs €19.7M. At the same achieved service "
               "level, validated out of sample, the reduction is 37%.")

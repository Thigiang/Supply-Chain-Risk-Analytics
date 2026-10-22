import sqlite3
from pathlib import Path

import pandas as pd
import streamlit as st
import plotly.express as px


ROOT = Path(__file__).parent.parent
DB_PATH = ROOT / "data" / "supply_chain.db"
SQL_DIR = ROOT / "sql" / "dashboard"

@st.cache_data
def run_query(name):
    sql = (SQL_DIR / f"{name}.sql").read_text()
    with sqlite3.connect(DB_PATH) as conn:
        return pd.read_sql(sql, conn)

st.set_page_config(page_title="Supply Chain Risk", layout="wide")
st.title("Supply Chain Risk Analytics")
st.caption("DataCo supply chain dataset, 2015-01 to 2018-01")

otif = run_query("kpi_otif")
delivery = run_query("kpi_delivery")

col1, col2, col3, col4 = st.columns(4)
col1.metric("OTIF", f"{otif.loc[0, 'otif_pct']}%")
col2.metric("Late rate", f"{delivery.loc[0, 'late_rate_pct']}%")
col3.metric("Avg delay", f"{delivery.loc[0, 'avg_delay_days']} days")
col4.metric("Revenue delivered late", f"${delivery.loc[0, 'late_revenue'] / 1e6:.1f}M")

# add a section header
st.subheader("OTIF by shipping mode")

otif_mode = run_query("otif_by_mode")

fig = px.bar(
    otif_mode,
    x="shipping_mode",
    y="otif_pct",
    text="otif_pct",
    labels={"shipping_mode": "Shipping mode", "otif_pct": "OTIF (%)"},
)
fig.update_traces(textposition="outside")  # keeps the 0% label visible for First Class
fig.update_yaxes(range=[0, 105])
st.plotly_chart(fig)

st.caption("First Class can never be on time: promised 1 day, always delivered in 2.")

st.subheader("Risk")
left, right = st.columns(2)

with left:
    st.markdown("**Department risk ranking** (department as a stand-in for supplier)")
    risk = run_query("risk_score")
    st.dataframe(
        risk,
        hide_index=True,
        column_config={
            "department_name": "Department",
            "n": "Items (incl. canceled)",
            "delay_pct": "Late (%)",
            "lead_time_var": "Lead-time variance",
            "cancel_rate_pct": "Canceled (%)",
            "risk_score": "Risk score",
            "risk_rank": "Rank",
        },
    )
    st.caption(
        "Weights: 0.5 delay, 0.3 variance, 0.2 cancellation, each min-max normalized. "
        "Rank 1 and rank 8 differ by only 1.2 points of late rate, within chance, "
        "so no department is a meaningfully riskier supplier."
    )

with right:
    st.markdown("**Shipment risk labels by shipping mode** (% of each mode's shipments)")
    alerts = run_query("alerts_by_mode")
    fig = px.bar(
        alerts,
        x="shipping_mode",
        y="pct",
        color="risk_label",
        text="pct",
        category_orders={
            "risk_label": ["Low", "Medium", "High"],
            # same mode order as the OTIF chart (worst OTIF first)
            "shipping_mode": ["First Class", "Second Class", "Same Day", "Standard Class"],
        },
        # one hue, light to dark = low to high risk
        color_discrete_map={"Low": "#86b6ef", "Medium": "#3987e5", "High": "#184f95"},
        labels={"shipping_mode": "Shipping mode", "pct": "Share of shipments (%)", "risk_label": "Risk"},
        hover_data={"n": True},
    )
    fig.update_yaxes(range=[0, 100])
    fig.update_layout(legend_traceorder="reversed")  # legend top-to-bottom matches the stack: High on top
    st.plotly_chart(fig)
    st.caption(
        "High = 3+ days late, Medium = 1–2 days late, Low = on time or early. "
        "High risk comes only from Second Class; every First Class shipment is Medium."
    )


st.subheader("Monthly trend")

trend = run_query("monthly_trend")
trend["order_month"] = pd.to_datetime(trend["order_month"])

fig = px.line(
    trend,
    x="order_month",
    y="late_rate_pct",
    markers=True,
    labels={"order_month": "Order month", "late_rate_pct": "Late rate (%)"},
    hover_data={"n_items": True, "avg_cycle_days": True},
)
fig.update_traces(line_width=2, marker_size=8)
fig.update_yaxes(range=[0, 100])
fig.add_vrect(
    x0="2017-10-01",
    x1="2018-01-31",
    fillcolor="gray",
    opacity=0.15,
    line_width=0,
    annotation_text="Data recording change",
    annotation_position="top left",
)
st.plotly_chart(fig)

st.caption(
    "Late rate stays between 55.17% and 59.31% every month: lateness is structural, not seasonal. "
    "From 2017-10, orders have ~1 item each and item counts drop by more than half while order counts do not; "
    "this abrupt change most likely reflects how the data was recorded, not a business change."
)


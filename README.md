# Supply Chain Risk Analytics

SQL analysis of 180,519 order items from the DataCo supply chain dataset: OTIF, root cause of late
deliveries, department risk scoring and shipment risk alerts.

**Data:** [DataCo Smart Supply Chain for Big Data Analysis](https://www.kaggle.com/datasets/shashwatwork/dataco-smart-supply-chain-for-big-data-analysis) (Kaggle)

**Headline:** OTIF is 41.78%, and lateness is driven by shipping-mode promises the operation can't meet
(First Class promises 1 day but always takes 2), not by market, region or department.

The project has two versions with the same SQL analysis and a different dashboard:

| Version | Dashboard | Branch |
|---|---|---|
| Streamlit | Python web app with an executive summary page | [`streamlit`](https://github.com/Thigiang/Supply-Chain-Risk-Analytics/tree/streamlit) |
| Tableau | [Tableau Public dashboard](https://public.tableau.com/app/profile/thi.giang/viz/Supply_Chain_Risk_Analysis_Dashboard/Dashboard) | [`tableau`](https://github.com/Thigiang/Supply-Chain-Risk-Analytics/tree/tableau) |

Each branch's README has the full findings, KPI definitions, data limitations and setup steps.
This branch holds the shared work: `notebooks/` (data cleaning), `sql/exploration/`, `sql/analysis/`
and `sql/dashboard/`.

The SQL is written for SQLite. It uses SQLite's boolean shortcuts (e.g. `SUM(NOT in_full)`,
`AVG(order_status = 'SUSPECTED_FRAUD')`); other databases such as PostgreSQL or Snowflake need
`SUM(CASE WHEN ... THEN 1 ELSE 0 END)` instead.

# Supply Chain Risk Analytics

Why are more than half of deliveries late, and where should a business act first?
This project answers that with SQL on 180,519 order items from the DataCo supply chain dataset,
and presents the results in an interactive **Tableau** dashboard.

**Data:** [DataCo Smart Supply Chain for Big Data Analysis](https://www.kaggle.com/datasets/shashwatwork/dataco-smart-supply-chain-for-big-data-analysis) (Kaggle)  
**Tools:** Python (pandas) · SQLite · SQL (CTEs, window functions) · Tableau

## Key findings

| Question | Answer |
|---|---|
| How well are orders delivered? | **OTIF is 41.78%**: fewer than half of 64,264 orders arrive on time and in full |
| What fails: timing or completeness? | Timing. On Time is 42.68%, In Full is 97.87%; 96.3% of OTIF failures are late deliveries |
| What drives lateness? | **Shipping mode only.** OTIF ranges from 0.00% (First Class) to 58.89% (Standard Class). Market, region, customer segment, product category and department barely matter: their gaps are small, and the larger ones come from small groups and are within chance |
| Why? | **Overpromising.** First Class promises 1 day but always takes 2, so it is never on time. Second Class takes the same 2–6 days as Standard Class but promises 2 days instead of 4 |
| What is at stake? | **$18.1M** of revenue (57%) was delivered late |
| Which "supplier" is riskiest? | None meaningfully: department late rates differ by only 1.2 points, within chance |
| Is it getting better or worse? | Neither. The monthly late rate stays between 55.17% and 59.31% for 37 months |
| Fraud? | 1,488 orders ($741K) flagged as suspected fraud, all paid by bank transfer, all blocked before shipping |

**Recommendation:** reset the promised delivery days for First and Second Class to what operations
actually deliver, or speed those modes up. Together they cover 22,338 orders, about a third of all orders.

## Dashboard

**[View the dashboard on Tableau Public](https://public.tableau.com/app/profile/thi.giang/viz/Supply_Chain_Risk_Analysis_Dashboard/Dashboard)**

One page with KPI tiles (OTIF, late rate, average delay, revenue delivered late), OTIF by shipping mode,
shipment risk labels by mode, the department risk ranking, and the monthly late-rate trend.

SQL does the analysis and Tableau does the visuals: every number comes from a query in `sql/dashboard/`,
exported to `tableau/data/` as CSV, so the dashboard shows exactly what the SQL returns.

## KPI definitions

| KPI | Definition |
|---|---|
| **On Time** | `days_for_shipping_real <= days_for_shipment_scheduled` |
| **In Full** | The order was not canceled. The dataset has no shipped-vs-ordered quantities and no order is partially canceled, so cancellation is the only measurable "not in full" outcome |
| **OTIF** | On Time AND In Full, per order. Suspected-fraud orders are excluded: blocking them was the correct action, not a delivery failure. Customer cancellations count as failures |
| **Late rate** | Share of shipped items with `late_delivery_risk = 1` (canceled items excluded) |
| **Delay** | `days_for_shipping_real - days_for_shipment_scheduled`. Risk labels: High = 3+ days late, Medium = 1–2 days late, Low = on time or early |
| **Department risk score** | 0.5 × late rate + 0.3 × lead-time variance + 0.2 × cancellation rate, each min-max normalized. Department stands in for supplier, since the dataset has no supplier column |

## Method

1. **Load and clean** (`notebooks/load_data.ipynb`): convert the date columns to ISO format so SQLite's date
   functions work, remove personal customer data, drop empty columns, and load everything into SQLite.
2. **Explore** (`sql/exploration/`): baseline late rate, late rate by shipping mode, market, region, segment and
   category, promised vs. actual days, revenue impact, fraud.
3. **Analyse** (`sql/analysis/`): OTIF and its breakdowns, root cause (mode × market, mode × region × department
   compared with each mode's own late rate), department risk score, shipment risk labels, monthly trend.
4. **Present** (`sql/dashboard/` + `tableau/`): one query per chart, exported to CSV and visualized in Tableau.

Two rules apply throughout: canceled items are excluded from delivery metrics (they never shipped), and small
groups (under 500 items) are excluded from rankings, because their rates swing too much by chance. Differences
are judged against a rough margin of error of ±100/√n percentage points.

## Data limitations

- **Possibly simulated data:** actual delivery times are spread almost perfectly evenly (about 20% at each of
  2–6 days for Standard Class), and markets differ by less than 1 point. Real operations are rarely this uniform.
- **Recording change from October 2017:** orders drop to about 1 item each and item counts fall by more than half,
  while order counts do not. This most likely reflects how the data was recorded, not a business change.
- **Fraud is only ever flagged on bank transfers** (0% for every other payment type), which suggests the fraud
  check only runs on transfers. "Suspected" means flagged, not confirmed.
- **No refund or customer-churn data**, so the real cost of lateness can't be measured: $18.1M is revenue
  exposed to a poor delivery experience, not money lost.
- **No supplier column:** department is used as a stand-in.

## Run it locally

**To open the dashboard:** open `tableau/Supply_Chain_Risk_Analysis_Dashboard.twbx` in Tableau Desktop or
Tableau Public. The packaged workbook includes its data, so nothing else is needed.

**To rebuild the data from scratch:**

1. Download the dataset from Kaggle:
   [DataCo Smart Supply Chain for Big Data Analysis](https://www.kaggle.com/datasets/shashwatwork/dataco-smart-supply-chain-for-big-data-analysis),
   and put `DataCoSupplyChainDataset.csv` in `DataCo/`.
2. Install the dependencies (Python 3.12):
   ```bash
   python -m venv .venv
   .venv/bin/pip install -r requirements.txt
   ```
3. Build the database: run `notebooks/load_data.ipynb` top to bottom. It creates `data/supply_chain.db`.
4. Export the dashboard queries to CSV:
   ```bash
   for f in sql/dashboard/*.sql; do name=$(basename "$f" .sql); sqlite3 -header -csv data/supply_chain.db < "$f" > "tableau/data/$name.csv"; done
   ```
5. Open the workbook in Tableau and refresh the extracts (Data → each data source → Extract → Refresh).

## Repository structure

```
notebooks/load_data.ipynb      clean the raw CSV and load it into SQLite
sql/exploration/01–05          exploratory questions, each with written findings
sql/analysis/01–05             risk score, alerts, OTIF, root cause, monthly trend
sql/dashboard/                 one query per dashboard element
tableau/Supply_Chain_Risk_Analysis_Dashboard.twbx   Tableau workbook (data included)
tableau/data/                  query results exported to CSV for Tableau
DataCo/DescriptionDataCoSupplyChain.csv   data dictionary
```

## AI-assisted workflow

I wrote the code and analysis, and used Claude (Claude Code) as a reviewer: it tested my queries
by running them, pointed out issues, and suggested improvements.

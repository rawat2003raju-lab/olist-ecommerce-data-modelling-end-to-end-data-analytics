# Olist E-Commerce: End-to-End Data Modelling Project

**Python → MySQL → Power BI**

An end-to-end analytics project on the Brazilian Olist e-commerce dataset. Raw CSVs are cleaned in Python, loaded into a MySQL database, queried to answer business questions, and modelled as a star schema in Power BI to power a 3-page interactive dashboard.

---

## Business Problem

Olist is a marketplace connecting small sellers to customers across Brazil. This project answers questions leadership would ask:

- How big is the business, and how is revenue trending?
- Which product categories and states drive revenue?
- How do customers pay?
- Do customers come back?
- How fast is delivery, and does late delivery hurt customer satisfaction?

---

## Workflow

```
Raw CSVs (9 files)  →  Python (pandas)  →  MySQL  →  SQL views  →  Power BI
   Kaggle               cleaning &          schema,     reporting      star schema,
                        validation          queries     layer          DAX, dashboard
```

| Stage | Tool | What was done |
|---|---|---|
| 1. Clean | Python (pandas, Jupyter) | Type fixes, missing values, duplicates, derived columns, validation |
| 2. Store and query | MySQL | Schema with keys and indexes, 12 business queries, reporting views |
| 3. Model | Power BI | Star schema, date table, DAX measures |
| 4. Visualise | Power BI | 3-page dashboard |

---

## Dataset

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) on Kaggle (9 related CSV files, about 100k orders from 2016 to 2018). Credit to Olist and Kaggle. Please see the Kaggle page for the dataset license. The raw data is not included in this repository; download it from the link above.

| Table | Rows (raw) | Description |
|---|---|---|
| customers | 99,441 | Customer IDs and location |
| orders | 99,441 | Order status and timestamps |
| order_items | 112,650 | Products, sellers, price and freight per order |
| payments | 103,886 | Payment type, instalments, value |
| reviews | 100,000 | Review scores and comments |
| products | 32,951 | Product attributes and category |
| sellers | 3,095 | Seller location |
| geolocation | 1,000,163 | Zip prefix coordinates |
| category translation | 71 | Portuguese to English category names |

---

## Repository Structure

```
olist-data-modelling/
├── notebooks/
│   └── 01_cleaning.ipynb        # Python cleaning and validation
├── sql/
│   ├── schema.sql               # Tables, keys, indexes
│   ├── business_queries.sql     # 12 business questions with insights
│   └── views.sql                # Reporting views used by Power BI
├── powerbi/
│   └── olist_dashboard.pbix     # Data model and dashboard
├── images/                      # ER diagram, data model, dashboard screenshots
├── README.md
```

---

## Step 1: Data Cleaning (Python)

Notebook: `notebooks/01_cleaning.ipynb`

| Table | Issue found | Fix |
|---|---|---|
| geolocation | 261,831 duplicate rows | Dropped duplicates, then aggregated to one row per zip prefix (19,015 rows) so it can act as a clean lookup |
| reviews | Repeated `review_id`s, about 146k empty comment fields | Kept the latest version of each review, added a `has_comment` flag, filled empty text with placeholders |
| orders | Dates stored as text, 4,908 missing values | Converted to datetime. **Missing delivery dates were kept as NULL** because they belong to orders that were never delivered |
| products | 2,448 missing values, misspelled column names | Filled missing category with "unknown", fixed `lenght` typos, merged in English category names |
| customers, sellers | Zip codes losing leading zeros | Stored zip prefixes as 5-character text |

**Derived columns:** `delivery_days`, `delay_days` (actual vs estimated delivery), `is_late`, `order_year`, `order_month`.

**Validation:** unique order IDs, every order item maps to a valid order and product, unique review IDs.

---

## Step 2: Database and Business Queries (MySQL)

- **Schema** (`sql/schema.sql`): 8 tables with primary keys, foreign keys and indexes on join columns.
- **ER diagram:** see `images/er_diagram.png`.
- **Queries** (`sql/business_queries.sql`): 12 queries from basic aggregation to window functions and CTEs (`LAG`, `RANK`, `NTILE`, running totals, customer segmentation).
- **Views** (`sql/views.sql`): a clean reporting layer (`vw_fact_sales`, `vw_dim_customer`, `vw_dim_product`, `vw_dim_seller`, `vw_dim_order`, `vw_fact_reviews`, `vw_fact_payments`) so Power BI reads a prepared star-schema-ready layer.

**Definitions:** revenue is the sum of item `price` for **delivered** orders, in Brazilian Reals (R$). It excludes freight.

---

## Step 3: Data Model (Power BI)

Star schema with three fact tables and five dimensions:

- **Facts:** `fact_sales` (grain: one row per order item), `fact_reviews`, `fact_payments`
- **Dimensions:** `dim_customer`, `dim_product`, `dim_seller`, `dim_order`, `dim_date`

![Data model](images/data_model.png)

**Modelling decisions**
- All relationships are many-to-one. Filtering is single-direction, except `fact_sales` to `dim_order`, which is bi-directional so that slicers also filter reviews and payments through the sales table.
- `dim_order` sits between the sales, reviews and payments tables, avoiding a many-to-many relationship (reviews and payments are order-level, sales is item-level).
- A dedicated `dim_date` table, marked as a date table, supports time-intelligence measures.

**Key DAX measures:** Total Revenue, Total Orders, Avg Order Value, Unique Customers, Avg Delivery Days, Late Delivery %, On-Time Delivery %, Avg Review Score, Revenue MoM %, Revenue YTD, Repeat Customer %.

---

## Dashboard

### Page 1: Executive Overview
![Page 1](images/dashboard_page1.png)

### Page 2: Customers and Geography
![Page 2](images/dashboard_page2.png)

### Page 3: Delivery and Satisfaction
![Page 3](images/dashboard_page3.png)

---

## Key Findings

**Business size**
- **R$13.22M** in revenue from **96,478 delivered orders** and **93,358 unique customers**, with an average order value of **R$137.04**.
- 97% of orders are delivered, so fulfilment is healthy.

**Growth**
- Monthly revenue grew steadily through 2017, from about R$112K in January to R$489K in May, and peaked at about R$1.0M in **November 2017 (Black Friday)**, then plateaued through 2018.

**Products**
- **health_beauty** leads on revenue (R$1.23M), followed by watches_gifts (R$1.17M) and bed_bath_table (R$1.02M).
- watches_gifts earns more than bed_bath_table with far fewer orders (5,495 vs 9,272) because its average order is much higher. High-value categories matter more than order volume.

**Geography**
- **São Paulo alone brings about 38% of revenue** (R$5.07M), and SP, RJ and MG together make up about **63%**. The business is heavily concentrated in the Southeast.

**Payments**
- Credit card makes up about **78%** of money paid, with customers splitting purchases into **3.5 instalments** on average. Boleto (bank slip) is next at about 18%.

**Customer retention**
- **97% of customers bought only once** (90,557 of 93,358). Only 3% (2,801) came back.

**Delivery and satisfaction**
- Average delivery takes about 12 days, and 93% of orders arrive on time.
- **Late deliveries score about 2 points lower in reviews** (roughly 2.3 stars vs 4.3 for on-time orders).
- Remote northern states are slowest (RR about 29 days, AP 26.7, AM 26.0 vs about 8 in SP). Late rates tell a different story: AP (3.0%) and AM (2.8%) are rarely late because their estimates are generous, while AL (21.4%) and MA (17.4%) miss their estimates often. **Estimate accuracy matters as much as raw speed.**

---

## Business Recommendations

1. **Focus on retention.** With 97% one-time buyers, small gains in repeat purchases would add revenue without new acquisition cost (loyalty offers, follow-up campaigns, post-delivery re-engagement).
2. **Fix delivery reliability.** Late deliveries cut review scores by about 2 points. Prioritise states with high late rates (AL, MA) and set realistic delivery estimates.
3. **Grow beyond the Southeast.** Revenue depends heavily on SP, RJ and MG. Target other high-population states with logistics improvements.
4. **Promote high-value categories** such as watches_gifts, where each order is worth far more than the average.
5. **Keep instalment options.** Credit card instalments dominate payment behaviour and likely support larger purchases.

---

## Data Notes and Limitations

- Revenue figures use **delivered orders only** and item price (no freight), so they are lower than total payments (about R$16.0M), which include freight and all order statuses.
- Category order counts add up to more than total orders, because an order can contain items from several categories. Payment order counts do too, because some orders use more than one payment method.
- 2016 data is very sparse and November 2016 is missing, so growth rates start from January 2017. The last months of the dataset are also incomplete.
- Some customer and seller zip prefixes do not exist in the geolocation table, so no foreign key links them.
- `customer_unique_id` identifies a person; `customer_id` changes with each order. Repeat-customer analysis uses `customer_unique_id`.

---

## How to Run

1. Download the dataset from [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) and place the CSVs in `data/raw/`.
2. Run `notebooks/01_cleaning.ipynb` to produce the cleaned CSVs.
3. In MySQL, run `sql/schema.sql`, then load the cleaned CSVs (the notebook shows how, using `pandas` and `SQLAlchemy`; set your own password where it says `YOUR_PASSWORD`).
4. Run `sql/views.sql`, then explore `sql/business_queries.sql`.
5. Open `powerbi/olist_dashboard.pbix` in Power BI Desktop. Connect it to your MySQL database (Get Data → MySQL) or point it at CSV exports of the views.

**Requirements:** Python 3 with `pandas`, `sqlalchemy`, `pymysql`; MySQL 8; Power BI Desktop; MySQL Connector/NET (for the live Power BI connection).

---

## Skills Demonstrated

- Data cleaning and validation with pandas
- Relational database design, joins, CTEs, window functions and views in MySQL
- Dimensional modelling (star schema, fact and dimension tables, grain, relationship design)
- DAX measures and time intelligence
- Dashboard design and business storytelling

---

## Author

**Raju Rawat**
[LinkedIn](https://www.linkedin.com/in/raju-rawat-4a6233251/) | [GitHub](https://github.com/rawat2003raju-lab)

# Blinkit Operations Dashboard

A Streamlit dashboard powered by Snowflake, providing real-time operational insights for Blinkit's delivery business.

## Project Structure

```
blinkit_dashboard/
├── .streamlit/
│   └── config.toml              # Snowflake-branded theme
├── setup_database.sql           # DDL + synthetic data for all 4 tables (12.4k rows)
├── setup_data.py                # Python script to execute SQL setup against Snowflake
├── streamlit_app.py             # Streamlit dashboard application
├── requirements.txt             # Python dependencies
├── run.bat                      # One-click Windows launcher
└── .gitignore
```

## Tables & Data

| Table | Rows | Description |
|---|---|---|
| `BLINKIT_ORDERS` | 5,000 | Orders with customer, payment, delivery status, store |
| `BLINKIT_MARKETING_PERFORMANCE` | 5,400 | Daily campaign metrics across 30 campaigns, 6 channels |
| `BLINKIT_DELIVERY_PERFORMANCE` | 1,000 | Delivery timing, distance, delay reasons |
| `BLINKIT_ORDER_ITEMS` | 1,000 | Line items with 120 products across 4 categories |

## Dashboard Features

### KPI Cards
- Total Orders, Revenue, Avg Order Value, Unique Customers, On-Time Delivery %, Blended ROAS

### Sidebar Filters
- Date Range, Delivery Status, Payment Method, Marketing Channel, Store ID

### Tabs
- **Orders** — Daily trend, revenue by payment method, status donut, top stores
- **Delivery** — Status distribution, distance histogram, avg delivery time, delay reasons
- **Marketing** — Channel spend vs revenue, ROAS by channel, daily spend trend, top campaigns
- **Order Items** — Top products by revenue, quantity distribution

## Quick Start

### Option 1: One-click (Windows)
```
run.bat
```

### Option 2: Manual
```bash
pip install -r requirements.txt
python setup_data.py --connection YOUR_CONNECTION_NAME
streamlit run streamlit_app.py
```

## Requirements
- Python 3.10+
- Snowflake account with a configured connection
- Packages: `streamlit`, `snowflake-connector-python`, `altair`, `pandas`, `numpy`

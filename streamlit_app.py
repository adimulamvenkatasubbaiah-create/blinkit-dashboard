"""
Blinkit Operations Dashboard
KPI cards, delivery analytics, marketing performance, and order insights
powered by Snowflake.
"""

from datetime import date, timedelta
import os
import pandas as pd
import streamlit as st
import altair as alt

st.set_page_config(
    page_title="Blinkit Operations Dashboard",
    page_icon=":material/local_shipping:",
    layout="wide",
)

CHART_HEIGHT = 320


# ── Snowflake connection ─────────────────────────────────────────────────────

def get_connection():
    try:
        return st.connection("snowflake")
    except Exception as e:
        st.error(f"Failed to connect to Snowflake: {e}")
        st.stop()


conn = get_connection()


@st.cache_data(ttl=600, show_spinner=False)
def run_query(sql):
    df = conn.query(sql)
    df.columns = df.columns.str.lower()
    return df


# ── Load data ────────────────────────────────────────────────────────────────

@st.cache_data(ttl=600, show_spinner="Loading orders...")
def load_orders():
    return run_query("""
        SELECT ORDER_ID, CUSTOMER_ID, ORDER_DATE, DELIVERY_STATUS,
               ORDER_TOTAL, PAYMENT_METHOD, DELIVERY_PARTNER_ID, STORE_ID
        FROM BLINKIT_DW.RAW.BLINKIT_ORDERS
    """)


@st.cache_data(ttl=600, show_spinner="Loading delivery data...")
def load_delivery():
    return run_query("""
        SELECT ORDER_ID, DELIVERY_PARTNER_ID, PROMISED_TIME, ACTUAL_TIME,
               DELIVERY_TIME_MINUTES, DISTANCE_KM, DELIVERY_STATUS,
               REASONS_IF_DELAYED
        FROM BLINKIT_DW.RAW.BLINKIT_DELIVERY_PERFORMANCE
    """)


@st.cache_data(ttl=600, show_spinner="Loading marketing data...")
def load_marketing():
    return run_query("""
        SELECT CAMPAIGN_ID, CAMPAIGN_NAME, DATE, TARGET_AUDIENCE, CHANNEL,
               IMPRESSIONS, CLICKS, CONVERSIONS, SPEND, REVENUE_GENERATED, ROAS
        FROM BLINKIT_DW.RAW.BLINKIT_MARKETING_PERFORMANCE
    """)


@st.cache_data(ttl=600, show_spinner="Loading order items...")
def load_order_items():
    return run_query("""
        SELECT ORDER_ID, PRODUCT_ID, QUANTITY, UNIT_PRICE, TOTAL_PRICE
        FROM BLINKIT_DW.RAW.BLINKIT_ORDER_ITEMS
    """)


orders_raw = load_orders()
delivery_raw = load_delivery()
marketing_raw = load_marketing()
items_raw = load_order_items()

# Parse dates
orders_raw["order_date"] = pd.to_datetime(orders_raw["order_date"])
marketing_raw["date"] = pd.to_datetime(marketing_raw["date"])


# ── Sidebar filters ──────────────────────────────────────────────────────────

st.sidebar.markdown("## :material/filter_alt: Filters")

# Date range
min_date = orders_raw["order_date"].min().date()
max_date = orders_raw["order_date"].max().date()
date_range = st.sidebar.date_input(
    "Order Date Range",
    value=(min_date, max_date),
    min_value=min_date,
    max_value=max_date,
    key="date_range",
)
if isinstance(date_range, tuple) and len(date_range) == 2:
    start_date, end_date = date_range
else:
    start_date, end_date = min_date, max_date

# Delivery status
all_statuses = sorted(orders_raw["delivery_status"].dropna().unique().tolist())
sel_statuses = st.sidebar.multiselect(
    "Delivery Status", all_statuses, default=all_statuses, key="statuses"
)

# Payment method
all_payments = sorted(orders_raw["payment_method"].dropna().unique().tolist())
sel_payments = st.sidebar.multiselect(
    "Payment Method", all_payments, default=all_payments, key="payments"
)

# Marketing channel
all_channels = sorted(marketing_raw["channel"].dropna().unique().tolist())
sel_channels = st.sidebar.multiselect(
    "Marketing Channel", all_channels, default=all_channels, key="channels"
)

# Store filter
all_stores = sorted(orders_raw["store_id"].dropna().unique().tolist())
sel_stores = st.sidebar.multiselect(
    "Store ID (leave empty for all)", all_stores, default=[], key="stores"
)


# ── Apply filters ────────────────────────────────────────────────────────────

orders = orders_raw[
    (orders_raw["order_date"].dt.date >= start_date)
    & (orders_raw["order_date"].dt.date <= end_date)
    & (orders_raw["delivery_status"].isin(sel_statuses))
    & (orders_raw["payment_method"].isin(sel_payments))
].copy()
if sel_stores:
    orders = orders[orders["store_id"].isin(sel_stores)]

filtered_order_ids = set(orders["order_id"])

delivery = delivery_raw[delivery_raw["order_id"].isin(filtered_order_ids)].copy()
items = items_raw[items_raw["order_id"].isin(filtered_order_ids)].copy()

marketing = marketing_raw[
    (marketing_raw["date"].dt.date >= start_date)
    & (marketing_raw["date"].dt.date <= end_date)
    & (marketing_raw["channel"].isin(sel_channels))
].copy()


# ── Header ───────────────────────────────────────────────────────────────────

with st.container(horizontal=True, horizontal_alignment="distribute", vertical_alignment="center"):
    st.markdown("# :material/local_shipping: Blinkit Operations Dashboard")
    if st.button(":material/restart_alt: Reset Filters", type="tertiary"):
        st.session_state.clear()
        st.rerun()

st.divider()


# ── KPI Row ──────────────────────────────────────────────────────────────────

total_orders = len(orders)
total_revenue = orders["order_total"].sum()
avg_order_value = orders["order_total"].mean() if total_orders > 0 else 0
unique_customers = orders["customer_id"].nunique()

delivered = delivery[delivery["delivery_status"] == "On Time"]
on_time_pct = (len(delivered) / len(delivery) * 100) if len(delivery) > 0 else 0
avg_delivery_min = delivery["delivery_time_minutes"].dropna().mean() if len(delivery) > 0 else 0

total_mkt_spend = marketing["spend"].sum()
total_mkt_revenue = marketing["revenue_generated"].sum()
blended_roas = total_mkt_revenue / total_mkt_spend if total_mkt_spend > 0 else 0

k1, k2, k3, k4, k5, k6 = st.columns(6)
k1.metric("Total Orders", f"{total_orders:,}")
k2.metric("Revenue", f"₹{total_revenue:,.0f}")
k3.metric("Avg Order Value", f"₹{avg_order_value:,.0f}")
k4.metric("Unique Customers", f"{unique_customers:,}")
k5.metric("On-Time Delivery", f"{on_time_pct:.1f}%")
k6.metric("Blended ROAS", f"{blended_roas:.2f}x")

st.divider()


# ── Tab layout ───────────────────────────────────────────────────────────────

tab_orders, tab_delivery, tab_marketing, tab_items = st.tabs(
    [":material/shopping_cart: Orders", ":material/local_shipping: Delivery",
     ":material/campaign: Marketing", ":material/inventory_2: Order Items"]
)


# ── Orders Tab ───────────────────────────────────────────────────────────────

with tab_orders:
    col1, col2 = st.columns(2)

    with col1:
        st.markdown("**Daily Orders Trend**")
        daily = orders.groupby(orders["order_date"].dt.date).agg(
            order_count=("order_id", "count"),
            daily_revenue=("order_total", "sum"),
        ).reset_index()
        daily.columns = ["date", "order_count", "daily_revenue"]
        daily["date"] = pd.to_datetime(daily["date"])

        chart = (
            alt.Chart(daily)
            .mark_area(opacity=0.4, line=True, color="#29B5E8")
            .encode(
                x=alt.X("date:T", title=None),
                y=alt.Y("order_count:Q", title="Orders"),
                tooltip=[
                    alt.Tooltip("date:T", title="Date", format="%Y-%m-%d"),
                    alt.Tooltip("order_count:Q", title="Orders", format=","),
                    alt.Tooltip("daily_revenue:Q", title="Revenue", format="₹,.0f"),
                ],
            )
            .properties(height=CHART_HEIGHT)
        )
        st.altair_chart(chart, use_container_width=True)

    with col2:
        st.markdown("**Revenue by Payment Method**")
        pay_rev = orders.groupby("payment_method")["order_total"].sum().reset_index()
        pay_rev.columns = ["payment_method", "revenue"]
        chart = (
            alt.Chart(pay_rev)
            .mark_bar(cornerRadiusTopLeft=4, cornerRadiusTopRight=4)
            .encode(
                x=alt.X("payment_method:N", title=None, sort="-y"),
                y=alt.Y("revenue:Q", title="Revenue (₹)"),
                color=alt.Color("payment_method:N", legend=None,
                                scale=alt.Scale(scheme="tableau10")),
                tooltip=[
                    alt.Tooltip("payment_method:N", title="Method"),
                    alt.Tooltip("revenue:Q", title="Revenue", format="₹,.0f"),
                ],
            )
            .properties(height=CHART_HEIGHT)
        )
        st.altair_chart(chart, use_container_width=True)

    col3, col4 = st.columns(2)

    with col3:
        st.markdown("**Order Status Breakdown**")
        status_counts = orders["delivery_status"].value_counts().reset_index()
        status_counts.columns = ["status", "count"]
        chart = (
            alt.Chart(status_counts)
            .mark_arc(innerRadius=60, cornerRadius=4)
            .encode(
                theta=alt.Theta("count:Q"),
                color=alt.Color("status:N", title="Status",
                                scale=alt.Scale(
                                    domain=["Delivered", "Cancelled", "Returned", "In Transit"],
                                    range=["#29B5E8", "#FF6B6B", "#FFA94D", "#95DE64"]
                                )),
                tooltip=[
                    alt.Tooltip("status:N", title="Status"),
                    alt.Tooltip("count:Q", title="Orders", format=","),
                ],
            )
            .properties(height=CHART_HEIGHT)
        )
        st.altair_chart(chart, use_container_width=True)

    with col4:
        st.markdown("**Top 10 Stores by Order Volume**")
        top_stores = orders.groupby("store_id")["order_id"].count().nlargest(10).reset_index()
        top_stores.columns = ["store_id", "orders"]
        top_stores["store_id"] = top_stores["store_id"].astype(str)
        chart = (
            alt.Chart(top_stores)
            .mark_bar(cornerRadiusTopLeft=4, cornerRadiusTopRight=4, color="#29B5E8")
            .encode(
                x=alt.X("store_id:N", title="Store", sort="-y"),
                y=alt.Y("orders:Q", title="Order Count"),
                tooltip=[
                    alt.Tooltip("store_id:N", title="Store"),
                    alt.Tooltip("orders:Q", title="Orders", format=","),
                ],
            )
            .properties(height=CHART_HEIGHT)
        )
        st.altair_chart(chart, use_container_width=True)


# ── Delivery Tab ─────────────────────────────────────────────────────────────

with tab_delivery:
    if delivery.empty:
        st.info("No delivery data for the selected filters.")
    else:
        col1, col2 = st.columns(2)

        with col1:
            st.markdown("**Delivery Status Distribution**")
            del_status = delivery["delivery_status"].value_counts().reset_index()
            del_status.columns = ["status", "count"]
            chart = (
                alt.Chart(del_status)
                .mark_arc(innerRadius=60, cornerRadius=4)
                .encode(
                    theta=alt.Theta("count:Q"),
                    color=alt.Color("status:N", title="Status",
                                    scale=alt.Scale(
                                        domain=["On Time", "Delayed", "Cancelled", "Returned", "In Transit"],
                                        range=["#29B5E8", "#FF6B6B", "#FFA94D", "#95DE64", "#B37FEB"]
                                    )),
                    tooltip=[
                        alt.Tooltip("status:N", title="Status"),
                        alt.Tooltip("count:Q", title="Count", format=","),
                    ],
                )
                .properties(height=CHART_HEIGHT)
            )
            st.altair_chart(chart, use_container_width=True)

        with col2:
            st.markdown("**Delivery Distance Distribution (km)**")
            chart = (
                alt.Chart(delivery)
                .mark_bar(cornerRadiusTopLeft=3, cornerRadiusTopRight=3, color="#29B5E8")
                .encode(
                    x=alt.X("distance_km:Q", bin=alt.Bin(maxbins=20), title="Distance (km)"),
                    y=alt.Y("count():Q", title="Deliveries"),
                    tooltip=[
                        alt.Tooltip("distance_km:Q", bin=alt.Bin(maxbins=20), title="Distance Range"),
                        alt.Tooltip("count():Q", title="Count"),
                    ],
                )
                .properties(height=CHART_HEIGHT)
            )
            st.altair_chart(chart, use_container_width=True)

        col3, col4 = st.columns(2)

        with col3:
            st.markdown("**Avg Delivery Time by Status (minutes)**")
            del_time = delivery.groupby("delivery_status")["delivery_time_minutes"].mean().dropna().reset_index()
            del_time.columns = ["status", "avg_minutes"]
            del_time["avg_minutes"] = del_time["avg_minutes"].round(1)
            chart = (
                alt.Chart(del_time)
                .mark_bar(cornerRadiusTopLeft=4, cornerRadiusTopRight=4)
                .encode(
                    x=alt.X("status:N", title=None),
                    y=alt.Y("avg_minutes:Q", title="Avg Minutes"),
                    color=alt.Color("status:N", legend=None, scale=alt.Scale(scheme="tableau10")),
                    tooltip=[
                        alt.Tooltip("status:N", title="Status"),
                        alt.Tooltip("avg_minutes:Q", title="Avg Min", format=".1f"),
                    ],
                )
                .properties(height=CHART_HEIGHT)
            )
            st.altair_chart(chart, use_container_width=True)

        with col4:
            st.markdown("**Top Delay Reasons**")
            delayed = delivery[delivery["reasons_if_delayed"].notna()]
            if delayed.empty:
                st.info("No delayed deliveries in selection.")
            else:
                reasons = delayed["reasons_if_delayed"].value_counts().reset_index()
                reasons.columns = ["reason", "count"]
                chart = (
                    alt.Chart(reasons)
                    .mark_bar(cornerRadiusEnd=4, color="#FF6B6B")
                    .encode(
                        y=alt.Y("reason:N", title=None, sort="-x"),
                        x=alt.X("count:Q", title="Occurrences"),
                        tooltip=[
                            alt.Tooltip("reason:N", title="Reason"),
                            alt.Tooltip("count:Q", title="Count", format=","),
                        ],
                    )
                    .properties(height=CHART_HEIGHT)
                )
                st.altair_chart(chart, use_container_width=True)


# ── Marketing Tab ────────────────────────────────────────────────────────────

with tab_marketing:
    if marketing.empty:
        st.info("No marketing data for the selected filters.")
    else:
        mk1, mk2, mk3, mk4 = st.columns(4)
        mk1.metric("Total Spend", f"₹{marketing['spend'].sum():,.0f}")
        mk2.metric("Total Revenue", f"₹{marketing['revenue_generated'].sum():,.0f}")
        mk3.metric("Total Conversions", f"{marketing['conversions'].sum():,}")
        avg_ctr = (marketing["clicks"].sum() / marketing["impressions"].sum() * 100) if marketing["impressions"].sum() > 0 else 0
        mk4.metric("Avg CTR", f"{avg_ctr:.2f}%")

        st.markdown("")
        col1, col2 = st.columns(2)

        with col1:
            st.markdown("**Channel Performance — Spend vs Revenue**")
            chan_perf = marketing.groupby("channel").agg(
                spend=("spend", "sum"),
                revenue=("revenue_generated", "sum"),
            ).reset_index()
            melted = chan_perf.melt(id_vars=["channel"], value_vars=["spend", "revenue"],
                                    var_name="metric", value_name="amount")
            chart = (
                alt.Chart(melted)
                .mark_bar(cornerRadiusTopLeft=4, cornerRadiusTopRight=4)
                .encode(
                    x=alt.X("channel:N", title=None),
                    y=alt.Y("amount:Q", title="Amount (₹)"),
                    color=alt.Color("metric:N", title=None,
                                    scale=alt.Scale(domain=["spend", "revenue"],
                                                    range=["#FF6B6B", "#29B5E8"])),
                    xOffset="metric:N",
                    tooltip=[
                        alt.Tooltip("channel:N", title="Channel"),
                        alt.Tooltip("metric:N", title="Metric"),
                        alt.Tooltip("amount:Q", title="Amount", format="₹,.0f"),
                    ],
                )
                .properties(height=CHART_HEIGHT)
            )
            st.altair_chart(chart, use_container_width=True)

        with col2:
            st.markdown("**ROAS by Channel**")
            chan_roas = marketing.groupby("channel").agg(
                spend=("spend", "sum"),
                revenue=("revenue_generated", "sum"),
            ).reset_index()
            chan_roas["roas"] = (chan_roas["revenue"] / chan_roas["spend"]).round(2)
            chart = (
                alt.Chart(chan_roas)
                .mark_bar(cornerRadiusTopLeft=4, cornerRadiusTopRight=4, color="#29B5E8")
                .encode(
                    x=alt.X("channel:N", title=None, sort="-y"),
                    y=alt.Y("roas:Q", title="ROAS"),
                    tooltip=[
                        alt.Tooltip("channel:N", title="Channel"),
                        alt.Tooltip("roas:Q", title="ROAS", format=".2f"),
                    ],
                )
                .properties(height=CHART_HEIGHT)
            )
            st.altair_chart(chart, use_container_width=True)

        col3, col4 = st.columns(2)

        with col3:
            st.markdown("**Daily Marketing Spend Trend**")
            daily_mkt = marketing.groupby(marketing["date"].dt.date)["spend"].sum().reset_index()
            daily_mkt.columns = ["date", "spend"]
            daily_mkt["date"] = pd.to_datetime(daily_mkt["date"])
            chart = (
                alt.Chart(daily_mkt)
                .mark_area(opacity=0.4, line=True, color="#FF6B6B")
                .encode(
                    x=alt.X("date:T", title=None),
                    y=alt.Y("spend:Q", title="Spend (₹)"),
                    tooltip=[
                        alt.Tooltip("date:T", title="Date", format="%Y-%m-%d"),
                        alt.Tooltip("spend:Q", title="Spend", format="₹,.0f"),
                    ],
                )
                .properties(height=CHART_HEIGHT)
            )
            st.altair_chart(chart, use_container_width=True)

        with col4:
            st.markdown("**Top 10 Campaigns by ROAS**")
            camp_roas = marketing.groupby("campaign_name").agg(
                spend=("spend", "sum"),
                revenue=("revenue_generated", "sum"),
            ).reset_index()
            camp_roas["roas"] = (camp_roas["revenue"] / camp_roas["spend"]).round(2)
            top_camps = camp_roas.nlargest(10, "roas")
            chart = (
                alt.Chart(top_camps)
                .mark_bar(cornerRadiusEnd=4, color="#29B5E8")
                .encode(
                    y=alt.Y("campaign_name:N", title=None, sort="-x"),
                    x=alt.X("roas:Q", title="ROAS"),
                    tooltip=[
                        alt.Tooltip("campaign_name:N", title="Campaign"),
                        alt.Tooltip("roas:Q", title="ROAS", format=".2f"),
                        alt.Tooltip("spend:Q", title="Spend", format="₹,.0f"),
                        alt.Tooltip("revenue:Q", title="Revenue", format="₹,.0f"),
                    ],
                )
                .properties(height=CHART_HEIGHT)
            )
            st.altair_chart(chart, use_container_width=True)


# ── Order Items Tab ──────────────────────────────────────────────────────────

with tab_items:
    if items.empty:
        st.info("No order items for the selected filters.")
    else:
        it1, it2, it3 = st.columns(3)
        it1.metric("Total Line Items", f"{len(items):,}")
        it2.metric("Avg Quantity/Item", f"{items['quantity'].mean():.1f}")
        it3.metric("Avg Line Value", f"₹{items['total_price'].mean():,.0f}")

        st.markdown("")
        col1, col2 = st.columns(2)

        with col1:
            st.markdown("**Top 15 Products by Revenue**")
            prod_rev = items.groupby("product_id")["total_price"].sum().nlargest(15).reset_index()
            prod_rev.columns = ["product_id", "revenue"]
            prod_rev["product_id"] = prod_rev["product_id"].astype(str)
            chart = (
                alt.Chart(prod_rev)
                .mark_bar(cornerRadiusEnd=4, color="#29B5E8")
                .encode(
                    y=alt.Y("product_id:N", title="Product ID", sort="-x"),
                    x=alt.X("revenue:Q", title="Revenue (₹)"),
                    tooltip=[
                        alt.Tooltip("product_id:N", title="Product"),
                        alt.Tooltip("revenue:Q", title="Revenue", format="₹,.0f"),
                    ],
                )
                .properties(height=CHART_HEIGHT + 60)
            )
            st.altair_chart(chart, use_container_width=True)

        with col2:
            st.markdown("**Quantity Distribution**")
            qty_dist = items["quantity"].value_counts().reset_index()
            qty_dist.columns = ["quantity", "count"]
            qty_dist = qty_dist.sort_values("quantity")
            qty_dist["quantity"] = qty_dist["quantity"].astype(str)
            chart = (
                alt.Chart(qty_dist)
                .mark_bar(cornerRadiusTopLeft=4, cornerRadiusTopRight=4, color="#29B5E8")
                .encode(
                    x=alt.X("quantity:N", title="Quantity per Line", sort=None),
                    y=alt.Y("count:Q", title="Frequency"),
                    tooltip=[
                        alt.Tooltip("quantity:N", title="Qty"),
                        alt.Tooltip("count:Q", title="Count", format=","),
                    ],
                )
                .properties(height=CHART_HEIGHT + 60)
            )
            st.altair_chart(chart, use_container_width=True)


# ── Footer ───────────────────────────────────────────────────────────────────
st.divider()
st.caption(f"Data from BLINKIT_DW.RAW • {total_orders:,} orders loaded • Powered by Snowflake")

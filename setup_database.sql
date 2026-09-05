-- =============================================================================
-- Blinkit Data Warehouse — Full Setup Script
-- Creates database, schema, all 4 tables, and inserts synthetic data.
-- Run this once in Snowflake (Snowsight or SnowSQL) to bootstrap everything.
-- =============================================================================

-- ── Database & Schema ───────────────────────────────────────────────────────

CREATE DATABASE IF NOT EXISTS BLINKIT_DW;
CREATE SCHEMA IF NOT EXISTS BLINKIT_DW.RAW;

USE SCHEMA BLINKIT_DW.RAW;


-- ═══════════════════════════════════════════════════════════════════════════
-- TABLE 1: BLINKIT_ORDERS  (5,000 rows)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE TABLE BLINKIT_DW.RAW.BLINKIT_ORDERS (
    ORDER_ID         NUMBER(12,0) NOT NULL PRIMARY KEY,
    CUSTOMER_ID      NUMBER(12,0),
    ORDER_DATE       TIMESTAMP_NTZ(9),
    PROMISED_DELIVERY_TIME TIMESTAMP_NTZ(9),
    ACTUAL_DELIVERY_TIME   TIMESTAMP_NTZ(9),
    DELIVERY_STATUS  VARCHAR(50),
    ORDER_TOTAL      NUMBER(10,2),
    PAYMENT_METHOD   VARCHAR(50),
    DELIVERY_PARTNER_ID NUMBER(12,0),
    STORE_ID         NUMBER(12,0)
);

INSERT INTO BLINKIT_DW.RAW.BLINKIT_ORDERS
(ORDER_ID, CUSTOMER_ID, ORDER_DATE, PROMISED_DELIVERY_TIME, ACTUAL_DELIVERY_TIME,
 DELIVERY_STATUS, ORDER_TOTAL, PAYMENT_METHOD, DELIVERY_PARTNER_ID, STORE_ID)
WITH gen AS (
  SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) AS rn,
    ABS(HASH(SEQ4()))           AS h0,
    ABS(HASH(SEQ4() + 100000)) AS h1,
    ABS(HASH(SEQ4() + 200000)) AS h2,
    ABS(HASH(SEQ4() + 300000)) AS h3,
    ABS(HASH(SEQ4() + 400000)) AS h4,
    ABS(HASH(SEQ4() + 500000)) AS h5,
    ABS(HASH(SEQ4() + 600000)) AS h6,
    ABS(HASH(SEQ4() + 700000)) AS h7,
    ABS(HASH(SEQ4() + 800000)) AS h8
  FROM TABLE(GENERATOR(ROWCOUNT => 5000))
),
base AS (
  SELECT
    rn AS ORDER_ID,
    MOD(h0, 2000) + 1 AS CUSTOMER_ID,
    DATEADD('minute', -1 * MOD(h1, 259200), '2026-09-04 23:59:59'::TIMESTAMP_NTZ) AS ORDER_DATE,
    MOD(h2, 13) + 8 AS promise_min,
    MOD(h3, 100) + 1 AS status_roll,
    ROUND(49 + (MOD(h4, 10000) / 10000.0) * 2950, 2) AS ORDER_TOTAL,
    MOD(h5, 100) + 1 AS pay_roll,
    MOD(h6, 150) + 1 AS DELIVERY_PARTNER_ID,
    MOD(h7, 80) + 1 AS STORE_ID,
    MOD(h8, 14) - 5 AS delivery_offset
  FROM gen
)
SELECT
  ORDER_ID, CUSTOMER_ID, ORDER_DATE,
  DATEADD('minute', promise_min, ORDER_DATE) AS PROMISED_DELIVERY_TIME,
  CASE
    WHEN status_roll <= 85 THEN DATEADD('minute', promise_min + delivery_offset, ORDER_DATE)
    ELSE NULL
  END AS ACTUAL_DELIVERY_TIME,
  CASE
    WHEN status_roll <= 85 THEN 'Delivered'
    WHEN status_roll <= 87 THEN 'In Transit'
    WHEN status_roll <= 93 THEN 'Cancelled'
    ELSE 'Returned'
  END AS DELIVERY_STATUS,
  ORDER_TOTAL,
  CASE
    WHEN pay_roll <= 40 THEN 'UPI'
    WHEN pay_roll <= 60 THEN 'Credit Card'
    WHEN pay_roll <= 75 THEN 'Debit Card'
    WHEN pay_roll <= 85 THEN 'Net Banking'
    WHEN pay_roll <= 92 THEN 'Wallet'
    ELSE 'Cash on Delivery'
  END AS PAYMENT_METHOD,
  DELIVERY_PARTNER_ID,
  STORE_ID
FROM base;


-- ═══════════════════════════════════════════════════════════════════════════
-- TABLE 2: BLINKIT_MARKETING_PERFORMANCE  (5,400 rows)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE TABLE BLINKIT_DW.RAW.BLINKIT_MARKETING_PERFORMANCE (
    CAMPAIGN_ID      NUMBER(12,0),
    CAMPAIGN_NAME    VARCHAR(100),
    DATE             DATE,
    TARGET_AUDIENCE  VARCHAR(50),
    CHANNEL          VARCHAR(50),
    IMPRESSIONS      NUMBER(10,0),
    CLICKS           NUMBER(10,0),
    CONVERSIONS      NUMBER(10,0),
    SPEND            NUMBER(12,2),
    REVENUE_GENERATED NUMBER(12,2),
    ROAS             NUMBER(6,2)
);

INSERT INTO BLINKIT_DW.RAW.BLINKIT_MARKETING_PERFORMANCE
(CAMPAIGN_ID, CAMPAIGN_NAME, DATE, TARGET_AUDIENCE, CHANNEL, IMPRESSIONS, CLICKS, CONVERSIONS, SPEND, REVENUE_GENERATED, ROAS)
WITH
campaigns AS (
  SELECT c.id AS CAMPAIGN_ID, c.name AS CAMPAIGN_NAME, c.audience AS TARGET_AUDIENCE, c.channel AS CHANNEL,
         c.imp_base, c.ctr_base, c.cvr_base, c.cpc_base, c.aov_base
  FROM (
    SELECT * FROM VALUES
    (1001,'Grocery Essentials Push','Families 25-45','Google Ads',50000,0.028,0.045,8.50,620),
    (1002,'Fresh Fruits Promo','Health Conscious 18-35','Instagram',35000,0.035,0.038,5.20,480),
    (1003,'Late Night Cravings','Young Adults 18-28','YouTube',28000,0.022,0.032,12.00,550),
    (1004,'Weekend Feast Sale','Families 30-50','Facebook',42000,0.031,0.041,7.80,710),
    (1005,'Office Snack Box','Working Professionals 25-40','Google Ads',30000,0.026,0.036,9.20,520),
    (1006,'Baby Care Basics','New Parents 25-40','Facebook',22000,0.033,0.050,6.50,850),
    (1007,'Pet Food Express','Pet Owners 22-45','Instagram',18000,0.029,0.042,7.00,620),
    (1008,'Monsoon Essentials','All Ages 18-55','Push Notification',60000,0.042,0.055,2.10,480),
    (1009,'Dairy Fresh Daily','Families 25-50','Email',45000,0.038,0.048,1.80,390),
    (1010,'Instant Noodles Mania','Students 18-25','YouTube',40000,0.025,0.030,10.50,320),
    (1011,'Premium Organic Range','HNI 30-55','Google Ads',15000,0.020,0.035,14.00,1200),
    (1012,'Summer Coolers','All Ages 18-40','Instagram',38000,0.034,0.040,5.80,410),
    (1013,'Diwali Mega Sale','Families 25-55','Facebook',70000,0.037,0.052,6.20,780),
    (1014,'Protein & Fitness','Fitness Enthusiasts 20-38','YouTube',25000,0.024,0.033,11.00,720),
    (1015,'Kitchen Staples Refill','Homemakers 28-50','Push Notification',55000,0.040,0.058,2.30,540),
    (1016,'Breakfast Combos','Working Professionals 22-40','Email',32000,0.036,0.044,2.00,380),
    (1017,'Beverage Bonanza','Young Adults 18-30','Instagram',33000,0.032,0.036,6.00,350),
    (1018,'Holi Color Party','Students 18-28','Facebook',48000,0.030,0.039,7.20,420),
    (1019,'Winter Warmers','Families 30-55','Google Ads',26000,0.023,0.037,10.00,650),
    (1020,'Beauty & Personal Care','Women 20-40','Instagram',20000,0.036,0.043,5.50,580),
    (1021,'Midnight Delivery Blitz','Night Owls 18-30','Push Notification',50000,0.044,0.048,1.90,390),
    (1022,'Sunday Brunch Basket','Couples 25-40','Email',28000,0.035,0.046,2.20,520),
    (1023,'Back to School','Parents 30-45','Facebook',35000,0.028,0.040,7.50,600),
    (1024,'Festive Dry Fruits','HNI 35-60','Google Ads',12000,0.019,0.032,15.00,1400),
    (1025,'Quick Meds Delivery','All Ages 25-60','Push Notification',40000,0.039,0.052,2.50,680),
    (1026,'Ice Cream Festival','Families 20-45','YouTube',30000,0.027,0.034,9.80,370),
    (1027,'Cleaning Supplies Restock','Homemakers 25-50','Email',38000,0.034,0.045,1.70,410),
    (1028,'Rakhi Gift Hampers','Siblings 18-40','Facebook',45000,0.033,0.047,6.80,750),
    (1029,'Exotic Imports','Foodies 25-45','Instagram',14000,0.021,0.029,8.50,950),
    (1030,'New User Welcome Offer','New Users 18-35','Google Ads',55000,0.040,0.060,6.00,500)
  AS t(id, name, audience, channel, imp_base, ctr_base, cvr_base, cpc_base, aov_base)
  ) c
),
days AS (
  SELECT DATEADD('day', ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1, '2026-03-09'::DATE) AS dt
  FROM TABLE(GENERATOR(ROWCOUNT => 180))
),
crossed AS (
  SELECT
    c.*, d.dt,
    ROW_NUMBER() OVER (ORDER BY c.CAMPAIGN_ID, d.dt) AS rn,
    ABS(HASH(c.CAMPAIGN_ID * 10000 + DATEDIFF('day','2026-03-09',d.dt)))            AS h0,
    ABS(HASH(c.CAMPAIGN_ID * 10000 + DATEDIFF('day','2026-03-09',d.dt) + 100000))   AS h1,
    ABS(HASH(c.CAMPAIGN_ID * 10000 + DATEDIFF('day','2026-03-09',d.dt) + 200000))   AS h2,
    ABS(HASH(c.CAMPAIGN_ID * 10000 + DATEDIFF('day','2026-03-09',d.dt) + 300000))   AS h3,
    CASE WHEN DAYOFWEEK(d.dt) IN (0, 6) THEN 1.20 ELSE 1.0 END AS wknd_mult,
    1.0 + (DATEDIFF('day','2026-03-09',d.dt) / 180.0) * 0.15 AS growth_mult
  FROM campaigns c CROSS JOIN days d
),
trimmed AS (
  SELECT * FROM crossed WHERE rn <= 5400
),
metrics AS (
  SELECT
    CAMPAIGN_ID, CAMPAIGN_NAME, dt AS DATE, TARGET_AUDIENCE, CHANNEL,
    GREATEST(500, ROUND(imp_base * wknd_mult * growth_mult * (0.70 + (MOD(h0, 6000) / 10000.0)))) AS IMPRESSIONS,
    ctr_base * (0.75 + (MOD(h1, 5000) / 10000.0)) AS eff_ctr,
    cvr_base * (0.70 + (MOD(h2, 6000) / 10000.0)) AS eff_cvr,
    cpc_base * (0.85 + (MOD(h3, 3000) / 10000.0)) AS eff_cpc,
    aov_base
  FROM trimmed
)
SELECT
  CAMPAIGN_ID, CAMPAIGN_NAME, DATE, TARGET_AUDIENCE, CHANNEL,
  IMPRESSIONS::NUMBER(10,0) AS IMPRESSIONS,
  GREATEST(1, ROUND(IMPRESSIONS * eff_ctr))::NUMBER(10,0) AS CLICKS,
  GREATEST(0, ROUND(IMPRESSIONS * eff_ctr * eff_cvr))::NUMBER(10,0) AS CONVERSIONS,
  ROUND(ROUND(IMPRESSIONS * eff_ctr) * eff_cpc, 2) AS SPEND,
  ROUND(ROUND(IMPRESSIONS * eff_ctr * eff_cvr) * aov_base, 2) AS REVENUE_GENERATED,
  CASE
    WHEN ROUND(ROUND(IMPRESSIONS * eff_ctr) * eff_cpc, 2) > 0
    THEN ROUND(ROUND(ROUND(IMPRESSIONS * eff_ctr * eff_cvr) * aov_base, 2) /
               ROUND(ROUND(IMPRESSIONS * eff_ctr) * eff_cpc, 2), 2)
    ELSE 0
  END AS ROAS
FROM metrics;


-- ═══════════════════════════════════════════════════════════════════════════
-- TABLE 3: BLINKIT_DELIVERY_PERFORMANCE  (1,000 rows)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE TABLE BLINKIT_DW.RAW.BLINKIT_DELIVERY_PERFORMANCE (
    ORDER_ID             NUMBER(12,0) NOT NULL PRIMARY KEY,
    DELIVERY_PARTNER_ID  NUMBER(12,0),
    PROMISED_TIME        TIMESTAMP_NTZ(9),
    ACTUAL_TIME          TIMESTAMP_NTZ(9),
    DELIVERY_TIME_MINUTES NUMBER(6,2) AS (CAST(DATEDIFF('MINUTE', PROMISED_TIME, ACTUAL_TIME) AS NUMBER(6,2))),
    DISTANCE_KM          NUMBER(6,2),
    DELIVERY_STATUS      VARCHAR(50),
    REASONS_IF_DELAYED   VARCHAR(200)
);

INSERT INTO BLINKIT_DW.RAW.BLINKIT_DELIVERY_PERFORMANCE
(ORDER_ID, DELIVERY_PARTNER_ID, PROMISED_TIME, ACTUAL_TIME, DISTANCE_KM, DELIVERY_STATUS, REASONS_IF_DELAYED)
WITH src AS (
  SELECT
    o.ORDER_ID, o.DELIVERY_PARTNER_ID,
    o.PROMISED_DELIVERY_TIME, o.ACTUAL_DELIVERY_TIME,
    o.DELIVERY_STATUS AS ord_status,
    ABS(HASH(o.ORDER_ID * 7 + 1)) AS h0,
    ABS(HASH(o.ORDER_ID * 7 + 2)) AS h1
  FROM BLINKIT_DW.RAW.BLINKIT_ORDERS o
  WHERE o.ORDER_ID <= 1000
)
SELECT
  ORDER_ID, DELIVERY_PARTNER_ID,
  PROMISED_DELIVERY_TIME AS PROMISED_TIME,
  CASE
    WHEN ord_status = 'Delivered' THEN ACTUAL_DELIVERY_TIME
    ELSE NULL
  END AS ACTUAL_TIME,
  ROUND(0.5 + (MOD(h0, 7500) / 1000.0), 2) AS DISTANCE_KM,
  CASE
    WHEN ord_status = 'Delivered' AND ACTUAL_DELIVERY_TIME <= PROMISED_DELIVERY_TIME THEN 'On Time'
    WHEN ord_status = 'Delivered' AND ACTUAL_DELIVERY_TIME > PROMISED_DELIVERY_TIME THEN 'Delayed'
    WHEN ord_status = 'Cancelled' THEN 'Cancelled'
    WHEN ord_status = 'Returned' THEN 'Returned'
    ELSE 'In Transit'
  END AS DELIVERY_STATUS,
  CASE
    WHEN ord_status = 'Delivered' AND ACTUAL_DELIVERY_TIME > PROMISED_DELIVERY_TIME THEN
      CASE MOD(h1, 8)
        WHEN 0 THEN 'Heavy traffic on route'
        WHEN 1 THEN 'High order volume at store'
        WHEN 2 THEN 'Rider got delayed at previous delivery'
        WHEN 3 THEN 'Rain/bad weather conditions'
        WHEN 4 THEN 'Customer address hard to locate'
        WHEN 5 THEN 'Item out of stock - replacement needed'
        WHEN 6 THEN 'Store packing delay'
        ELSE 'Vehicle breakdown en route'
      END
    ELSE NULL
  END AS REASONS_IF_DELAYED
FROM src;


-- ═══════════════════════════════════════════════════════════════════════════
-- TABLE 4: BLINKIT_ORDER_ITEMS  (1,000 rows)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE TABLE BLINKIT_DW.RAW.BLINKIT_ORDER_ITEMS (
    ORDER_ID    NUMBER(12,0) NOT NULL,
    PRODUCT_ID  NUMBER(12,0) NOT NULL,
    QUANTITY    NUMBER(10,0),
    UNIT_PRICE  NUMBER(10,2),
    TOTAL_PRICE NUMBER(20,2) AS (CAST(QUANTITY AS NUMBER(10,0)) * CAST(UNIT_PRICE AS NUMBER(10,2))),
    PRIMARY KEY (ORDER_ID, PRODUCT_ID)
);

INSERT INTO BLINKIT_DW.RAW.BLINKIT_ORDER_ITEMS
(ORDER_ID, PRODUCT_ID, QUANTITY, UNIT_PRICE)
WITH
orders_pool AS (
  SELECT ORDER_ID, ABS(HASH(ORDER_ID * 13 + 99)) AS h_items
  FROM BLINKIT_DW.RAW.BLINKIT_ORDERS WHERE ORDER_ID <= 500
),
order_items AS (
  SELECT ORDER_ID,
    CASE
      WHEN MOD(h_items, 100) < 20 THEN 1
      WHEN MOD(h_items, 100) < 55 THEN 2
      WHEN MOD(h_items, 100) < 85 THEN 3
      ELSE 4
    END AS item_count
  FROM orders_pool
),
with_running AS (
  SELECT ORDER_ID, item_count,
    SUM(item_count) OVER (ORDER BY ORDER_ID) AS running_total
  FROM order_items
),
capped AS (
  SELECT ORDER_ID, item_count FROM with_running WHERE running_total <= 1000
),
expanded AS (
  SELECT c.ORDER_ID,
    ROW_NUMBER() OVER (PARTITION BY c.ORDER_ID ORDER BY g.seq) AS line_num
  FROM capped c
  CROSS JOIN (
    SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) AS seq FROM TABLE(GENERATOR(ROWCOUNT => 4))
  ) g
  WHERE g.seq <= c.item_count
),
product_pool AS (
  SELECT * FROM VALUES
    (1001,45.00),(1002,62.00),(1003,30.00),(1004,155.00),(1005,28.00),
    (1006,90.00),(1007,120.00),(1008,35.00),(1009,55.00),(1010,199.00),
    (1011,25.00),(1012,40.00),(1013,85.00),(1014,75.00),(1015,110.00),
    (1016,15.00),(1017,22.00),(1018,180.00),(1019,48.00),(1020,65.00),
    (1021,32.00),(1022,95.00),(1023,140.00),(1024,20.00),(1025,58.00),
    (1026,42.00),(1027,78.00),(1028,125.00),(1029,38.00),(1030,210.00),
    (1031,35.00),(1032,50.00),(1033,99.00),(1034,25.00),(1035,150.00),
    (1036,45.00),(1037,70.00),(1038,30.00),(1039,85.00),(1040,120.00),
    (1041,18.00),(1042,55.00),(1043,40.00),(1044,160.00),(1045,22.00),
    (1046,75.00),(1047,95.00),(1048,28.00),(1049,110.00),(1050,60.00),
    (1051,42.00),(1052,130.00),(1053,35.00),(1054,88.00),(1055,15.00),
    (1056,65.00),(1057,48.00),(1058,175.00),(1059,52.00),(1060,80.00),
    (1061,49.00),(1062,69.00),(1063,39.00),(1064,89.00),(1065,29.00),
    (1066,59.00),(1067,119.00),(1068,35.00),(1069,79.00),(1070,45.00),
    (1071,55.00),(1072,99.00),(1073,25.00),(1074,149.00),(1075,42.00),
    (1076,65.00),(1077,32.00),(1078,85.00),(1079,72.00),(1080,110.00),
    (1081,38.00),(1082,58.00),(1083,95.00),(1084,28.00),(1085,135.00),
    (1086,48.00),(1087,75.00),(1088,22.00),(1089,105.00),(1090,62.00),
    (1091,189.00),(1092,75.00),(1093,245.00),(1094,120.00),(1095,55.00),
    (1096,165.00),(1097,85.00),(1098,310.00),(1099,42.00),(1100,199.00),
    (1101,68.00),(1102,145.00),(1103,92.00),(1104,225.00),(1105,38.00),
    (1106,155.00),(1107,110.00),(1108,280.00),(1109,65.00),(1110,175.00),
    (1111,95.00),(1112,130.00),(1113,58.00),(1114,210.00),(1115,82.00),
    (1116,145.00),(1117,48.00),(1118,195.00),(1119,72.00),(1120,260.00)
  AS t(pid, price)
)
SELECT
  e.ORDER_ID,
  p.pid AS PRODUCT_ID,
  CASE MOD(ABS(HASH(e.ORDER_ID * 100 + e.line_num + 777)), 10)
    WHEN 0 THEN 4 WHEN 1 THEN 3 WHEN 2 THEN 3 WHEN 3 THEN 2
    WHEN 4 THEN 2 WHEN 5 THEN 2 ELSE 1
  END AS QUANTITY,
  p.price AS UNIT_PRICE
FROM expanded e
JOIN (SELECT pid, price, ROW_NUMBER() OVER (ORDER BY pid) AS rn FROM product_pool) p
  ON p.rn = MOD(ABS(HASH(e.ORDER_ID * 100 + e.line_num)), 120) + 1;


-- ═══════════════════════════════════════════════════════════════════════════
-- Verification
-- ═══════════════════════════════════════════════════════════════════════════

SELECT 'BLINKIT_ORDERS' AS table_name, COUNT(*) AS row_count FROM BLINKIT_DW.RAW.BLINKIT_ORDERS
UNION ALL
SELECT 'BLINKIT_MARKETING_PERFORMANCE', COUNT(*) FROM BLINKIT_DW.RAW.BLINKIT_MARKETING_PERFORMANCE
UNION ALL
SELECT 'BLINKIT_DELIVERY_PERFORMANCE', COUNT(*) FROM BLINKIT_DW.RAW.BLINKIT_DELIVERY_PERFORMANCE
UNION ALL
SELECT 'BLINKIT_ORDER_ITEMS', COUNT(*) FROM BLINKIT_DW.RAW.BLINKIT_ORDER_ITEMS
ORDER BY table_name;

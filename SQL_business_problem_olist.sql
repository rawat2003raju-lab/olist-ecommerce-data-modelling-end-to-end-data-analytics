CREATE DATABASE IF NOT EXISTS olist;
USE olist;

CREATE TABLE customers (
    customer_id              VARCHAR(50) PRIMARY KEY,
    customer_unique_id       VARCHAR(50) NOT NULL,
    customer_zip_code_prefix CHAR(5),
    customer_city            VARCHAR(100),
    customer_state           CHAR(2)
);

CREATE TABLE sellers (
    seller_id              VARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix CHAR(5),
    seller_city            VARCHAR(100),
    seller_state           CHAR(2)
);

CREATE TABLE geolocation (
    geolocation_zip_code_prefix CHAR(5) PRIMARY KEY,
    lat   DECIMAL(10,6),
    lng   DECIMAL(10,6),
    city  VARCHAR(100),
    state CHAR(2)
);

CREATE TABLE products (
    product_id                     VARCHAR(50) PRIMARY KEY,
    product_category_name          VARCHAR(100),
    product_name_length            INT,
    product_description_length     INT,
    product_photos_qty             INT,
    product_weight_g               INT,
    product_length_cm              INT,
    product_height_cm              INT,
    product_width_cm               INT,
    product_category_name_english  VARCHAR(100)
);

CREATE TABLE orders (
    order_id                       VARCHAR(50) PRIMARY KEY,
    customer_id                    VARCHAR(50) NOT NULL,
    order_status                   VARCHAR(20),
    order_purchase_timestamp       DATETIME,
    order_approved_at              DATETIME,
    order_delivered_carrier_date   DATETIME,
    order_delivered_customer_date  DATETIME,
    order_estimated_delivery_date  DATETIME,
    delivery_days                  INT,
    delay_days                     INT,
    is_late                        TINYINT,
    order_year                     INT,
    order_month                    INT,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE order_items (
    order_id            VARCHAR(50),
    order_item_id       INT,
    product_id          VARCHAR(50),
    seller_id           VARCHAR(50),
    shipping_limit_date DATETIME,
    price               DECIMAL(10,2),
    freight_value       DECIMAL(10,2),
    PRIMARY KEY (order_id, order_item_id),
    FOREIGN KEY (order_id)   REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    FOREIGN KEY (seller_id)  REFERENCES sellers(seller_id)
);

CREATE TABLE payments (
    order_id             VARCHAR(50),
    payment_sequential   INT,
    payment_type         VARCHAR(30),
    payment_installments INT,
    payment_value        DECIMAL(10,2),
    PRIMARY KEY (order_id, payment_sequential),
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

CREATE TABLE reviews (
    review_id               VARCHAR(50) PRIMARY KEY,
    order_id                VARCHAR(50) NOT NULL,
    review_score            TINYINT,
    review_comment_title    VARCHAR(255),
    review_comment_message  TEXT,
    review_creation_date    DATETIME,
    review_answer_timestamp DATETIME,
    has_comment             TINYINT,
    INDEX idx_reviews_order (order_id),
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_items_product   ON order_items(product_id);
CREATE INDEX idx_items_seller    ON order_items(seller_id);

USE olist;

SELECT 'customers' AS tbl, COUNT(*) AS n FROM customers
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'payments', COUNT(*) FROM payments
UNION ALL SELECT 'reviews', COUNT(*) FROM reviews
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'geolocation', COUNT(*) FROM geolocation;


-- Q1. What are the overall KPIs of the business?
SELECT COUNT(DISTINCT o.order_id)            AS total_orders,
       COUNT(DISTINCT c.customer_unique_id)  AS unique_customers,
       ROUND(SUM(oi.price), 2)               AS revenue,
       ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM orders o
JOIN customers c    ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered';


-- Q2. How are orders distributed by status?
SELECT order_status,
       COUNT(*) AS orders,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_orders
FROM orders
GROUP BY order_status
ORDER BY orders DESC;

-- Q3. Which 10 product categories generate the most revenue?
SELECT p.product_category_name_english AS category,
       COUNT(DISTINCT oi.order_id)     AS orders,
       ROUND(SUM(oi.price), 2)         AS revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN orders o   ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY category
ORDER BY revenue DESC
LIMIT 10;

-- Q4. Which states bring the most revenue and customers?
SELECT c.customer_state,
       COUNT(DISTINCT c.customer_unique_id) AS customers,
       ROUND(SUM(oi.price), 2)              AS revenue
FROM orders o
JOIN customers c    ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY revenue DESC;

-- Q5. How do customers pay?
SELECT payment_type,
       COUNT(DISTINCT order_id)  AS orders,
       ROUND(SUM(payment_value), 2) AS total_paid,
       ROUND(AVG(payment_installments), 1) AS avg_installments
FROM payments
GROUP BY payment_type
ORDER BY total_paid DESC;

-- Q7. Monthly revenue and month-over-month growth
WITH monthly AS (
    SELECT DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
           SUM(oi.price) AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY month
)
SELECT month,
       ROUND(revenue, 2) AS revenue,
       ROUND(100 * (revenue - LAG(revenue) OVER (ORDER BY month))
             / LAG(revenue) OVER (ORDER BY month), 1) AS mom_growth_pct
FROM monthly
ORDER BY month;

-- Q8. Top 3 sellers in each of the top categories
WITH seller_rev AS (
    SELECT p.product_category_name_english AS category,
           oi.seller_id,
           SUM(oi.price) AS revenue
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    GROUP BY category, oi.seller_id
),
ranked AS (
    SELECT *, RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS rnk
    FROM seller_rev
)
SELECT category, seller_id, ROUND(revenue, 2) AS revenue, rnk
FROM ranked
WHERE rnk <= 3
ORDER BY category, rnk;

-- Q9. How many customers buy again?
WITH cust_orders AS (
    SELECT c.customer_unique_id, COUNT(DISTINCT o.order_id) AS orders
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT CASE WHEN orders = 1 THEN 'One-time' ELSE 'Repeat' END AS customer_type,
       COUNT(*) AS customers,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM cust_orders
GROUP BY customer_type;

-- Q10. Does late delivery hurt review scores?
SELECT CASE WHEN o.is_late = 1 THEN 'Late' ELSE 'On time' END AS delivery,
       COUNT(*)                     AS reviews,
       ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM orders o
JOIN reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered' AND o.is_late IS NOT NULL
GROUP BY delivery;

-- Q11. Cumulative revenue over time
WITH monthly AS (
    SELECT DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
           SUM(oi.price) AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY month
)
SELECT month,
       ROUND(revenue, 2) AS revenue,
       ROUND(SUM(revenue) OVER (ORDER BY month), 2) AS running_total
FROM monthly;

-- Q6. Which states have the slowest delivery?
SELECT c.customer_state,
       ROUND(AVG(o.delivery_days), 1) AS avg_delivery_days,
       ROUND(100 * AVG(o.is_late), 1) AS pct_late
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY avg_delivery_days DESC;

SELECT COUNT(*) AS review_rows FROM reviews;

SELECT COUNT(*) AS orders,
       COUNT(delivery_days) AS has_delivery_days,
       COUNT(is_late) AS has_is_late
FROM orders;

SELECT COUNT(*) FROM reviews;

TRUNCATE TABLE reviews;

SELECT COUNT(*) FROM reviews;

select * from reviews;

SELECT CASE WHEN o.is_late = 1 THEN 'Late' ELSE 'On time' END AS delivery,
       COUNT(*)                      AS reviews,
       ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM orders o
JOIN reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered' AND o.is_late IS NOT NULL
GROUP BY delivery;


-- Q1 Insight: 96,478 delivered orders from 93,358 unique customers generated
-- about R$13.2M in item revenue, with an average order value of R$137.04.
-- Only ~3,100 orders came beyond each customer's first, so repeat buying is very low.

-- Q2 Insight: 97% of orders are delivered. Cancelled and unavailable orders together
-- are ~1.2%, so the business has a healthy fulfilment rate. All revenue
-- queries filter to delivered orders, which excludes the remaining ~3%.

-- Q3 Insight: health_beauty leads on revenue (R$1.23M). watches_gifts is #2 on revenue
-- with far fewer orders than bed_bath_table (5,495 vs 9,272), because its average order
-- is much higher (~R$212 vs ~R$110). High-value categories matter more than order volume.

-- Q4 Insight: SP alone contributes ~38% of revenue (R$5.07M) and ~42% of customers.
-- SP, RJ and MG together make up ~63% of revenue, so the business is heavily
-- concentrated in the Southeast. RJ customers spend more each (~R$148) than SP (~R$129),
-- which suggests RJ is worth targeting for higher-value growth.

-- Q5 Insight: Credit card is the dominant payment method, at ~78% of money paid, with
-- customers splitting purchases into 3.5 installments on average. Boleto (a Brazilian
-- bank slip) is second at ~18%. Vouchers and debit cards are ~4% combined.
-- Instalment offers are clearly important to purchase behaviour here.
-- Note: 3 orders have payment_type 'not_defined' with R$0 value, a data quirk
-- that is left in place because it doesn't affect results.

-- Q6 Insight: Delivery is slowest in remote northern states, with RR averaging 29 days,
-- AP 26.7 and AM 26.0, versus ~21 days in MA and SE. Late rates don't follow the same
-- pattern: AP (3.0%) and AM (2.8%) are rarely late despite long delivery times,
-- because estimated delivery dates there are set generously, while AL (21.4%) and
-- MA (17.4%) miss their estimates far more often. Estimate accuracy matters as much
-- as raw speed for customer experience.


-- Q7 Insight: Revenue grew rapidly through early 2017, from R$112K in January to
-- R$489K in May, with the strongest months-over-month jumps in Feb (+110%),
-- Mar (+53%) and May (+44%). The 2016 months are excluded because the dataset
-- has almost no orders then and November 2016 is missing entirely.

-- Q8 Insight: Several categories are dominated by a single seller. In
-- agro_industry_and_commerce the top seller earned ~R$31.6K, almost 4x the runner-up.
-- This concentration is a supply risk for those categories.

-- Q9 Insight: 97% of customers (90,557 of 93,358) bought only once, and only 3%
-- (2,801) came back. Retention is the biggest growth opportunity: even a small
-- lift in repeat purchases would add substantial revenue without new acquisition costs.

-- Q11 Insight: Cumulative revenue passed R$2M by June 2017 after the ramp-up
-- started in January 2017.


CREATE OR REPLACE VIEW vw_dim_order AS
SELECT order_id, customer_id, order_status,
       order_purchase_timestamp, order_year, order_month
FROM orders;



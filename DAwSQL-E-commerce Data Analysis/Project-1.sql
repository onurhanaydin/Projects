
use Project

-- E-COMMERCE PROJECT SOLUTION


-- 1. Join all the tables and create a new table called combined_table. (market_fact, cust_dimen, orders_dimen, prod_dimen, shipping_dimen)

SELECT *
INTO combined_table
FROM
(
SELECT mf.Ord_id, mf.Prod_id, mf.Ship_id, mf.Cust_id, mf.Sales, mf.Discount, mf.Order_Quantity, mf.Product_Base_Margin,
cd.Customer_Name, cd.Province, cd.Region, cd.Customer_Segment,
od.Order_Priority, od.Order_Date,
sd.Order_ID, sd.Ship_Date, sd.Ship_Mode,
pd.Product_Category, pd.Product_Sub_Category
FROM market_fact mf 
FULL OUTER JOIN cust_dimen cd ON cd.Cust_id=mf.Cust_id
FULL OUTER JOIN orders_dimen od ON od.Ord_id=mf.Ord_id
FULL OUTER JOIN shipping_dimen sd ON sd.Ship_id=mf.Ship_id
FULL OUTER JOIN prod_dimen pd ON pd.Prod_id=mf.Prod_id
) A

SELECT *
FROM combined_table


-- 2. Find the top 3 customers who have the maximum count of orders.


SELECT top 3 Customer_Name,count(Customer_Name) AS times
FROM combined_table
GROUP BY Customer_Name
ORDER BY times DESC


-- 3.Create a new column at combined_table as DaysTakenForDelivery that contains the date difference of Order_Date and Ship_Date.
-- Use "ALTER TABLE", "UPDATE" etc.


ALTER TABLE combined_table
ADD DaysTakenForDelivery int

UPDATE combined_table 
SET DaysTakenForDelivery = DATEDIFF (DAY, Order_Date, Ship_Date)

SELECT *
FROM combined_table


-- 4. Find the customer whose order took the maximum time to get delivered.
-- Use "MAX" or "TOP"


SELECT TOP 1 Customer_Name, DaysTakenForDelivery
FROM combined_table
ORDER BY DaysTakenForDelivery DESC


-- 5. Count the total number of unique customers in January and how many of them came back every month over the entire year in 2011
-- You can use such date functions and subqueries


SELECT COUNT(DISTINCT Customer_Name) AS Number_of_Uniq_Customers
FROM combined_table
WHERE MONTH(Order_Date)=01


WITH T1 AS
(
    SELECT Customer_Name, Order_Date
    From combined_table
    WHERE MONTH(Order_Date) IN (01,02,03,04,05,06,07,08,09,10,11,12) and YEAR(Order_Date)=2011
)

SELECT Customer_Name
FROM T1
WHERE MONTH(Order_Date)=01
GROUP BY Customer_Name


--6. write a query to return for each user the time elapsed between the first purchasing and the third purchasing, 
--in ascending order by Customer ID
--Use "MIN" with Window Functions


SELECT CusT_id, Order_Date, Density, First_Order, DATEDIFF(DAY, First_Order, Order_Date) Elapsed_Days
FROM 
(SELECT Cust_id, Ord_id, Order_Date,
MIN (Order_Date) OVER (PARTITION BY Cust_id) First_Order,
DENSE_RANK() OVER (PARTITION BY Cust_id ORDER BY Order_Date) Density
FROM combined_table) A
WHERE Density=3


-- 7. Write a query that returns customers who purchased both product 11 and product 14, 
-- as well as the ratio of these products to the total number of products purchased by the customer.
-- Use CASE Expression, CTE, CAST AND such Aggregate Functions


SELECT *
FROM combined_table

WITH T1 AS
(SELECT Cust_id,
SUM(CASE WHEN Prod_id='Prod_11' THEN Order_Quantity ELSE 0 END) P11,
SUM(CASE WHEN Prod_id='Prod_14' THEN Order_Quantity ELSE 0 END) P14,
SUM(Order_Quantity) TOTAL 
FROM combined_table
GROUP BY Cust_id
HAVING 
SUM(CASE WHEN Prod_id='Prod_11' THEN Order_Quantity ELSE 0 END) >0 AND
SUM(CASE WHEN Prod_id='Prod_14' THEN Order_Quantity ELSE 0 END) >0)

SELECT Cust_id, P11, P14, TOTAL,
       CAST(1.0*P11/TOTAL AS numeric (4,3)) AS Perc_P11,
       CAST(1.0*P14/TOTAL AS numeric (4,3)) AS Perc_P14
FROM T1


--CUSTOMER RETENTION ANALYSIS


-- 1. Create a view that keeps visit logs of customers on a monthly basis. (For each log, three field is kept: Cust_id, Year, Month)
-- Use such date functions. Don't forget to call up columns you might need later.


CREATE VIEW customer_log AS
SELECT Cust_id, 
         YEAR(Order_Date) yearr,
         MONTH(Order_Date) monthh
FROM combined_table


SELECT *
FROM customer_log


-- 2. Create a view that keeps the number of monthly visits by users. (Separately for all months from the business beginning)
-- Don't forget to call up columns you might need later.


CREATE VIEW visit AS

WITH T1 AS
(
    SELECT Cust_id, yearr, monthh, COUNT(*) AS Num_of_Log
    FROM customer_log
    GROUP BY Cust_id, yearr, monthh
)
SELECT *
FROM T1


SELECT *
FROM visit


-- 3. For each visit of customers, create the next month of the visit as a separate column.
-- You can number the months with "DENSE_RANK" function.
-- then create a new column for each month showing the next month using the numbering you have made. (use "LEAD" function.)
-- Don't forget to call up columns you might need later.


CREATE VIEW Next_Visit AS

SELECT *,
LEAD(current_month,1) OVER (PARTITION BY Cust_id ORDER BY current_month) AS Next_Vis
FROM
(SELECT *,
		DENSE_RANK() OVER (ORDER BY yearr, monthh) AS Current_Month
FROM visit) A


SELECT *
FROM Next_Visit


-- 4. Calculate the monthly time gap between two consecutive visits by each customer.
-- Don't forget to call up columns you might need later.


CREATE VIEW Time_Gaps AS

SELECT *,
		Next_Vis - Current_Month AS Time_gaps
FROM	Next_Visit


SELECT *
FROM Time_Gaps


-- 5.Categorise customers using time gaps. Choose the most fitted labeling model for you.
--  For example: 
--	Labeled as churn if the customer hasn't made another purchase in the months since they made their first purchase.
--	Labeled as regular if the customer has made a purchase every month.


SELECT cust_id, avg_time_gap,
		CASE WHEN avg_time_gap = 1 THEN 'retained' 
			WHEN avg_time_gap > 1 THEN 'irregular'
			WHEN avg_time_gap IS NULL THEN 'Churn'
			ELSE 'UNKNOWN DATA' END CUST_LABELS
FROM
		(
		SELECT Cust_id, AVG(Time_gaps) avg_time_gap
		FROM	Time_Gaps
		GROUP BY Cust_id
		) A


-- MONTH-WISE RETENTION RATE


-- Find the number of customers retained month-wise. (You can use time gaps)
-- Use Time Gaps


SELECT	DISTINCT cust_id, yearr, monthh
		Current_Month,
		Next_Vis,
		Time_gaps,
		COUNT (cust_id)	OVER (PARTITION BY Next_Vis) Retention_month_wise
FROM	Time_Gaps
where	Time_gaps =1
ORDER BY cust_id, Next_Vis


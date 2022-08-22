/*>> Project: Investigate a Relational Database */
-- Date: 25.06.2022




/* Question 1*/
/* How did the business work?*/
-- There are 3 categories, similar numbers of films inventories distributed across the 3 categories
SELECT 
	f.rental_rate,
	COUNT(DISTINCT i.inventory_id) AS count_inventory,
	COUNT(DISTINCT f.film_id) AS count_film,
	MAX(f.rental_duration) AS max_rental_duration,
	MIN(f.rental_duration) AS min_rental_duration
FROM inventory i
JOIN film f
ON i.film_id = f.film_id
 
GROUP BY rental_rate;




/* Question 2*/
/* Where were the customers? */
-- top 20 countries of customer numbers & payment amount, also aggregate a bottom line
WITH sub AS
	(SELECT cu.customer_id,c.country,c.country_id 
	FROM customer cu
	JOIN address a
	ON cu.address_id = a.address_id
	JOIN city ci
	ON a.city_id = ci.city_id
	JOIN country c
	ON ci.country_id = c.country_id),
	
top AS(
	SELECT
		DISTINCT country,
		COUNT(DISTINCT sub.customer_id) customer_count,
		SUM(amount) payment
	
	FROM
		payment p
	JOIN
		 sub
	ON p.customer_id=sub.customer_id
	GROUP BY country
	ORDER BY 3 DESC
	LIMIT 20),

non_top AS(
	SELECT
		'Others' country,
		COUNT(DISTINCT sub.customer_id) customer_count,
		SUM(amount) payment
	FROM
		payment p
	JOIN
		 sub
	ON p.customer_id=sub.customer_id
	WHERE country NOT IN(SELECT country FROM top)),

bottom_line AS(
	SELECT
		'All regions' country,
		COUNT(DISTINCT sub.customer_id) customer_count,
		SUM(amount) payment
	FROM
		payment p
	JOIN
		 sub
	ON p.customer_id=sub.customer_id)

SELECT *,1 order_code
FROM top
UNION
SELECT *,2 order_code
FROM non_top
UNION
SELECT *,3 oder_code
FROM bottom_line
ORDER BY order_code,payment DESC;




/* Question 3*/
/*How much did each customer pay?*/
-- generate a list of customer id and their payment given all avilable records from table "payment"
-- regression analysis shows per count of rent corresponds to an further spend of 4

WITH pr_agg AS --aggregate all payment records
	(SELECT customer_id,
	 	SUM(amount) pay_per_customer
	FROM payment
	GROUP BY customer_id
	ORDER BY customer_id DESC),
	
	rr_agg AS--aggregate all rent records
	(SELECT customer_id,
	 	COUNT(rental_id) rent_per_customer
	FROM rental
	GROUP BY customer_id)
	
SELECT pr_agg.*,rr_agg.rent_per_customer
FROM pr_agg
FULL JOIN rr_agg
ON pr_agg.customer_id = rr_agg.customer_id
ORDER BY pay_per_customer;

-- linear regression, min, max average aggregations are conducted in excel




/* Question 4*/
/*How fast did Inventories move?*/


WITH t1 AS(
	SELECT 
		DATE_TRUNC('day',MIN(rental_date)) ealiest_rent,--2005-05-24
		DATE_TRUNC('day',MIN(return_date)) earliest_return,--2005-05-25
		
		DATE_TRUNC('day',MAX(rental_date)) latest_rent,--2006-02-14
		DATE_TRUNC('day',MAX(return_date)) latest_return--2005-09-02
	FROM rental),

firt AS(
	SELECT i.inventory_id,r.rental_id, f.film_id, f.title, r.rental_date, r.return_date, 
		DATE_PART('day',r.return_date::timestamp-r.rental_date::timestamp)+1 AS rent_length_days,
		SUM(DATE_PART('day',r.return_date::timestamp-r.rental_date::timestamp)+1) OVER(PARTITION BY i.inventory_id) sum_inventory_out_days, 
		r.return_date-r.rental_date AS rent_length
	FROM rental r
	JOIN inventory i
	ON r.inventory_id = i.inventory_id
	JOIN film f
	ON i.film_id = f.film_id
	WHERE r.return_date < CAST((SELECT latest_return FROM t1) as date)+1),

firtr AS (
		SELECT *, RANK() OVER(ORDER BY(SUM_inventory_out_days)DESC) AS pop_rank 
		FROM (
			SELECT 
			DISTINCT rental_id, 
			sum_inventory_out_days
			FROM firt) sub
		),	
		
firtd AS(
	SELECT 
		*,
		generate_series( (SELECT DATE_TRUNC('day',MIN(rental_date) )FROM firt), (SELECT DATE_TRUNC('day',MAX(return_date)) FROM firt), '1 day') AS date_index
	FROM firt)
		
		
SELECT 
	firtd.inventory_id,firtd.title,firtd.rental_id, firtd.sum_inventory_out_days,firtd.date_index,
	firtr.pop_rank,
	1 out_flag
FROM firtd
JOIN firtr
ON firtd.rental_id = firtr.rental_id
WHERE date_index>=DATE_TRUNC('day',rental_date) AND date_index<=DATE_TRUNC('day',return_date)
ORDER BY pop_rank;

-- calendar visualization is done in Excel










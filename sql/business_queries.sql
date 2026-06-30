
-- 1.How many pizzas were ordered?

SELECT count(order_id) AS total_pizzas_ordered
FROM customer_orders;

-- 2.How many unique customer orders were made?

SELECT count(DISTINCT order_id) AS unique_orders
FROM customer_orders;

-- 3.How many successful orders were delivered by each runner?

SELECT runner_id, count(order_id) AS successful_orders
FROM runner_orders
WHERE cancellation IS NULL
GROUP BY runner_id
ORDER BY runner_id;

-- 4.How many of each type of pizza was delivered?

SELECT co.pizza_id, count(co.pizza_id) FROM runner_orders AS ro
INNER JOIN customer_orders AS co
ON ro.order_id = co.order_id
WHERE ro.cancellation IS NULL
GROUP BY co.pizza_id;

-- 5.How many Vegetarian and Meatlovers were ordered by each customer?

SELECT co.customer_id, pn.pizza_name, count(co.pizza_id) AS ordered_count
FROM customer_orders AS co
INNER JOIN pizza_names as pn
ON co.pizza_id = pn.pizza_id
GROUP BY co.customer_id, pn.pizza_name
ORDER BY co.customer_id;

-- 6.What was the maximum number of pizzas delivered in a single order?

SELECT co.order_id, count(co.pizza_id) AS pizzas_delivered 
FROM customer_orders as co
INNER JOIN runner_orders AS ro
ON co.order_id = ro.order_id
WHERE ro.cancellation IS null
group BY order_id
ORDER BY pizzas_delivered DESC
LIMIT 1;

-- 7.For each customer, how many delivered pizzas had at least 1 change and how many had no changes?

SELECT co.customer_id, sum(CASE WHEN co.exclusions IS not NULL OR co.extras IS not NULL THEN 1
                                ELSE 0
                                end) AS changed_orders,
                        sum(CASE WHEN co.exclusions IS NULL AND co.extras IS NULL THEN 1
                                ELSE 0
                                end) AS unchanged_orders
FROM customer_orders AS co
INNER JOIN runner_orders AS ro
ON co.order_id = ro.order_id
WHERE ro.cancellation IS NULL
GROUP BY customer_id
ORDER by co.customer_id;

-- 8.How many pizzas were delivered that had both exclusions and extras?

SELECT sum(CASE WHEN co.exclusions IS not NULL AND co.extras IS not NULL THEN 1
                                ELSE 0
                                end) AS had_exclusions_and_extras
FROM customer_orders AS co
INNER JOIN runner_orders AS ro
ON co.order_id = ro.order_id
WHERE ro.cancellation IS NULL;

-- 9.What was the total volume of pizzas ordered for each hour of the day?

SELECT hour(order_time) AS hour_of_day, count(pizza_id) AS total_volume 
FROM customer_orders
group BY hour(order_time)
ORDER BY hour_of_day;

-- 10.What was the volume of orders for each day of the week?

SELECT DAYNAME(order_time) AS day_of_week, count(pizza_id) AS total_weekly_volume 
FROM customer_orders
group BY DAYNAME(order_time), dayofweek(order_time)
ORDER BY DAYOFWEEK(order_time);

-- B. Runner and customer experience

-- 1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)

SELECT week(registration_date, 5) AS week_number,
count(runner_id) AS runner_signups
FROM runners
GROUP BY week(registration_date, 5)
ORDER BY week_number;

-- 2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?

SELECT ro.runner_id, round(avg(TIMESTAMPDIFF(minute, co.order_time, ro.pickup_time)), 2) AS avg_pickup_time
FROM runner_orders AS ro
INNER JOIN customer_orders AS co
ON ro.order_id = co.order_id
WHERE ro.cancellation IS NULL
GROUP BY ro.runner_id
ORDER BY ro.runner_id;

-- 3. Is there any relationship between the number of pizzas and how long the order takes to prepare?

SELECT pizza_count,
round(avg(prep_time_minutes), 2) AS avg_prep_time_per_order,
round(avg(prep_time_minutes) / pizza_count, 2) AS avg_prep_time_per_pizza
from(

SELECT co.order_id,
count(co.pizza_id) AS pizza_count,
TIMESTAMPDIFF(minute, co.order_time, ro.pickup_time) AS prep_time_minutes
FROM customer_orders AS co
INNER JOIN runner_orders AS ro
ON co.order_id = ro.order_id
WHERE ro.cancellation IS NULL
group BY co.order_id, co.order_time, ro.pickup_time
) AS order_summary

GROUP BY pizza_count
ORDER BY pizza_count;

-- as the number of pizzas in one order increases the preparation time increases

-- 4. What was the average distance travelled for each customer?

SELECT co.customer_id, round(avg(ro.distance), 2)
FROM customer_orders co
INNER JOIN runner_orders ro
ON co.order_id = ro.order_id
WHERE ro.cancellation is null
GROUP BY co.customer_id;

-- 5. What was the difference between the longest and shortest delivery times for all orders?

SELECT timediff(max(duration),min(duration)) AS difference FROM runner_orders
where cancellation IS null;
-- another method

SELECT max(TIME_TO_SEC(duration)/60) - min(TIME_TO_SEC(duration)/60) AS duration_range_minutes
FROM runner_orders
WHERE cancellation IS null;

-- 6. What was the average speed for each runner for each delivery and do you notice any trend for these values?

SELECT co.order_id, ro.runner_id, round(avg((ro.distance / TIME_TO_SEC(ro.duration))*3600), 2) AS average_speed
FROM customer_orders co
inner JOIN runner_orders ro
ON co.order_id = ro.order_id
WHERE ro.cancellation is NULL
GROUP BY ro.runner_id, co.order_id
ORDER BY average_speed;

-- 7. What is the successful delivery percentage for each runner?

SELECT runner_id, round((sum(CASE WHEN cancellation IS NULL THEN 1 ELSE 0 end) / count(order_id)) * 100, 0) 
AS successful_percentage
FROM runner_orders
group BY runner_id;

-- C. Ingredient optimisation

-- 1. What are the standard ingredients for each pizza?

SELECT pn.pizza_name, pt.topping_name
FROM pizza_recipes_normalized AS pr
INNER JOIN pizza_names pn
ON pr.pizza_id = pn.pizza_id
inner JOIN pizza_toppings AS pt
ON pr.topping_id = pt.topping_id
ORDER BY pn.pizza_name, pt.topping_name;

-- 2. What was the most commonly added extra?

SELECT pt.topping_name,
count(co.order_id) AS total_times_added
FROM pizza_toppings pt
INNER JOIN customer_orders co
ON FIND_IN_SET(pt.topping_id, replace(co.extras, ' ', '')) > 0
WHERE co.extras is NOT NULL
GROUP BY pt.topping_name
ORDER BY total_times_added DESC
LIMIT 1;

-- 3. What was the most common exclusion?

SELECT pt.topping_name,
count(co.order_id) AS total_times_excluded
FROM pizza_toppings pt
INNER JOIN customer_orders co
ON FIND_IN_SET(pt.topping_id, replace(co.exclusions, ' ', '')) > 0
WHERE co.exclusions is NOT NULL
GROUP BY pt.topping_name
ORDER BY total_times_excluded DESC
LIMIT 1;

-- 4. Generate an order item for each record in the customers_orders table in the format 
--    of one of the following:
--      Meat Lovers
--      Meat Lovers - Exclude Beef
--      Meat Lovers - Extra Bacon
--      Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers

CREATE TABLE IF NOT EXISTS customer_exclusions_normalized AS
SELECT co.order_id, co.pizza_id, cast(pt.topping_id AS UNSIGNED) AS topping_id
FROM customer_orders co
inner join pizza_toppings pt
ON FIND_IN_SET(pt.topping_id, replace(co.exclusions, ' ', '')) > 0;

CREATE TABLE IF NOT EXISTS customer_extras_normalized AS
SELECT co.order_id, co.pizza_id, cast(pt.topping_id AS UNSIGNED) AS topping_id
FROM customer_orders co
inner join pizza_toppings pt
ON FIND_IN_SET(pt.topping_id, replace(co.extras, ' ', '')) > 0;

SELECT co.order_id,
co.customer_id,
co.pizza_id,
CONCAT_WS(' - ', pn.pizza_name,

(SELECT concat('Exclude ', GROUP_CONCAT(pt.topping_name SEPARATOR ', '))
FROM customer_exclusions_normalized AS x
inner JOIN pizza_toppings AS pt
ON x.topping_id = pt.topping_id
WHERE x.order_id = co.order_id AND x.pizza_id = co.pizza_id),

(SELECT CONCAT('Extra ', GROUP_CONCAT(pt.topping_name SEPARATOR ', '))
 FROM customer_extras_normalized AS e
 INNER JOIN pizza_toppings AS pt ON e.topping_id = pt.topping_id
 WHERE e.order_id = co.order_id AND e.pizza_id = co.pizza_id)) AS custome_order_item

FROM customer_orders co
INNER JOIN pizza_names pn
ON co.pizza_id = pn.pizza_id;

-- 5. Generate an alphabetically ordered comma separated ingredient list for each pizza order 
--    from the customer_orders table and add a 2x in front of any relevant ingredients
--         For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"

WITH prepared_orders AS (
SELECT
order_id,
customer_id,
pizza_id,
exclusions,
extras,
ROW_NUMBER() OVER (ORDER BY order_id) AS pizza_record_id
FROM customer_orders
),
all_ingredients_compiled AS (
SELECT po.pizza_record_id, po.order_id, po.pizza_id, pr.topping_id
FROM prepared_orders AS po
INNER JOIN pizza_recipes_normalized pr
ON po.pizza_id = pr.pizza_id

union ALL
SELECT
po.pizza_record_id,
po.order_id,
po.pizza_id, pt.topping_id
FROM prepared_orders po
INNER JOIN pizza_toppings pt
ON FIND_IN_SET(pt.topping_id, replace(po.extras, ' ', ''))>0
)
SELECT ingredient_counts.order_id,
pn.pizza_name,
concat(pn.pizza_name, ': ',
GROUP_CONCAT(CASE
WHEN ingredient_counts.topping_tally = 2 THEN concat('2x', ingredient_counts.topping_name)
ELSE ingredient_counts.topping_name
END
ORDER BY ingredient_counts.topping_name SEPARATOR ', ')
) AS final_ingredient_list

FROM (SELECT base.pizza_record_id,
base.order_id,
base.pizza_id,
pt.topping_name,
count(base.topping_id) AS topping_tally
FROM all_ingredients_compiled base
INNER JOIN pizza_toppings pt
ON base.topping_id = pt.topping_id
LEFT join prepared_orders po
ON base.pizza_record_id = po.pizza_record_id
WHERE NOT FIND_IN_SET(base.topping_id, REPLACE(COALESCE(po.exclusions, ''), ' ', '')) > 0
GROUP BY base.pizza_record_id, base.order_id, base.pizza_id, pt.topping_name
) AS ingredient_counts
INNER JOIN pizza_names pn
ON ingredient_counts.pizza_id = pn.pizza_id
GROUP BY ingredient_counts.pizza_record_id, ingredient_counts.order_id, pn.pizza_name
ORDER BY ingredient_counts.order_id;

-- 6. What is the total quantity of each ingredient used in all delivered pizzas 
--    sorted by most frequent first?

WITH delivered_pizzas AS (
SELECT
co.order_id,
co.pizza_id,
co.exclusions,
co.extras,
ROW_NUMBER() OVER (ORDER BY co.order_id) AS pizza_record_id
FROM customer_orders co
INNER JOIN
runner_orders ro
ON co.order_id = ro.order_id
WHERE ro.cancellation is NULL
),
all_ingredients AS (
SELECT dp.pizza_record_id, pr.topping_id
FROM delivered_pizzas AS dp
INNER JOIN pizza_recipes_normalized pr
ON dp.pizza_id = pr.pizza_id

union ALL
SELECT dp.pizza_record_id, pt.topping_id
FROM delivered_pizzas AS dp
INNER JOIN pizza_toppings pt
ON FIND_IN_SET(pt.topping_id, replace(dp.extras, ' ', '')) > 0
)

SELECT pt.topping_name,
count(ai.topping_id) AS total_ingredients_used
FROM all_ingredients AS ai
INNER JOIN pizza_toppings pt
ON ai.topping_id = pt.topping_id
LEFT JOIN delivered_pizzas AS dp
ON ai.pizza_record_id = dp.pizza_record_id

WHERE NOT FIND_IN_SET(ai.topping_id, replace(coalesce(dp.exclusions, ''), ' ', ''))>0
GROUP BY pt.topping_name
ORDER BY total_ingredients_used desc;


-- D. Pricing and ratings



-- 1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes 
--     - how much money has Pizza Runner made so far if there are no delivery fees?

SELECT
sum(CASE WHEN co.pizza_id = 1 THEN 12
WHEN co.pizza_id = 2 THEN 10
ELSE 0 end) AS total_income
FROM customer_orders AS co
INNER JOIN runner_orders ro
ON co.order_id = ro.order_id
WHERE ro.cancellation is null;

-- 2. What if there was an additional $1 charge for any pizza extras?
--       Add cheese is $1 extra

SELECT
sum(CASE WHEN co.pizza_id = 1 THEN 12
WHEN co.pizza_id = 2 THEN 10
WHEN co.extras IS NOT NULL THEN 1
ELSE 0 END +
CASE
WHEN co.extras is NULL THEN 0
ELSE LENGTH(REPLACE(co.extras, ' ', '')) - LENGTH(REPLACE(REPLACE(co.extras, ' ', ''), ',', ''))+1
end) AS total_income_with_extras
FROM customer_orders AS co
INNER JOIN runner_orders ro
ON co.order_id = ro.order_id
WHERE ro.cancellation is null;

-- 3. The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, 
--        how would you design an additional table for this new dataset - generate a schema for this new table and 
--        insert your own data for ratings for each successful customer order between 1 to 5.

ALTER TABLE runner_orders ADD INDEX (order_id);

CREATE TABLE runner_ratings(
rating_id int AUTO_INCREMENT PRIMARY KEY,
order_id int NOT null,
rating int NOT null,
review_text varchar(200),
rating_time timestamp DEFAULT CURRENT_TIMESTAMP,
FOREIGN KEY (order_id) REFERENCES runner_orders(order_id),
CONSTRAINT chk_rating_range CHECK (rating BETWEEN 1 AND 5)
);

INSERT INTO runner_ratings (order_id, rating, review_text) 
VALUES
    (1, 5, 'Delivered incredibly fast! Pizza was steaming hot.'),
    (2, 4, 'Great service, polite runner.'),
    (3, 3, 'Took a bit longer than expected, but the food was fine.'),
    (4, 5, 'Amazing runner! Navigated through heavy rain safely.'),
    (5, 5, 'Super friendly and prompt.'),
    (7, 4, 'Good delivery, but forgot the extra napkins.'),
    (8, 2, 'Runner got lost and pizza arrived lukewarm.'),
    (10, 5, 'Excellent service, right on time!');

SELECT * FROM runner_ratings;

-- 4. Using your newly generated table - can you join all of the information together to form a table
--     which has the following information for successful deliveries?
--         customer_id
--         order_id
--         runner_id
--         rating
--         order_time
--         pickup_time
--         Time between order and pickup
--         Delivery duration
--         Average speed
--         Total number of pizzas

SELECT co.customer_id,
co.order_id,
ro.runner_id,
rr.rating,
co.order_time,
ro.pickup_time,
TIMESTAMPDIFF(minute, co.order_time, ro.pickup_time) AS mins_order_pickup,
ro.duration AS delivery_duration,
round(avg((ro.distance / TIME_TO_SEC(ro.duration)) * 3600), 2) AS average_speed_km_h,
count(co.pizza_id) AS total_number_of_pizzas
FROM customer_orders co
INNER JOIN runner_orders ro
ON co.order_id = ro.order_id
inner JOIN runner_ratings rr 
ON ro.order_id = rr.order_id
WHERE ro.cancellation is NULL
group BY
co.customer_id,
co.order_id,
ro.runner_id,
rr.rating,
co.order_time,
ro.pickup_time,
ro.duration
ORDER BY co.order_id;

-- 5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner 
--     is paid $0.30 per kilometre traveled - how much money does Pizza Runner have left over after these deliveries?

SELECT sum(case
WHEN co.pizza_id = 1 THEN 12
WHEN co.pizza_id = 2 THEN 10
ELSE 0
end) AS total_revenue,

round(sum(payout_calculations.delivery_cost), 2) AS total_runner_payout,
round(sum(CASE WHEN co.pizza_id = 1 THEN 12
WHEN co.pizza_id = 2 THEN 10
ELSE 0
end) - sum(payout_calculations.delivery_cost), 2) AS net_profit

FROM customer_orders co
INNER JOIN runner_orders ro
ON co.order_id = ro.order_id

INNER JOIN(
SELECT order_id, (distance*0.3) AS delivery_cost
FROM runner_orders
WHERE cancellation IS NULL) AS payout_calculations
ON co.order_id = payout_calculations.order_id
WHERE ro.cancellation IS null;

USE sakila;


-- =============================================================
-- PROJECT 3: SQL FLUENCY DRILLING
-- Dataset: Sakila (MySQL sample database)
-- Author: Christopher Davenport
-- =============================================================
-- Convention: SQL keywords in UPPERCASE, table/column names in lowercase
-- Each query is preceded by a comment stating the question it answers
-- and any notes about the approach or construct being practiced.
-- =============================================================



-- -------------------------------------------------------------
-- TIER 0: Schema Orientation
-- No queries. Key relationships established by reading the EER
-- diagram in MySQL Workbench before any analytical querying.
--
-- Key relationships confirmed:
--   Geographic chain:
--     customer -> address (address_id)
--              -> city    (city_id)
--              -> country (country_id)
--
--   Junction tables (many-to-many):
--     film_actor    : film_id + actor_id
--     film_category : film_id + category_id
--
--   Staff and store:
--     staff holds store_id as a FK pointing to store
--     Each staff member belongs to exactly one store
--     Both staff and store have independent address_id FK to address
-- -------------------------------------------------------------


-- -------------------------------------------------------------
-- TIER 1: Single-Table Fundamentals
-- Constructs: WHERE, ORDER BY, DISTINCT, LIKE, IN, BETWEEN,
--             date filtering
-- -------------------------------------------------------------

-- The following code selects customer information (first_name, last_name, email) from the customer.
-- Only the customers whose last name starts with 'S' will be selected. This is accomplished through the pattern matching operator 
-- LIKE, which will match the data within a column to the provided string match. % is used as a wildcard where any amount of characters
-- may come after the S. Finally, this information is sorted in alphabetical order via last name 
SELECT first_name, last_name, email 
	FROM customer
	WHERE last_name LIKE 'S%'
    ORDER BY last_name;

-- The following code selects the unique ratings that are used in the film table. In order to do this, DISTINCT is utilized. DISTINCT selects
-- values from the specified column only once. This allows you to see every type of value represented within a column one time.
SELECT DISTINCT rating
	FROM film;

-- The following code selects the titles of movies and the amount of time to rent (in days) from the film table where the movies are rented 
-- between five and seven days. This list is first ordered by the duration and then alphabetized within each rental duration
SELECT title, rental_duration
	FROM film
    WHERE rental_duration BETWEEN 5 AND 7
    ORDER BY rental_duration, title;

-- The following code returns title and description of films mentioning "astronaut" anywhere in the description
-- this is done by putting % on both sides, which tells the query and amount of characters 
-- may come before or after the word
SELECT title, `description`
	FROM film
	WHERE `description` LIKE '%astronaut%';

-- The following code returns the a number counting the amount of entries where movies have astronaut in their
-- description. I tried to incorporate this in the previous syntax intially, but I received an error message.
-- This is because count is an aggregate function, and I was passing two nonaggregated values with it, and 
-- sql does not know how to handle this.
SELECT count(*) AS with_astronaut
	FROM film
	WHERE `description` LIKE '%astronaut%';

-- The following code is used to retrieve customer rental information for the month of July.
-- Comparison operators were used in place of the BETWEEN clause to fix the common issue where
-- dates outside of the anticipated range are included into the query. Using BETWEEN with a
-- datetime datatype creates the range using inclusive logic on midnight, such that data collected
-- up until midnight of the queried date will be included. In the example below, ending the range
-- at August 1st with BETWEEN would have wrongly included rental data timestamped at midnight on
-- August 1st. Conversely, ending at July 31st would have wrongly excluded all rental data
-- recorded after midnight on that date. The half-open range, using >= on the start and < on the
-- following month, avoids both boundary errors by construction.
SELECT rental_id, rental_date, customer_id
    FROM rental
    WHERE rental_date >= '2005-07-01'
      AND rental_date < '2005-08-01';

-- The following list selects films whose rating is not G, PG, or PG-13, using NOT IN to exclude that list of values.
-- The IN operator is used to compare values within a column to a (in this context) provided list.
-- The LIKE operator is not applicable here as that is reserved for partial string comparisons
SELECT title, rating 
	FROM film
    WHERE rating NOT IN ('G', 'PG', 'PG-13');

-- -------------------------------------------------------------
-- TIER 2: Aggregation
-- Constructs: GROUP BY, COUNT, SUM, AVG, WHERE vs HAVING
-- -------------------------------------------------------------

-- The following code returns each value in the rating column, followed by the count for
-- each time the rating occurs. GROUP BY performs a similar function to SELECT DISTINCT
-- as it will only output the values once for the specified column. The major difference
-- is that GROUP BY allows you to perform aggregations functions to assess the contents
-- of the unique values.
SELECT rating, COUNT(*) AS '# of movies'
	FROM film
    GROUP BY rating;


-- The following code utilizes the GROUP BY clause to find the average rental rate for each
-- rating value. The averaged rate is rounded to the nearest hundredth using the ROUND() function,
-- where the second argument (2) specifies the number of decimal places retained.
SELECT rating, ROUND(AVG(rental_rate), 2) AS avg_rental_rate
    FROM film
    GROUP BY rating;
    
-- The following code displays only the rating values that have more than 200 movies with that value.
-- This is accomplished by selecting the rating column, computing a count of films per group with
-- COUNT(*), grouping by rating, and then using HAVING to include only the ratings whose computed
-- count is greater than 200. HAVING is required here rather than WHERE because the count is an
-- aggregate that does not exist until after the rows are grouped.
SELECT rating, COUNT(*) AS number_of_films
    FROM film
    GROUP BY rating
    HAVING number_of_films > 200;

-- The following code returns each rating and the number of films with that rating, restricted to
-- films whose rental rate is 4.99, and further restricted to ratings represented by more than 200
-- such films. Two filters operate at two different stages. The WHERE clause filters individual
-- rows before grouping, removing every film that is not priced at 4.99. Because rental_rate is a
-- raw row-level value, it must be filtered here, before aggregation occurs. The GROUP BY clause
-- then collapses the surviving rows into one group per rating, and COUNT(*) computes the size of
-- each group. The HAVING clause filters those groups after aggregation, keeping only ratings whose
-- count exceeds 200. Because that count is an aggregate that does not exist until after grouping,
-- it cannot be filtered in WHERE and must be placed in HAVING. The general rule: row-level
-- conditions belong in WHERE, aggregate conditions belong in HAVING.
SELECT rating, COUNT(*) AS number_of_films
    FROM film
    WHERE rental_rate = 4.99
    GROUP BY rating
    HAVING number_of_films > 200;
    
-- The following code creates a set of customer ids, the amount they spent, and orders 
-- these data in descending order (most to least)
SELECT customer_id, SUM(amount) as total_spent
	FROM payment
    GROUP BY customer_id
	ORDER BY total_spent DESC;
	
-- The following code returns the lowest amount spent, the highest amount spent, and 
-- the average amount spend. Since we are query across all customers and returning
-- one value, group by is not needed. instead, these data are treating as a singular
-- group, and it is aggregated within that group
SELECT MIN(amount), MAX(amount), AVG(amount)
	FROM payment;

-- The following code returns the number of payments for each unique pairing of customer and staff
-- member. Listing two columns in the GROUP BY clause groups the rows by the combination of those
-- columns, producing one group per distinct (customer_id, staff_id) pairing rather than one group
-- per column individually. COUNT then counts the payments within each pairing. Both customer_id and
-- staff_id appear in the GROUP BY because every non-aggregated column in the SELECT must be grouped
-- or aggregated. Within each group those columns hold a single constant value, so they can sit
-- unambiguously beside the aggregated count.
SELECT customer_id, staff_id, COUNT(amount) AS num_payments
    FROM payment
    GROUP BY customer_id, staff_id;
 
-- -------------------------------------------------------------
-- TIER 3: Joins
-- Constructs: INNER JOIN, LEFT JOIN, RIGHT JOIN,
--             multi-hop geographic chain, junction table joins,
--             self-joins, aliasing when two FKs hit the same table
-- -------------------------------------------------------------

-- The following code joins the first and last name from the staff table with the amount and payment id
-- from the payment table. This is done with an INNER JOIN on staff_id, the column shared by both tables.
-- Because INNER JOIN was used, the output only contains payments that have a matching staff record.
-- Any row without a match on staff_id is excluded. The result has 16044 rows, one per payment, since
-- each payment matches exactly one staff member while each staff member matches many payments.
SELECT s.first_name, s.last_name, p.amount, p.payment_id
    FROM staff AS s
    INNER JOIN payment AS p
    ON s.staff_id = p.staff_id;
    
-- The following code combines the first and last name columns from the customer table with the city
-- column of the city table. Given that there is not a direct link between customer and city, two joins
-- were used: 1) customer with address and 2) address with city.
SELECT c.first_name, c.last_name, ci.city
	FROM customer as c
    JOIN address as a
    ON c.address_id = a.address_id
    JOIN city as ci
    ON ci.city_id = a.city_id;

-- The following code returns the first and last name from the actor table and the title from the film
-- table, but only for the actor named Nick Wahlberg. Actor and film have no direct relationship, so they
-- are linked through the film_actor junction table. Actor joins to film_actor on actor_id, then
-- film_actor joins to film on film_id.
-- NOTE: the joins assemble the combined rows first, then WHERE filters those joined rows, and finally
-- the SELECT columns are chosen and ORDER BY is applied. WHERE appears near the end of the written query
-- by convention, but it does not literally run last.
SELECT a.first_name, a.last_name, f.title
    FROM actor AS a
    JOIN film_actor AS fa
    ON fa.actor_id = a.actor_id
    JOIN film AS f
    ON f.film_id = fa.film_id
    WHERE a.first_name = 'Nick' AND a.last_name = 'Wahlberg'
    ORDER BY f.title;

-- The following code returns the titles from the film table where there is no linking entry in the
-- inventory table, meaning films with no physical copies. A LEFT JOIN returns all titles from the film
-- table regardless of whether a matching inventory row exists, and films with no match get NULL in every
-- inventory column. The WHERE clause then filters on inventory_id IS NULL to keep only those unmatched
-- films. This is the anti-join pattern. The primary key is tested for NULL because a primary key is never
-- NULL in a real row, so a NULL there can only mean no match.
SELECT f.title
	FROM film as f
    LEFT JOIN inventory as i
    ON f.film_id = i.film_id
    WHERE i.inventory_id IS NULL;

-- The following code is the RIGHT JOIN version of the previous anti-join. RIGHT JOIN preserves every row
-- from the table in the JOIN clause, so film is placed there and inventory moves to FROM. The ON condition
-- and the IS NULL filter are unchanged, and the result is identical at 42 films. A RIGHT JOIN and a LEFT
-- JOIN can express the same question, differing only in which table is preserved and therefore in table
-- order. LEFT JOIN is preferred in practice because it keeps the anchor table in the first position, which
-- reads top to bottom.
SELECT f.title
    FROM inventory AS i
    RIGHT JOIN film AS f
    ON i.film_id = f.film_id
    WHERE i.inventory_id IS NULL;
    
-- The following code returns a list of movie title pairings that share the same length. Since both title
-- and length live in the same table, the film table is referenced twice (f1 and f2) so its rows can be
-- evaluated against each other. The WHERE clause with the < operator on film_id does two jobs at once.
-- It eliminates self-pairings, since a film matched with itself has equal ids that fail the less-than
-- test, and it removes duplicate pairs (movie 1/movie 2 and movie 2/movie 1) by keeping only the ordering
-- where f1.film_id < f2.film_id. film_id is used rather than title because it is the primary key and
-- guaranteed unique.
SELECT f1.title AS f1_title, f2.title AS f2_title, f1.length
    FROM film AS f1
    JOIN film AS f2
    ON f1.length = f2.length
    WHERE f1.film_id < f2.film_id
    ORDER BY f1.length;
    
	

-- -------------------------------------------------------------
-- TIER 4: Subqueries
-- Constructs: scalar subquery, IN subquery, correlated subquery,
--             EXISTS, NOT EXISTS, derived table in FROM
-- -------------------------------------------------------------

-- The following code returns the titles in the title column and the rental rate from
-- the rental_rate column where the rental rates are higher than the average rate.
-- In order to know what the average rental rate is, a subquery was used in the comparison
-- logic. This subquery finds the rental rate averages for all the films, and then the 
-- main query uses this value for the comparison logic in the WHERE clause. NOTE: the 
-- special thing learned from this scalar subquery is that the logic within () is only computed
-- once since the average of the table is not going to change
SELECT title, rental_rate
FROM film 
WHERE rental_rate > (SELECT AVG(rental_rate) FROM film);

-- The following code returns the first and last names of customers who live in a city located in India.
-- The subquery answers one question on its own, which cities are in India, by joining city to country and
-- returning those city_ids. The main query joins customer to address to get each customer's city_id, and
-- the IN check keeps only the customers whose city_id shows up in the India list. The subquery returns
-- city_id rather than address_id because being in India is a property of the city, so that is the level
-- the filter should live at. = 'India' is used instead of LIKE 'india' since an exact match is wanted, and
-- LIKE with no wildcard is just a slower way of writing =. The capital I matters so it matches the value
-- stored in the table.
SELECT c.first_name, c.last_name
    FROM customer AS c
    JOIN address AS a ON a.address_id = c.address_id
    WHERE a.city_id IN (
        SELECT ci.city_id
        FROM city AS ci
        JOIN country AS co ON co.country_id = ci.country_id
        WHERE co.country = 'India'
    );

-- This is an alternate version of the query above. It cuts the four-table chain at a different point.
-- Here the subquery handles address, city, and country and returns address_ids, so the main query only
-- needs the customer table. Both return the same result. The difference is where the join work happens.
SELECT first_name, last_name
	FROM customer
    WHERE address_id IN (
		SELECT a.address_id
		FROM address as a
		JOIN city as ci ON ci.city_id = a.city_id
		JOIN country as co ON co.country_id = ci.country_id
		WHERE co.country LIKE 'India');

-- The following code returns films whose rental rate is higher than the average rental rate for their own
-- rating. This needs a correlated subquery because the benchmark changes per film. A PG film gets compared
-- to the PG average, an R film to the R average. The subquery references f1.rating from the outer query, so
-- it cannot run by itself and re-runs for each film using that film's rating. The WHERE inside
-- (f1.rating = f2.rating) narrows the inner rows down to just the films with the same rating, and AVG then
-- gives one number for that rating. I originally tried GROUP BY plus HAVING here, but that was wrong. Since
-- only one aggregated value is wanted, GROUP BY is not needed. Filtering with WHERE first means the average
-- only ever sees one rating's worth of films.
SELECT f1.title, f1.rental_rate, f1.rating
    FROM film AS f1
    WHERE f1.rental_rate > (
        SELECT AVG(f2.rental_rate)
        FROM film AS f2
        WHERE f1.rating = f2.rating
    );
    
-- The following code returns the first and last name of customers who have made at least one payment.
-- For each customer, the subquery checks the payment table for a row matching that customer's id. EXISTS
-- returns true or false based on whether the subquery returns any rows, and it stops as soon as the first
-- match is found. SELECT * is used inside because EXISTS only checks whether rows are returned, not what
-- those rows contain.
SELECT c.first_name, c.last_name
    FROM customer as c
    WHERE EXISTS (
        SELECT *
        FROM payment as p
        WHERE c.customer_id = p.customer_id);
 
-- The following code returns the first and last names of customers who have made no payment. This is the
-- reverse of the previous query. NOT EXISTS keeps the customer only when the subquery returns nothing.
-- This is an anti-join, the same idea as the films with no inventory query from Tier 3. Every customer in
-- Sakila has payments, so this returns zero rows, which is the correct result rather than an error.
-- NOTE on NOT IN versus NOT EXISTS: this could be written with NOT IN against a subquery of payment
-- customer_ids, but NOT IN returns wrong results if that list contains a NULL. SQL cannot resolve "not
-- equal to NULL" as true or false, it returns UNKNOWN, so a single NULL causes NOT IN to return no rows at
-- all. NOT EXISTS tests whether rows exist rather than comparing values, so a NULL cannot break it. NOT IN
-- is a comparison operator. EXISTS is a presence operator.
SELECT c.first_name, c.last_name
    FROM customer AS c
    WHERE NOT EXISTS (
        SELECT *
        FROM payment AS p
        WHERE c.customer_id = p.customer_id
    );
 
-- The following code returns the customer_id and total amount paid for customers whose total payments
-- exceed 150 dollars. The total is computed inside a derived table, which is a subquery placed in the FROM
-- clause. The derived table must be given an alias (cust_payment) or MySQL will error. HAVING is used
-- rather than WHERE because SUM is an aggregate and can only be filtered after grouping.
-- NOTE: this derived table is actually redundant. The outer query just re-selects the same values, so the
-- inner query alone returns the same result. It is kept here to show the mechanism.
SELECT customer_id, tot_pay
    FROM (
        SELECT customer_id, SUM(amount) AS tot_pay
        FROM payment
        GROUP BY customer_id
        HAVING SUM(amount) > 150
    ) AS cust_payment;
 
 
-- The following code outputs the average total spending among higher-end customers, meaning those who
-- spent more than 150 dollars. This is where a derived table actually earns its place. It computes an
-- average of sums, an aggregate of an aggregate, which cannot be done in a single grouped query since
-- AVG(SUM(amount)) is not allowed. The inner query produces each customer's total, and the outer query
-- averages those totals. The outer query is doing real work the inner one cannot do on its own.
SELECT AVG(tot_pay) AS average_pay
    FROM (
        SELECT SUM(amount) AS tot_pay
        FROM payment
        GROUP BY customer_id
        HAVING SUM(amount) > 150
    ) AS cust_payment;
 
-- -------------------------------------------------------------
-- TIER 5: CTEs
-- Constructs: single CTE, chained CTEs, CTE vs subquery judgment
-- -------------------------------------------------------------


-- The following code returns the average total spending among higher-end customers (i.e., those who spent
-- more than 150 dollars). It is the same logic as the derived table version above, rewritten as a CTE. The
-- WITH block defines a named result set that groups payment by customer_id, sums each customer's payments,
-- and uses HAVING to keep only totals above 150. The main query then takes AVG over those totals. A CTE and
-- a derived table produce the identical result. The difference is only structure. The CTE lifts the subquery
-- out of the FROM clause, names it, and defines it up front, so the query reads top to bottom instead of
-- inside out.
WITH high_spender_totals AS (
    SELECT SUM(amount) AS total_paid
    FROM payment
    GROUP BY customer_id
    HAVING SUM(amount) > 150
)
SELECT AVG(total_paid) AS avg_high_spender_pay
    FROM high_spender_totals;
 
 
-- The following code returns the average number of films per category, counting only categories that have
-- more than 50 films. The CTE joins category to the film_category junction table, groups by category name,
-- counts the films in each category, and uses HAVING to keep only categories with more than 50 films. That
-- gives one row per qualifying category with its film count. The main query then takes AVG over the
-- film_count column with no GROUP BY, which collapses all the qualifying categories into a single number.
-- NOTE: the join to film_category is doing real work here. Counting from the category table alone would
-- return 1 for every category, since category has one row per category. The join pairs each category with
-- all its films, which is what gives COUNT something real to count.
WITH large_categories AS (
    SELECT c.name AS category_name, COUNT(fc.film_id) AS film_count
    FROM category AS c
    JOIN film_category AS fc ON c.category_id = fc.category_id
    GROUP BY category_name
    HAVING film_count > 50
)
SELECT AVG(film_count) AS avg_films_per_category
    FROM large_categories;
 
 
-- The following code returns the single category with the highest average rental rate among its films, along
-- with that average. It uses two chained CTEs. The first pairs each category name with its film_ids. The
-- second reads from the first, joins it to the film table on film_id to reach each film's rental rate, then
-- groups by category name and averages the rental rates. The main query orders by average rental rate
-- descending and uses LIMIT 1 to keep only the top row. ORDER BY plus LIMIT 1 is the standard way to select
-- the single highest of something, and it avoids the problem of pairing a MAX aggregate with a
-- non-aggregated category name.
-- NOTE: if two categories tied for the highest average, LIMIT 1 would arbitrarily return only one of them
-- and hide the tie. A window function (RANK) would be needed to keep all tied rows.
WITH category_films AS (
    SELECT c.name AS category_name, fc.film_id
    FROM category AS c
    JOIN film_category AS fc ON c.category_id = fc.category_id
),
category_avg_rates AS (
    SELECT category_films.category_name,
           AVG(f.rental_rate) AS avg_rental_rate
    FROM film AS f
    JOIN category_films ON category_films.film_id = f.film_id
    GROUP BY category_films.category_name
)
SELECT category_name, avg_rental_rate
    FROM category_avg_rates
    ORDER BY avg_rental_rate DESC
    LIMIT 1;
    
-- -------------------------------------------------------------
-- TIER 6: Window Functions
-- Constructs: ROW_NUMBER, RANK, DENSE_RANK, PARTITION BY,
--             running totals, LAG, LEAD, top-N-per-group pattern
-- -------------------------------------------------------------

-- The following code outputs the title, rating, and rental rate of every film, along with the average rental
-- rate for that film's rating category, while keeping all 1000 film rows. A window function performs its
-- calculation without collapsing rows, unlike GROUP BY, which would reduce the output to one row per rating.
-- AVG is the function, OVER is the clause that turns it into a window function, and PARTITION BY inside OVER
-- defines the set of rows each calculation looks at. PARTITION BY rating scopes the average to the rows
-- sharing that film's rating, so each film is stamped with its own category's average. Two films with the
-- same rating show the same value, since the average is computed over the same partition for both.
SELECT title, rating, rental_rate, AVG(rental_rate) OVER (PARTITION BY rating) AS avg_rental_rate
FROM film;

-- The following code outputs the title, rating, and rental rate of every film along with a sequential number
-- ranking each film within its rating category from most to least expensive. ROW_NUMBER assigns a unique
-- number to each row rather than aggregating. PARTITION BY rating restarts the numbering for each rating
-- category, and the ORDER BY inside the OVER clause determines the sequence within each partition. Because
-- rental rate takes only three values, many films tie, and ROW_NUMBER breaks those ties arbitrarily since no
-- tiebreaker column was specified.
SELECT title,
       rating,
       rental_rate,
       ROW_NUMBER() OVER (PARTITION BY rating ORDER BY rental_rate DESC) AS price_rank_in_rating
    FROM film;
    

-- The following code outputs the title, rating, and rental rate of every film alongside three ranking columns
-- that share the same window, so their handling of ties can be compared side by side. ROW_NUMBER assigns a
-- unique sequential number and ignores ties, so tied rows are ordered arbitrarily unless a tiebreaker is added
-- to the ORDER BY. RANK gives tied rows the same value and then skips ahead, leaving gaps that reflect how many
-- rows were tied above. DENSE_RANK gives tied rows the same value with no gaps, so its numbers count distinct
-- values rather than rows.
SELECT title,
       rating,
       rental_rate,
       RANK() OVER (PARTITION BY rating ORDER BY rental_rate DESC) AS rank_by_rating,
       DENSE_RANK() OVER (PARTITION BY rating ORDER BY rental_rate DESC) AS dense_rank_in_rating,
       ROW_NUMBER() OVER (PARTITION BY rating ORDER BY rental_rate DESC) AS row_num_in_rating
    FROM film;


-- The following code outputs each payment made by customer 1 in chronological order, alongside the amount of
-- that customer's previous payment. LAG reaches back to a prior row within the partition rather than
-- aggregating across rows. The ORDER BY inside the OVER clause defines what previous means, so it is required
-- rather than optional. The first payment has no prior row, so LAG returns NULL there. A default value of 0
-- was deliberately not used, because 0 would assert that the previous payment was zero dollars rather than
-- that no previous payment exists.
SELECT payment_date,
       amount, 
       LAG(amount, 1) OVER (PARTITION BY customer_id ORDER BY payment_date) AS previous_payment
	FROM payment
	WHERE customer_id = 1;

-- The following code outputs the payment date, amount, previous payment amount, and the change between the two
-- for customer 1. In order to do this, LAG was used to pull the amount from the previous row. Subtracting the
-- lagged amount from the current amount gives the change. The first row returns NULL for both columns since
-- there is no previous payment, and arithmetic with NULL returns NULL. A named window (w) was used so the OVER
-- clause does not have to be written twice.
SELECT payment_date,
       amount,
       LAG(amount, 1) OVER w AS previous_payment,
       amount - LAG(amount, 1) OVER w AS change_from_previous
    FROM payment
    WHERE customer_id = 1
    WINDOW w AS (PARTITION BY customer_id ORDER BY payment_date);

-- The following code outputs the payment date, amount, and a running total of everything customer 1 has paid
-- up to and including that payment. In order to do this, SUM was used as a window function with an ORDER BY
-- inside the window. The ORDER BY is what makes the sum accumulate, since it implicitly frames the window as
-- everything from the start of the partition through the current row. Without the ORDER BY, SUM would return
-- the customer's grand total on every row instead of a running total.
SELECT payment_date,
       amount,
       SUM(amount) OVER w AS running_total
    FROM payment
    WHERE customer_id = 1
    WINDOW w AS (PARTITION BY customer_id ORDER BY payment_date);

-- The following code outputs the films occupying the top three price positions within each rating category.
-- The window function was computed inside a CTE and then filtered in the outer query. Window functions are
-- evaluated in the SELECT step, which runs after WHERE, so the rank column does not exist yet when WHERE runs
-- and cannot be filtered there directly. Placing it in a CTE turns it into a plain column the outer query can
-- filter normally.
-- RANK gives tied films the same rank and then skips ahead. Since many films share the same rental rate, every
-- film at the top price receives rank 1, so this returns all of them rather than three per rating.
WITH ranking AS (
    SELECT title,
           rating,
           rental_rate,
           RANK() OVER (PARTITION BY rating ORDER BY rental_rate DESC) AS film_rank
    FROM film
)
SELECT *
    FROM ranking
    WHERE film_rank IN (1, 2, 3);


-- The following code outputs exactly three films per rating category, the three most expensive. This is the
-- same CTE structure as above, but ROW_NUMBER is used instead of RANK. ROW_NUMBER assigns a unique number to
-- every row and ignores ties, so filtering to three returns exactly three films per rating.
-- NOTE: rental_rate only takes three values in Sakila, so many films tie at the top price. No tiebreaker was
-- specified in the ORDER BY, so which three films come back is non-deterministic. The three films returned per
-- rating are an arbitrary selection from a much larger tied group, and this result should not be presented as
-- a meaningful ranking of top performers.
WITH ranking AS (
    SELECT title,
           rating,
           rental_rate,
           ROW_NUMBER() OVER (PARTITION BY rating ORDER BY rental_rate DESC) AS film_rank
    FROM film
)
SELECT *
    FROM ranking
    WHERE film_rank IN (1, 2, 3);

-- -------------------------------------------------------------
-- TIER 7: Conditional Logic
-- Constructs: CASE in SELECT, CASE inside aggregation,
--             CASE in ORDER BY
-- -------------------------------------------------------------

-- The following code returns the title and length of every film, along with a label classifying the film
-- as short, medium, or long based on its runtime. This is accomplished with a searched CASE, which checks
-- each WHEN condition from top to bottom and stops at the first one that matches. Because the first WHEN
-- already accounts for every film under 60 minutes, the second WHEN only needs to state its upper bound.
-- Writing length >= 60 AND length <= 120 would be redundant. The ELSE clause captures everything over 120
-- minutes. If no ELSE were included, any film that matched none of the conditions would return NULL.
SELECT title, length,
	CASE WHEN length < 60 THEN 'short' WHEN length <= 120 THEN 'medium' ELSE 'long' END AS length_classifier
 	FROM film;
    
-- The following code returns one row per rating, showing the total number of films with that rating
-- and the number of those films that are over 120 minutes long. This is accomplished by placing a CASE
-- inside the COUNT function. Aggregate functions ignore NULL values, and a CASE with no ELSE will
-- return NULL for any row that does not meet the condition. This means COUNT will only count the films
-- that matched. The value placed after THEN does not matter because COUNT is only checking that a value
-- is not NULL. A WHERE clause could not be used here since it would remove the short films from the
-- entire query, and they are still needed for the total count.
SELECT rating, 
count(*) as Film_Count,
count(case when length > 120 THEN 1 END) as film_over_120min
from film
group by rating;


-- The following code returns the proportion of films within each rating that are over 120 minutes long.
-- This is done by dividing the conditional count by the total count. The division operator in MySQL
-- returns a decimal value, so no casting is needed.
SELECT rating, 
count(*) as Film_Count,
count(case when length > 120 THEN 1 END) / count(*) as prop_over_120min
from film
group by rating;


-- The following code returns the same proportion as above, but uses a single aggregate function instead
-- of two. AVG adds up the values it receives and divides by how many values it saw, so a column made up
-- of 1s and 0s will average to the proportion of 1s. The ELSE 0 is necessary here. Without it, the films
-- under 120 minutes would return NULL, and AVG would drop them entirely. It would then divide the sum of
-- the 1s by the count of the 1s, which returns 1.0 for every rating. This would not produce an error, but
-- the output would be wrong. The ELSE clause determines whether the non-matching rows are included in the
-- denominator. Since COUNT should not see those rows, no ELSE is used. Since AVG needs those rows present
-- as zeros, ELSE 0 is used.
SELECT rating,
       AVG(CASE WHEN length > 120 THEN 1 ELSE 0 END) AS prop_over_120min
    FROM film
    GROUP BY rating;

-- The following code returns every distinct rating from the film table, sorted from least restrictive to
-- most restrictive rather than alphabetically. Sorting on the rating column directly would produce G,
-- NC-17, PG, PG-13, R, which is not a meaningful order. Placing a CASE inside the ORDER BY assigns each
-- rating a sort position, and SQL then orders by that computed number instead of the text itself. The
-- simple CASE form is used here, which names the column once and then compares it against each literal
-- value. This works because every condition is checking the same column against a fixed value. No ELSE
-- clause was included. If a rating appeared that was not listed, the CASE would return NULL for it, and
-- MySQL sorts NULL values first in ascending order, so that rating would appear at the top of the list.
SELECT DISTINCT rating
	FROM film
    ORDER BY CASE rating WHEN 'G' THEN 1 WHEN 'PG' THEN 2 WHEN 'PG-13' THEN 3 WHEN 'R' THEN 4 WHEN 'NC-17' THEN 5 END;

-- -------------------------------------------------------------
-- TIER 8: Set Operations
-- Constructs: UNION, UNION ALL, when to use each
-- -------------------------------------------------------------

-- The following code returns a combined list of every person in the staff and customer tables, along
-- with a column indicating which table each row came from. UNION stacks the results of two queries
-- vertically, adding rows rather than columns the way a JOIN would. Both queries must return the same
-- number of columns with compatible types, and the column names are taken from the first query, so the
-- alias in the second query is ignored. The table_origin column is a hardcoded string literal rather
-- than a column from either table. UNION removes duplicate rows, but it compares entire rows rather than
-- individual columns, so no rows are removed here. Even if a staff member and a customer shared a name,
-- the table_origin values would differ and the rows would not match. Since duplicates are not possible
-- in this query, UNION ALL would return the same 601 rows without performing the deduplication step.
SELECT first_name, last_name, 'staff' as table_origin
	from staff
    UNION
SELECT first_name, last_name, 'customer' as table_origin
	from customer;


-- The following code shows the difference between UNION and UNION ALL. Each query returns the customer_id
-- column from the rental table and the payment table. UNION ALL returns 32088 rows, which is the 16044
-- rentals plus the 16044 payments, since it keeps every row from both queries. Customer ids repeat many
-- times because customers rent and pay more than once. UNION returns 599 rows because it removes all
-- duplicates from the combined result, leaving one row per distinct customer id. That number matches the
-- row count of the customer table, which means every customer has at least one rental and one payment.
-- UNION ALL should be used unless duplicates specifically need to be removed, since the deduplication
-- step has a cost.
SELECT customer_id
	FROM rental
    UNION ALL
SELECT customer_id
	FROM payment;

SELECT customer_id
	FROM rental
    UNION
SELECT customer_id
	FROM payment;

-- -------------------------------------------------------------
-- TIER 9: Synthesis
-- Multi-construct queries combining all tiers.
-- Example target: top-grossing category per country and the
-- staff member who sold the most of it.
-- -------------------------------------------------------------
-- Question 1: For each country, find the single top-grossing film category, meaning the category whose
-- films generated the most total payment revenue from customers in that country. Return the country, the
-- category, and that total revenue.

-- The following code returns one row per country showing its top-grossing category. Payment is the anchor
-- table because it holds the amount being measured and carries a foreign key to both directions needed
-- here. The customer_id fans out to the country chain (customer, address, city, country) and the rental_id
-- fans out to the category chain (rental, inventory, film, film_category, category). The first CTE groups
-- by country and category and sums the payment amounts, which produces one row per country-category pair.
-- The second CTE reads from the first and applies ROW_NUMBER partitioned by country, so the ranking
-- restarts for each country and rank 1 is that country's highest-grossing category. The ranking has to be
-- computed in a CTE because window functions are evaluated in the SELECT step, which runs after WHERE, so
-- the rank column does not exist yet and cannot be filtered in the same query.
With country_category_revenue as (
    SELECT country, category.name as category, SUM(amount) as revenue
	FROM payment 
    join customer on customer.customer_id = payment.customer_id
    join address on address.address_id = customer.address_id
    join city on city.city_id = address.city_id
    join country on country.country_id = city.country_id
    join rental on rental.rental_id = payment.rental_id
    join inventory on inventory.inventory_id = rental.inventory_id
    join film on film.film_id = inventory.film_id
    join film_category on film_category.film_id = film.film_id
    join category on category.category_id = film_category.category_id
    group by country, category),
    ranked_categories as (
	SELECT country, category, revenue,
		ROW_NUMBER() OVER (partition by country order by revenue DESC) as category_ranking
        FROM country_category_revenue
        )
	SELECT country, category, revenue
    FROM ranked_categories
    WHERE category_ranking in (1);
    

-- Question 2: For each store, find the customer who has spent the most money there. 
-- Return the store id, the customer's first and last name, and the total that customer spent at that store.

-- The two queries below were used to work out which path to the store is the correct one. The customer
-- table has its own store_id, but it holds one value per customer, meaning the store the customer is
-- registered at rather than the store where a transaction happened. Joining through it would attribute
-- every payment to the customer's home branch. Checking the data showed that customers do rent from both
-- stores, so the two paths disagree and the customer.store_id path would produce wrong results.

-- This outputs one store per customer. If customers made purchases at multiple stores, using this
-- pathway to join the customers purchases by store would miss out on purchases made at stores
-- not displayed in this connection.
SELECT first_name, store_id
	from customer;

-- customer to payment table will link customers to multiple payments
select c.first_name, p.payment_id
	from customer as c
    JOIN payment as p on p.customer_id = c.customer_id;

-- The following code returns the top-spending customer at each store. The correct path to a store runs
-- through inventory, since an inventory row is a physical copy that lives at a specific store, so it
-- records where the transaction actually occurred. The chain runs store to inventory to rental to payment
-- to customer. The first CTE groups by store and customer and sums the payment amounts, producing one row
-- per customer per store. customer_id is included in the GROUP BY rather than relying on the names alone,
-- because two different customers could share a first and last name and would otherwise be merged into one
-- row. The second CTE applies RANK partitioned by store so the ranking restarts for each store. RANK was
-- chosen over ROW_NUMBER so that if two customers tied for the highest spend at a store, both would be
-- returned rather than one being dropped arbitrarily.
WITH customer_store_totals as (
select c.first_name, C.last_name, s.store_id, SUM(p.amount) as total_amount
	from store as s
    JOIN inventory on inventory.store_id = s.store_id
    JOIN rental on rental.inventory_id = inventory.inventory_id
    JOIN payment as p on p.rental_id = rental.rental_id
    JOIN customer as c on c.customer_id = p.customer_id
    -- WHERE c.first_name LIKE 'JOEL'
    GROUP BY store_id, c.first_name, c.last_name, c.customer_id),
ranked_spenders as (
	SELECT *, RANK() OVER (partition by store_id ORDER BY total_amount DESC) as amount_ranking
    FROM customer_store_totals)
    SELECT *
    FROM ranked_spenders
    WHERE amount_ranking in (1);
    
-- The following code returns every category with its total revenue and the percentage of overall revenue
-- that category represents, sorted from highest to lowest. The CTE joins payment out to category through
-- the rental, inventory, film, and film_category chain, and sums the payment amounts for each category. A
-- RIGHT JOIN is used on category so that any category with no payments is still returned. An inner join
-- would drop it, since the chain starts at payment and a category with no payments has no payment row to
-- ride in on. When a category has no matching payments, SUM returns NULL rather than 0, so the CASE
-- converts that to 0. This matters because NULL propagates through arithmetic, and the percentage
-- calculation in the main query would also return NULL. The main query then divides each category's
-- revenue by the grand total, which is obtained with a scalar subquery. The total is a single value, so it
-- does not need to be its own CTE or joined to anything. It can sit directly inside the expression the same
-- way a scalar subquery sits inside a WHERE clause. Every category in Sakila has revenue, so no zero rows
-- appear, but the query handles that case correctly if one existed.
with category_revenue as (
select 
	(CASE WHEN SUM(p.amount) IS NULL THEN 0 ELSE SUM(p.amount) END) as category_amount, cat.name
	from payment as p
    JOIN rental on rental.rental_id = p.rental_id
    JOIN inventory on inventory.inventory_id = rental.inventory_id
    JOIN film on film.film_id = inventory.film_id
    JOIN film_category on film_category.film_id = film.film_id
    RIGHT JOIN category as cat on cat.category_id = film_category.category_id
    GROUP BY cat.name)
SELECT name, category_amount, 
	(category_amount / (SELECT sum(category_amount) from category_revenue)) * 100 AS pct_total
    FROM category_revenue
    ORDER BY category_amount DESC;

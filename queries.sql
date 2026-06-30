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

-------------------------------------------------------------
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
 
-------------------------------------------------------------
-- TIER 3: Joins
-- Constructs: INNER JOIN, LEFT JOIN, RIGHT JOIN,
--             multi-hop geographic chain, junction table joins,
--             self-joins, aliasing when two FKs hit the same table
-- -------------------------------------------------------------

-- The following query joins the first and last name from the staff table with the amount and
-- payment id from the payment table. This is accomplished using an INNER JOIN on staff_id, the
-- column shared by both tables. Table aliases (s for staff, p for payment) are used, and every
-- column is qualified with its alias for readability and to avoid ambiguity.
-- Note: Because INNER JOIN was used, the output contains only payments that have a matching staff
-- record on staff_id. Any row in either table without a match on staff_id is excluded. The result
-- has 16044 rows, one per payment, because each payment matches exactly one staff member while each
-- staff member matches many payments. In a one-to-many relationship, an INNER JOIN yields one row
-- per row on the "many" side (payment), with the "one" side (staff) repeating across its matches.
SELECT s.first_name, s.last_name, p.amount, p.payment_id
    FROM staff AS s
    INNER JOIN payment AS p
    ON s.staff_id = p.staff_id;
    
-- Return the first_name, last_name, and the name of the city each customer lives in.
-- This following syntax combines the first and last name columns from
-- the customer table with the city column of the city table. 
-- Given that there is not a direct link between customer 
-- and city, two joins were used: 1) customer with address and
-- 2) address with city.
SELECT c.first_name, c.last_name, ci.city
	FROM customer as c
    JOIN address as a
    ON c.address_id = a.address_id
    JOIN city as ci
    ON ci.city_id = a.city_id;

-- The following code returns the first_name and last_name from the actor table and the title from
-- the film table, but only for the actor named Nick Wahlberg. Because actor and film have no direct
-- relationship, they are linked through the film_actor junction table: actor joins to film_actor on
-- actor_id, then film_actor joins to film on film_id. The result is ordered alphabetically by title.
-- NOTE: In SQL's logical processing order the joins assemble the combined rows first, then the WHERE
-- clause filters those joined rows, and finally the SELECT columns are chosen and ORDER BY is applied.
-- WHERE appears near the end of the written query by convention, but it filters the joined rows before
-- the final output is selected and ordered; it does not literally run last.
SELECT a.first_name, a.last_name, f.title
    FROM actor AS a
    JOIN film_actor AS fa
    ON fa.actor_id = a.actor_id
    JOIN film AS f
    ON f.film_id = fa.film_id
    WHERE a.first_name = 'Nick' AND a.last_name = 'Wahlberg'
    ORDER BY f.title;

-- The following code returns the titles from the film table where there is NO linking entry in the
-- inventory table, meaning films that have no physical copies. This is accomplished with a LEFT JOIN,
-- which returns all titles from the film table regardless of whether a matching inventory row exists.
-- Films with no match have NULL in every inventory-side column. The WHERE clause then filters on
-- inventory_id IS NULL to keep only those unmatched films, where no inventory row exists. This is the
-- anti-join pattern: LEFT JOIN plus IS NULL on the right side isolates the left rows that have no match.
SELECT f.title
	FROM film as f
    LEFT JOIN inventory as i
    ON f.film_id = i.film_id
    WHERE i.inventory_id IS NULL;

-- The following code is the RIGHT JOIN equivalent of the previous anti-join, returning the titles of
-- films that have no inventory. Because RIGHT JOIN preserves every row from the table in the JOIN
-- clause, film is placed there (and inventory moves to FROM) so that all films are kept regardless of
-- whether a matching inventory row exists. The ON condition and the IS NULL filter are unchanged from
-- the LEFT JOIN version, and the result is identical: 42 films. This demonstrates that a RIGHT JOIN
-- and a LEFT JOIN can express the same question, differing only in which table is preserved and
-- therefore in table order. LEFT JOIN is preferred in practice because it keeps the anchor table (the
-- table the question is about) in the natural first position, which reads top to bottom; RIGHT JOIN
-- forces the anchor table into the JOIN clause and reads backwards.
SELECT f.title
    FROM inventory AS i
    RIGHT JOIN film AS f
    ON i.film_id = f.film_id
    WHERE i.inventory_id IS NULL;
    
-- The following code returns a list of movie title pairings that share the same length. Since both
-- title and length live in the same table, the film table is referenced twice (aliased f1 and f2) so
-- its rows can be evaluated against each other. The two copies are joined on equal length, pairing up
-- films of matching runtime. The WHERE clause with the < operator on film_id does two jobs at once:
-- it eliminates self-pairings (a film matched with itself, where the ids are equal and so fail the
-- less-than test), and it removes duplicate pairs (e.g. movie 1/movie 2 and movie 2/movie 1) by
-- keeping only the single ordering where f1.film_id < f2.film_id. film_id is used rather than title
-- because it is the primary key and guaranteed unique, so the deduplication is robust even if two
-- films happened to share a title. Results are ordered by length to group equal-length pairs together.
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




-- -------------------------------------------------------------
-- TIER 5: CTEs
-- Constructs: single CTE, chained CTEs, CTE vs subquery judgment
-- -------------------------------------------------------------




-- -------------------------------------------------------------
-- TIER 6: Window Functions
-- Constructs: ROW_NUMBER, RANK, DENSE_RANK, PARTITION BY,
--             running totals, LAG, LEAD, top-N-per-group pattern
-- -------------------------------------------------------------




-- -------------------------------------------------------------
-- TIER 7: Conditional Logic
-- Constructs: CASE in SELECT, CASE inside aggregation,
--             CASE in ORDER BY
-- -------------------------------------------------------------




-- -------------------------------------------------------------
-- TIER 8: Set Operations
-- Constructs: UNION, UNION ALL, when to use each
-- -------------------------------------------------------------




-- -------------------------------------------------------------
-- TIER 9: Synthesis
-- Multi-construct queries combining all tiers.
-- Example target: top-grossing category per country and the
-- staff member who sold the most of it.
-- -------------------------------------------------------------

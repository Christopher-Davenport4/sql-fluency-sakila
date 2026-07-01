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

-- The following code returns the first and last names of customers who live in a city located in
-- India. The logic is split across two levels. The subquery answers one self-contained question:
-- which city_ids belong to cities in India? It joins city to country and returns that list of
-- city_ids. The main query then connects each customer to their address (customer holds address_id,
-- and address holds the city_id) and uses IN to keep only the customers whose city_id appears in the
-- India list. The subquery returns city_id rather than address_id because "being in India" is a
-- property of a city, so the subquery answers the question at the level where the filter actually
-- lives. The country is matched with = 'India' (exact match, correct casing) rather than LIKE, since
-- LIKE without a wildcard is just a disguised equality and relying on lowercase 'india' would fail
-- under a case-sensitive collation.
SELECT c.first_name, c.last_name
    FROM customer AS c
    JOIN address AS a ON a.address_id = c.address_id
    WHERE a.city_id IN (
        SELECT ci.city_id
        FROM city AS ci
        JOIN country AS co ON co.country_id = ci.country_id
        WHERE co.country = 'India'
    );
-- or 
SELECT first_name, last_name
	FROM customer
    WHERE address_id IN (
		SELECT a.address_id
		FROM address as a
		JOIN city as ci ON ci.city_id = a.city_id
		JOIN country as co ON co.country_id = ci.country_id
		WHERE co.country LIKE 'India');

-- The following code returns the title, rental rate, and rating of every film whose rental rate is
-- greater than the average rental rate of films sharing its own rating. For example, a PG film is
-- compared against the PG average and an R film against the R average. This requires a correlated
-- subquery, meaning the inner query references f1.rating from the outer query, so it cannot run on
-- its own and instead re-runs once per outer film, each time using that film's rating. The subquery's
-- WHERE clause (f1.rating = f2.rating) restricts the inner rows to only films matching the current
-- outer film's rating, and AVG then returns a single value, the average rental rate for that one
-- rating. No GROUP BY is needed because the WHERE filter has already reduced the rows to one rating's
-- worth, so the aggregate treats that filtered subset as one implicit group and returns exactly one
-- number. This contrasts with a scalar subquery (Question 1), which computes one global average once
-- as a constant. Here the benchmark changes per outer row, which is what makes the subquery correlated.
SELECT f1.title, f1.rental_rate, f1.rating
    FROM film AS f1
    WHERE f1.rental_rate > (
        SELECT AVG(f2.rental_rate)
        FROM film AS f2
        WHERE f1.rating = f2.rating
    );
    
-- The following code returns the first name and the last name of customers who
-- have made at least one payment. This is accomplished through a subquery and 
-- EXISTS clause. The EXISTS clause returns a true or false value based on whether the
-- subquery after it returns any rows or not. The subquery selectively returns rows of data 
-- in the payment table based on its match to a customer id in the customer table
-- if customer id exists in both tables, data is present in the payment table, and 
-- the WHERE EXISTS clause returns true, selecting the first and last name of
-- that customer.
SELECT c.first_name, c.last_name
    FROM customer as c
    WHERE EXISTS (
        SELECT *
        FROM payment as p
        WHERE c.customer_id = p.customer_id);
 
-- Q2: Return the first and last names of customers who live in a city in India.
-- I split this into a subquery and a main query. The subquery answers one question on its own,
-- which cities are in India, by joining city to country and returning those city_ids. The main
-- query then joins customer to address so I can get each customer's city_id, and the IN check keeps
-- only the customers whose city_id shows up in the India list. I had the subquery return city_id
-- instead of address_id because being in India is really a property of the city, so that is the
-- level the filter should live at. I used = 'India' instead of LIKE 'india' since I want an exact
-- match, not a pattern, and LIKE with no wildcard is just a slower way of writing =. The capital I
-- matters too so it matches the value stored in the table.
SELECT c.first_name, c.last_name
    FROM customer AS c
    JOIN address AS a ON a.address_id = c.address_id
    WHERE a.city_id IN (
        SELECT ci.city_id
        FROM city AS ci
        JOIN country AS co ON co.country_id = ci.country_id
        WHERE co.country = 'India'
    );


-- Q3: Return films whose rental rate is higher than the average rental rate for their own rating.
-- This one needed a correlated subquery because the benchmark changes per film. A PG film gets
-- compared to the PG average, an R film to the R average, and so on. The subquery references
-- f1.rating from the outer query, so it can't run by itself, it re-runs for each film using that
-- film's rating. The WHERE inside (f1.rating = f2.rating) narrows the inner rows down to just the
-- films with the same rating, and then AVG gives me one number for that rating. I originally tried
-- GROUP BY plus HAVING here, but that was wrong. Since I only want one aggregated value, I don't
-- need GROUP BY. Filtering with WHERE first means the average only ever sees one rating's worth of
-- films, so it returns a single value instead of computing all five and throwing four away.
SELECT f1.title, f1.rental_rate, f1.rating
    FROM film AS f1
    WHERE f1.rental_rate > (
        SELECT AVG(f2.rental_rate)
        FROM film AS f2
        WHERE f1.rating = f2.rating
    );


-- Q4: Return customers who have made at least one payment, using EXISTS.
-- For each customer, the subquery looks in the payment table for a row matching that customer's id.
-- EXISTS just checks whether any rows come back, true or false, it doesn't care what's in them.
-- The moment it finds one match it stops and returns true, so the customer gets kept. That's why I
-- can write SELECT * in there, EXISTS ignores what I select and only cares that rows exist.
SELECT c.first_name, c.last_name
    FROM customer AS c
    WHERE EXISTS (
        SELECT *
        FROM payment AS p
        WHERE c.customer_id = p.customer_id
    );

 
-- The following code returns the first and last names of customers who have made no payment. This is
-- the reverse of the previous query and uses NOT EXISTS. For each customer, the subquery checks the
-- payment table for a matching row, and NOT EXISTS keeps the customer only when the subquery returns
-- nothing. This is an anti-join, the same idea as the films with no inventory query from Tier 3.
-- Because every customer in Sakila has payments, this returns zero rows, which is the correct result
-- rather than an error.
-- Note on NOT IN versus NOT EXISTS: this same question could be written with NOT IN against a subquery
-- of payment customer_ids, but NOT IN returns wrong results if that list contains a NULL. SQL cannot
-- resolve "not equal to NULL" as true or false, so a single NULL causes NOT IN to return no rows at
-- all. NOT EXISTS tests whether rows exist rather than comparing values, so a NULL cannot break it.
-- For anti-joins where the tested column may contain NULLs, NOT EXISTS is the safer choice.
SELECT c.first_name, c.last_name
    FROM customer AS c
    WHERE NOT EXISTS (
        SELECT *
        FROM payment AS p
        WHERE c.customer_id = p.customer_id
    );
 
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

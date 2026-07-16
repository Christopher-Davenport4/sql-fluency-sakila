# Project 3: Learning Log

This file captures patterns, gotchas, and conceptual distinctions as they surface.
Updated continuously throughout the project. The goal is to turn repetition into
retained understanding.

---

## Tier 0: Schema Orientation

**Junction tables resolve many-to-many relationships.**
A junction table holds two foreign keys, one pointing to each side of the relationship.
One row represents one link between two entities. Sakila has two: film_actor and film_category.

**The geographic chain runs four tables deep.**
customer -> address -> city -> country
Joined on address_id, city_id, country_id respectively.
This chain appears in any query that needs customer location and must be written in full each time.

**Two foreign keys can point to the same table independently.**
Both staff and store have their own address_id column, both pointing to the address table.
When both are needed in the same query, the address table must be joined twice using aliases
to distinguish which join is serving which purpose.

**staff.store_id is a foreign key to store.**
Each staff member belongs to exactly one store. The foreign key lives in staff, not store.

---

## Environment Notes

**Forward slashes required in MySQL client file paths on Windows.**
The MySQL SOURCE command interprets backslashes as escape characters.
Use forward slashes instead: SOURCE C:/path/to/file.sql;

**PATH must point to MySQL Server bin, not MySQL Shell bin.**
MySQL Shell (C:\Program Files\MySQL\MySQL Shell 8.0\bin) does not contain mysql.exe.
The correct PATH entry is: C:\Program Files\MySQL\MySQL Server 8.0\bin

**Load schema before data, always.**
The data file assumes tables already exist. Running data first produces immediate errors.

---

## Tier 1: Single-Table Fundamentals

**LIKE is pattern matching, not equality.**
`=` requires an exact match. `LIKE` matches against a pattern with wildcards.
`WHERE last_name = 'S%'` looks for the literal two-character string "S%" and matches nothing.
The two wildcards are `%` (any sequence of zero or more characters) and `_` (exactly one character).
Wildcard placement controls anchoring: `'S%'` starts with S, `'%S'` ends with S, `'%S%'` contains S anywhere.
To find a value anywhere inside a string, wrap it in `%` on both sides.

**COUNT(*) counts rows; COUNT(column) counts non-NULL values.**
`COUNT(*)` counts every row matching the WHERE condition, NULLs included.
`COUNT(column)` counts only rows where that column is not NULL.
The difference between the two equals the number of NULLs in that column. Useful data-quality check.

**Cannot mix aggregated and non-aggregated columns without GROUP BY.**
`SELECT title, COUNT(*) FROM film` throws an error under only_full_group_by.
COUNT collapses many rows into one value, but title exists per row, so MySQL cannot reconcile them.
This is the conceptual bridge into Tier 2 aggregation.

**The datetime BETWEEN trap. (Most important gotcha of this tier.)**
On a plain DATE column, BETWEEN is clean.
On a DATETIME column, `BETWEEN '2005-07-01' AND '2005-08-01'` is buggy:
the upper bound is read as midnight `'2005-08-01 00:00:00'`, and because BETWEEN is inclusive,
a record stamped exactly at that midnight is wrongly included as July.
Ending the range at the last day instead (`'2005-07-31'`) wrongly excludes everything after
midnight on the 31st.
The fix is a half-open range, correct by construction:
  `WHERE d >= '2005-07-01' AND d < '2005-08-01'`
`>=` includes the first instant, `<` excludes the first instant of the next period.
Conciseness is not worth a correctness risk. Use the half-open pattern as the default for datetimes.

**Terminology precision.**
`>=` and `<` are comparison (relational) operators.
`AND`, `OR`, `NOT` are Boolean operators.
A single query often uses both: comparisons inside each condition, a Boolean to join them.

**IN is preferable to chained OR.**
`WHERE rental_rate IN (0.99, 2.99)` is more readable, scales cleanly, and is edited in one place.
`NOT IN` excludes a list, but carries a NULL gotcha: if the column or list contains NULL,
NOT IN can silently drop rows. Safe in Sakila's rating column (no NULLs), but prefer NOT EXISTS
when NULLs are possible. Revisit in Tier 4.

**IS NULL / IS NOT NULL, never = NULL.**
NULL does not equal anything, so equality operators fail on it.
Checking for NULLs is a standard first step before analysis.
Finding zero NULLs (as with customer.email) is itself a meaningful data-quality finding.

**Documentation discipline.**
Describe what a query does mechanically, not a real-world label inferred from the result.
"Films not rated G, PG, or PG-13" is correct; "adults-only films" is an interpretation that
the query logic does not actually enforce.

---

## Tier 2: Aggregation

**GROUP BY is not an aggregation function.**
GROUP BY is a clause that partitions rows into groups. The aggregate functions
(COUNT, SUM, AVG, MIN, MAX) are separate and compute one value per group.
Keeping these two ideas distinct is the key to the whole tier.

**GROUP BY produces the same distinct values as DISTINCT, plus the ability to aggregate.**
`SELECT rating FROM film GROUP BY rating` returns the same rows as
`SELECT DISTINCT rating FROM film`. GROUP BY is the more powerful form because it
lets you attach an aggregate to each group.

**Aggregation can happen without GROUP BY.**
If no GROUP BY is present, the aggregate treats the entire table as one single group
and returns one summary row. `SELECT MIN(amount), MAX(amount), AVG(amount) FROM payment`
collapses all rows into one. Aggregation is present; grouping is simply absent.

**The SELECT rule: grouped or aggregated, nothing else.**
Every column in the SELECT must either appear in the GROUP BY or be wrapped in an
aggregate function. Reason: each output row is a collapsed group, and every value in
that row must be unambiguous. A GROUP BY column is unambiguous because it holds one
constant value within the group. An aggregate is unambiguous because it deliberately
collapses many values into one. A bare non-grouped column is ambiguous (the group holds
many values, SQL cannot pick one) and throws an error. This is the same error as the
Tier 1 `SELECT title, COUNT(*)` failure.

**WHERE vs HAVING. (The central concept of the tier.)**
WHERE filters individual rows BEFORE grouping. HAVING filters groups AFTER aggregation.
If a condition references an aggregate (COUNT, SUM, etc.), it must go in HAVING because
the aggregate does not exist until after grouping. If a condition references a raw column
value, it goes in WHERE, both because it must (the row-level value is what is being tested)
and for efficiency (filtering rows early shrinks the data before the expensive grouping step).
Interview phrasing: "WHERE filters rows before aggregation, HAVING filters groups after."

**Multi-column GROUP BY groups by the combination.**
`GROUP BY customer_id, staff_id` creates one group per unique PAIRING of the two columns,
not one group per column separately. Produces more rows than grouping by either alone.

**The common reporting pattern: aggregate then order by the aggregate.**
`GROUP BY entity, SUM/COUNT the metric, ORDER BY that metric DESC` is the shape behind
"top N customers by revenue," "top products by units sold," etc. Extremely common.

**ROUND for formatting aggregates.**
`ROUND(AVG(amount), 2)` nests the aggregate inside ROUND; the second argument is the
number of decimal places. AVG often returns long decimals, so round for readability.

**Aliasing discipline (recurring).**
Prefer clean snake_case aliases (avg_rental_rate, film_count). Avoid quoted aliases with
spaces or symbols ('Average Rental Rate') because they must be backtick-wrapped everywhere
downstream. Avoid aliasing an aggregate with the same name as a grouped column (e.g. naming
a count "rating" when grouping by rating) because it shadows the column and causes ambiguity
in ORDER BY and subqueries. Display-friendly capitalization belongs in the BI tool, not the query.

**Documentation discipline (recurring).**
A SELECT returns a RESULT SET, not a table. A table is a persistent stored object created
with CREATE TABLE. Reserve the word "table" for actual stored tables. This distinction matters
before Tier 4 (derived tables, CTEs) and views.

---

## Tier 3: Joins

**The core mental model.**
Every join combines rows from two tables based on a relationship, almost always a foreign
key matching a primary key. The ON clause states that relationship. The join condition is
where you declare how the two tables connect.

**INNER JOIN is about matches, not NULLs.**
INNER JOIN returns a row only when a row in one table has a matching row in the other on the
join condition. Unmatched rows are DROPPED from both sides. This is the defining feature.
Do NOT think of INNER JOIN as a NULL check; think of it as "keep only the rows that find a
match." (NULLs become relevant in LEFT/RIGHT JOIN, where unmatched rows are kept and the
missing side is filled with NULL.)

**JOIN defaults to INNER JOIN.**
Writing `JOIN` alone is identical to `INNER JOIN` in MySQL. Writing INNER explicitly is
clearer for readers but not required.

**Always alias tables and qualify every column in a join.**
Use short aliases (`FROM staff AS s`) and qualify every column (`s.first_name`), even
unambiguous ones. Two reasons: readability (the reader instantly sees each column's source),
and safety (a column that is unique today may later be added to the other table, breaking an
unqualified query with an ambiguity error). A column that exists in BOTH tables (like staff_id)
MUST be qualified or MySQL throws an "ambiguous column" error.

**Predict the row count as a sanity check.**
In a one-to-many relationship, an INNER JOIN yields one row per row on the "many" side,
provided each many-side row has a match. Example: staff (2 rows) joined to payment (16044 rows)
on staff_id returns 16044 rows, one per payment, with staff fields repeating. Before trusting
any join, predict its row count from the relationship. A result far larger than expected usually
signals an unintended many-to-many fan-out, one of the most common join bugs.

**Watch the Workbench 1000-row display cap.**
The Workbench result grid caps its display (often at 1000 rows) and shows "1000 row(s)" even
when the true result is larger. To get the real count, wrap the query in SELECT COUNT(*).

**The multi-hop chain (the gap-closing pattern).**
To reach a table with no direct relationship, chain joins hop by hop. The geographic chain:
  customer -> address (on address_id) -> city (on city_id) -> country (on country_id)
Each new JOIN connects back to a table already in the query via its alias. This four-table
chain is the backbone of any "by city" or "by country" analysis of customers. Extendable one
hop at a time.

**The junction-table bridge (many-to-many).**
To join two tables in a many-to-many relationship, route through the junction table that holds
both foreign keys. Example, films an actor appeared in:
  actor -> film_actor (on actor_id) -> film (on film_id)
One row in the junction table is one pairing, so the join yields one output row per pairing.

**Junction tables use a composite primary key.**
A junction table's primary key is the COMBINATION of its two foreign keys (e.g. actor_id +
film_id together), not either alone. This makes each PAIRING unique: an actor_id can repeat
across films and a film_id can repeat across actors, but the specific pair appears exactly once.
This composite key is what makes the many-to-many relationship work without duplicate pairings.

**Logical processing order (why WHERE is not "run last").**
SQL processes joins first (assembling combined rows), then WHERE (filtering those rows), then
SELECT (choosing columns), then ORDER BY. WHERE sits near the end of the WRITTEN query by
convention, but it filters the joined rows before the output is selected and ordered; it does
not literally execute last. ORDER BY and column selection happen after WHERE.

**Documentation discipline (recurring).**
A SELECT returns a RESULT SET, not a table. Stop writing "creates a table" for a SELECT.

**LEFT JOIN keeps every left-table row; unmatched right columns become NULL.**
LEFT JOIN preserves every row from the left (FROM) table. If a left row has a match on the
right, the right columns fill in normally. If it has no match, the left row is KEPT anyway and
every right-table column comes back NULL. Those NULLs are meaningful: they mark left rows that
found no match. This is where NULLs legitimately enter a join result.

**The anti-join pattern.**
LEFT JOIN the table you want everything from, then filter WHERE the right side IS NULL. This
isolates exactly the left rows with NO match on the right. Uses: "films with no inventory,"
"customers who never rented," "products never sold." Same shape every time.

**Test the right table's PRIMARY KEY for the IS NULL filter.**
In an anti-join, filter the NULL check on the right table's primary key (or any guaranteed
non-NULL column), never a nullable column. Reason: a primary key is never NULL in a real row,
so a NULL there can ONLY mean "no match." A nullable column's NULL is ambiguous: it could mean
"no match" OR "matched but that column was empty," which would corrupt the filter.

**Three questions, two tables, distinguished by join type:**
- INNER JOIN -> rows that HAVE a match ("films that have inventory")
- LEFT JOIN + WHERE right IS NULL -> rows with NO match ("films with no inventory")
- LEFT JOIN, no NULL filter -> ALL left rows, with match data where it exists

**RIGHT JOIN is the mirror of LEFT; rarely used in practice.**
RIGHT JOIN preserves every row from the table in the JOIN clause (the right table). Any RIGHT
JOIN can be rewritten as a LEFT JOIN by swapping table order. Analysts default to LEFT JOIN
because it keeps the anchor table (the table the question is about) in the natural first
position, reading top to bottom. Interview-ready phrasing: "I default to LEFT JOIN because any
RIGHT JOIN can be rewritten as a LEFT by swapping table order, and leading with the anchor reads
more naturally." A SELECT can pull columns from ANY table in the query regardless of whether it
is in FROM or JOIN; table position does not restrict column access.

**Join sides generalize as joins stack.**
For two tables: FROM is the left table, JOIN is the right table. For three or more, each new
JOIN attaches to the accumulated result of everything above it, so "left" = everything joined so
far, "right" = the table in the current JOIN clause.

**Self-join: a table joined to itself.**
Used when rows in one table relate to OTHER rows in the same table (hierarchies, or comparing
rows to each other). The table is named twice with TWO DIFFERENT ALIASES (e.g. f1, f2) so SQL
can treat the copies as distinct. The ON clause connects them on the relating columns.

**The self-join deduplication trick: < on the primary key.**
Naively self-joining on a shared value produces two problems: self-pairings (a row matched with
itself) and duplicate pairs (A/B and B/A). Adding `f1.pk < f2.pk` fixes BOTH at once, because <
is directional: equal ids fail the test (drops self-pairings), and only one ordering of each
genuine pair satisfies < (drops the flipped duplicate). Always compare on the PRIMARY KEY, not a
descriptive column, because the pk is guaranteed unique; comparing on a column that could have
ties (like title) would wrongly drop genuine pairs that happen to share that value.

---

## Tier 4: Subqueries

**A subquery is a query nested inside another query.**
The inner query runs and hands its result to the outer query to use. Useful for questions that
are naturally two-step: "customers who spent above average" = first compute the average, then
find customers above it. Expressing both steps as one statement keeps it correct when data changes,
instead of reading a number off the screen and pasting it into a second query by hand.

**Scalar subquery: returns ONE value, runs ONCE.**
`WHERE rental_rate > (SELECT AVG(rental_rate) FROM film)`. The inner query computes a single value
(one row, one column) a single time, and that value sits in the WHERE clause as a constant while the
outer query scans every row against it. It runs once, not once per row, because its answer is a
property of the whole table and does not change from row to row. This "runs once" behavior is the
key contrast with correlated subqueries (which re-run per outer row).

**IN subquery: returns a LIST, tested for membership.**
Same IN keyword as Tier 1, but instead of a hand-typed list, a subquery generates it.
`WHERE a.city_id IN (SELECT ci.city_id FROM city ci JOIN country co ... WHERE co.country = 'India')`.
The subquery should return the column at the level where the filter logic actually lives (city_id,
because "being in India" is a property of a city), and answer one self-contained question.

**Where to "cut" a multi-table chain: a real design judgment.**
For a four-table chain (customer -> address -> city -> country), you can split the work between the
outer query and the subquery at different points. One version keeps customer alone in the outer query
and puts the other three tables in the subquery (returning address_id). Another joins customer+address
in the outer query and puts city+country in the subquery (returning city_id). Same result, different
cut point. The cleaner cut is the one where each piece expresses one clear idea: the subquery answers
exactly "which cities are in India" (city + country only). No single right answer; it is a readability
judgment. Recognizing this tradeoff is a fluency marker.

**LIKE without a wildcard is a disguised equality.**
`LIKE 'india'` with no % behaves like `= 'india'`, so the LIKE signals unclear intent. Use `=` for an
exact match. Also match the stored casing: `= 'India'`, not `'india'`. A lowercase value only works
because MySQL's default collation is case-insensitive; under a case-sensitive collation it would
silently return zero rows.

**A table can be joined purely as scaffolding, never displayed.**
Tables appear in a query for one of two reasons: to provide columns you want to SELECT, or to provide
a PATH to a column you want to filter or join on. In the India query, the address table is joined only
to reach city_id for the filter; not one of its columns is selected. This breaks the beginner
assumption that every joined table must contribute a visible column. Connector/bridge tables earn
their place by connecting things, not by showing data.
    - Junction tables are the clearest example: joining actor to film through film_actor never selects
      anything FROM film_actor. It exists purely to bridge the two tables you actually care about.
      Same principle as the address bridge, just for a many-to-many relationship.

**EXISTS / NOT EXISTS test row PRESENCE, not values.**
EXISTS asks one thing: did the subquery return any rows, yes or no. It stops at the first match and
does not care what the rows contain, so SELECT * or SELECT 1 inside behaves identically. EXISTS keeps
the outer row when a match is found; NOT EXISTS keeps it when no match is found. The subquery in an
EXISTS is a FILTER, not a data SOURCE: its contents (including any NULLs) are never returned to the
outer query. Only the true/false verdict crosses the boundary. The outer row's displayed columns come
from the outer table directly, never from the subquery.

**NOT EXISTS as an anti-join.**
NOT EXISTS finds "rows with no match," the same idea as the LEFT JOIN + IS NULL anti-join from Tier 3.
For "customers who made no payment," the subquery looks for a matching payment and NOT EXISTS keeps
the customer only when none is found. In Sakila every customer has payments, so this correctly returns
zero rows (a valid answer, not a broken query).

**NOT IN vs NOT EXISTS, and three-valued logic. (The key gotcha of the tier.)**
SQL uses THREE truth values: true, false, and UNKNOWN. Any comparison against NULL returns UNKNOWN,
because NULL means "unknown value" (a sealed box). You cannot confirm a known value equals it, and you
also cannot confirm it is NOT equal to it, so both `= NULL` and `<> NULL` return UNKNOWN.
    - NOT IN expands to a chain of <> joined by AND: `5 NOT IN (1, 2, NULL)` becomes
      `5<>1 AND 5<>2 AND 5<>NULL`. The last term is UNKNOWN, and `true AND UNKNOWN` = UNKNOWN. A row is
      only returned when WHERE is TRUE, and UNKNOWN is not true, so the row is dropped. A single NULL in
      the list therefore makes NOT IN return NO rows at all, silently.
    - NOT EXISTS is safe because it tests row presence, not value equality. No comparison against NULL
      ever happens on the outer side, so nothing gets poisoned. A NULL inside the subquery just fails
      the join condition like any other non-match.
    - Rule: for an anti-join where the tested column could contain NULLs, use NOT EXISTS. NOT IN is only
      safe when the subquery column is guaranteed non-NULL.
    - The one-liner: NOT IN is a COMPARISON operator; EXISTS/NOT EXISTS is a PRESENCE operator.

**Finding NULLs: use IS NULL / IS NOT NULL, never = NULL.**
Because `column = NULL` returns UNKNOWN for every row (and finds nothing), NULLs need a dedicated
presence test. IS NULL asks "is there a sealed box here," a yes/no that returns true or false and never
gets stuck. This is why SQL had to invent a separate operator. In messy real-world data, "missing" can
also be an empty string '' or whitespace, which are real known values that slip past IS NULL, so you
sometimes check `WHERE col IS NULL OR col = ''`. The `= ''` works because an empty string is a known
value, not the sealed box; only NULL forces the special IS NULL treatment.

**Derived table: a subquery in the FROM clause.**
Every other subquery so far lived in WHERE. A derived table sits in FROM, and its result set is treated
like a temporary table the outer query can select from, filter, and join to. It MUST have an alias or
MySQL errors. Use it when you need to aggregate first and then work with the aggregated results.
    - Key insight: once the derived table runs, an aggregate like SUM(amount) AS tot_pay becomes a PLAIN
      COLUMN of the temporary table, with no memory it was ever an aggregate. So the outer query can
      filter it with an ordinary `WHERE tot_pay > 150`, even though `WHERE SUM(amount) > 150` is illegal
      inside (WHERE runs before grouping, so the aggregate does not exist yet).
    - This gives a THIRD way to filter on an aggregate: HAVING inside, OR push the aggregate into a
      derived table and filter with WHERE outside. Same result, two routes; pick whichever reads cleaner.
    - Derived tables are the bridge into Tier 5 CTEs (a CTE is a named, more readable derived table).

---

## Tier 5: CTEs

**A CTE is a named temporary result set defined up front with WITH.**
`WITH name AS ( subquery ) SELECT ... FROM name`. The CTE runs first and hands its result to the main
query, which is why the main query can reference the name as if it were a real table. Once defined, a
CTE behaves like a table anywhere a table name could go: FROM, JOIN, subqueries.

**A CTE is a derived table, pulled out of FROM and named.**
Same result, same work, different structure. A derived table nests the subquery inside FROM so you
read inside-out. A CTE lifts it out and names it, so the query reads top-to-bottom. For one small
step the two are interchangeable and it is a style call.

**Where CTEs actually beat derived tables:**
- Multi-step logic becomes separate named blocks instead of subqueries nested three deep.
- A CTE can be referenced MORE THAN ONCE in the main query. A derived table exists only at its one
  spot in FROM.

**Chained CTEs: the second reads FROM the first.**
`WITH a AS (...), b AS (...)` with one WITH at the top, CTEs separated by commas, and the last one
before the main query omitting the comma. Each CTE can only reference CTEs defined before it.
Conceptually the same as the `%>%` pipe in R: sequential steps, each building on the last.

**Build chained CTEs by working backwards.**
Figure out what the final result needs to look like, then what feeds it, then what feeds that. Each
layer becomes a CTE. This decomposition is the actual skill; the syntax is trivial once the steps are
clear.

**A wrapping layer (CTE or derived table) must earn its place.**
It is REDUNDANT when the outer query just re-selects the inner results unchanged. If running the inner
query alone gives the same answer, drop the wrapper and write the simpler query.
It is NECESSARY when the outer query transforms, aggregates, joins, or ranks the inner result.
Classic necessary case: AVG of SUM. `AVG(SUM(amount))` is illegal in one grouped query, so SUM inside
and AVG outside.

**Selecting the single top row: ORDER BY ... DESC LIMIT 1.**
This is the standard idiom for "the highest" of anything. It avoids the trap of pairing a MAX aggregate
with a non-aggregated column, because it sorts and takes the top rather than aggregating.
Blind spot: if two rows tie for the top, LIMIT 1 arbitrarily returns one and silently hides the tie. To
keep ties, use a window function (RANK). See Tier 6.

**The grouping-vs-summarizing mistake. (Cost me real time.)**
"Average number of films per category" wants ONE number. Leaving `GROUP BY category_name` in the main
query returns one row per category instead, and the AVG does nothing because averaging a single value
returns that same value. The diagnostic: if AVG of a group returns the group's own number back
unchanged, the GROUP BY is defeating the aggregate. Drop it and let the aggregate collapse the whole
set.

**COUNT depends on "rows of what?"**
Counting from a lookup table alone (e.g. `SELECT COUNT(name) FROM category GROUP BY name`) returns 1
per entity, because that table has one row per entity. The join to the junction/detail table is what
expands one category row into one row per film, which gives COUNT something real to count.
Diagnostic: if every count is 1 and a `HAVING > 50` wipes the result to empty (so AVG returns NULL),
you counted the lookup table instead of the detail rows.
`COUNT(fc.film_id)` is more honest than `COUNT(c.name)` after the join, since it says "I am counting
films."

**Naming for readability.**
The test: read ONLY the main query. If you can tell what it does from the names alone, without
scrolling up to decode a CTE, the naming is good.
- Name CTEs for their contents, not their position. `category_avg_rates`, not `t1`/`t2`/`temp`/`beans`.
  A CTE is a noun; name it like the result set it holds.
- Keep column aliases consistent. One name for one concept across the whole query, not `cat_name` in
  one CTE and `categories` in the next for the same thing.
- Match singular/plural to what the column holds. `avg_rental_rate` is one value per row, so singular.
- Short table aliases are fine for base tables (`c`, `fc`, `f`). Save descriptive naming for CTEs.
- snake_case, no spaces or capitals, or the alias needs backticks everywhere downstream.
- Descriptive does not mean long. Two or three words. `category_avg_rates` is good;
  `the_average_rental_rate_for_each_category` is worse than `t2`.

---

## Tier 6: Window Functions

**The core distinction: GROUP BY reduces rows, window functions preserve them.**
An aggregate with GROUP BY collapses many rows into one per group. A window function performs the
same calculation without collapsing anything: every original row survives and the computed value is
attached as a new column on each row. `AVG(rental_rate) OVER (PARTITION BY rating)` returns all 1000
films, each stamped with its own rating's average.

**Terminology precision.**
`AVG()` is the function (an ordinary aggregate). `OVER()` is a CLAUSE that turns it into a window
function. `PARTITION BY` is a component INSIDE the OVER clause that defines which rows each
calculation looks at. Neither OVER nor PARTITION BY is itself a function. The window function is the
whole expression: `AVG(x) OVER (...)`.

**PARTITION BY is the window-function cousin of GROUP BY.**
It scopes the calculation to a group the same way GROUP BY does, but preserves the rows. Every row in
the same partition receives the same value for an aggregate window function. That repetition across
rows is the visible signature of a window function.

**The three ranking functions differ only in how they handle ties.**
- `ROW_NUMBER()` assigns a unique sequential number (1, 2, 3, 4), ignoring ties. Which tied row gets
  the lower number is NON-DETERMINISTIC unless a tiebreaker is added to the ORDER BY inside OVER.
- `RANK()` gives tied rows the same value, then skips ahead. Three rows tied at the top all get 1 and
  the next row gets 4. The gaps reflect how many rows were tied above.
- `DENSE_RANK()` gives tied rows the same value with no gaps. Three tied at the top all get 1 and the
  next row gets 2. Its numbers count distinct values rather than rows.

**Never rely on incidental ordering.**
If tied rows happen to come back alphabetical, that is an artifact of physical row order or which
index the engine scanned, not a rule. Add an explicit tiebreaker (`ORDER BY rate DESC, title`) so the
ordering is deterministic and documented.

**"Top 3" is ambiguous until tie handling is decided.**
`DENSE_RANK() <= 3` returns the top three distinct VALUES (row count varies with repetition in the
data). `RANK() <= 3` returns every row occupying the top three positions. `ROW_NUMBER() <= 3` returns
exactly three rows, arbitrarily breaking ties. In Sakila, rental_rate has only three distinct values,
so "top 3 most expensive films per rating" is not a meaningful question: DENSE_RANK returns all 1000
films, RANK returns 336, and ROW_NUMBER returns an arbitrary 15. The right move is to go back to the
stakeholder rather than hand them an arbitrary list labeled "top performers."

**LAG and LEAD reach out to neighboring rows.**
Unlike other window functions, these do not compute over a set; they grab a value from a specific
other row in the partition. `LAG(col)` pulls from the previous row, `LEAD(col)` from the next. The
ORDER BY inside OVER is what defines "previous" and "next," so it is required, not optional. The
first row of a partition has no previous row, so LAG returns NULL there.

**The NULL-vs-zero-default judgment. (A real data integrity point.)**
`LAG(col, 1, 0)` substitutes 0 when no previous row exists. Only use a 0 default when zero is a real
MEASUREMENT, not a placeholder for unknown. A running count of prior events genuinely starts at zero.
A previous payment amount does not: defaulting to 0 asserts the previous payment WAS zero dollars
rather than that none exists. Leaving it NULL is truthful, and NULL propagates through arithmetic, so
`amount - LAG(amount)` correctly returns NULL on the first row instead of fabricating a change from
nothing. Encoding missingness as a number (0, 99, -1) silently corrupts any average or sum over that
column. This is a classic data-cleaning trap.

**ORDER BY inside OVER is what makes SUM accumulate.**
`SUM(x) OVER (PARTITION BY g)` returns the partition's grand total, stamped identically on every row.
`SUM(x) OVER (PARTITION BY g ORDER BY d)` returns a RUNNING total. Adding the ORDER BY implicitly
frames the window as "from the start of the partition through the current row." Same function, same
partition, entirely different result.

**Named windows remove duplication.**
`SELECT LAG(x) OVER w, SUM(x) OVER w FROM t WINDOW w AS (PARTITION BY g ORDER BY d)`. The WINDOW
clause defines the window once and names it. It goes after WHERE and before ORDER BY. MySQL 8.0
supports this.

**You CANNOT filter a window function in WHERE. (The tier's central mechanical lesson.)**
Window functions are evaluated in the SELECT step, which runs AFTER WHERE. So the column does not
exist yet when WHERE runs. `WHERE film_rank <= 3` throws "unknown column." HAVING fails for the same
reason (it also runs before SELECT). This follows directly from the logical processing order:
FROM, WHERE, GROUP BY, HAVING, SELECT, ORDER BY.

**The fix, and the top-N-per-group pattern.**
Compute the window function inside a CTE or derived table, which materializes it as a plain column of
that result set. Then the outer query filters it with an ordinary WHERE. This is the same insight as
aggregates in derived tables: once inside, it stops being a live window function and becomes a normal
column. Rank inside the CTE, `WHERE rank <= N` outside. This single fact explains most window function
errors people hit in practice.

---

## Tier 7: Conditional Logic

**Two CASE forms.**
Simple CASE names the column once and compares it against literals: `CASE rating WHEN 'G' THEN 1 ...`.
Searched CASE takes a full condition in each WHEN: `CASE WHEN length < 60 THEN 'short' ...`. Searched is
more flexible (ranges, multiple columns) and more common. Use simple when every branch tests the same
column against a fixed value.

**First match wins, so order the WHEN clauses from most restrictive outward.**
Evaluation runs top to bottom and stops at the first match. This means each condition only has to state
its upper bound, because the lower bound is guaranteed by what came before. `WHEN length < 60` then
`WHEN length <= 120` is correct; writing `WHEN length >= 60 AND length <= 120` is redundant. Fewer places
for a boundary error to hide.

**No ELSE means NULL.**
If no WHEN matches and there is no ELSE, the CASE returns NULL for that row. This is sometimes a bug and
sometimes the entire point (see conditional aggregation below).

**Watch the boundary.**
`WHEN length <= 120` vs `< 120` decides which side a 120-minute film lands on. Same family of problem as
the BETWEEN datetime trap from Tier 1: runs fine, silently misclassifies.

**Conditional aggregation: CASE inside an aggregate. (The pattern that matters most.)**
Aggregates ignore NULLs. A CASE with no ELSE returns NULL for non-matching rows. Put the CASE inside the
aggregate and it only sees the rows that matched. This computes a filtered aggregate inside a query that
is not otherwise filtered, which WHERE cannot do because WHERE would remove those rows from the whole
query. Lets several differently-filtered aggregates sit side by side in one grouped query.
  `COUNT(CASE WHEN length > 120 THEN 1 END)` counts only the long films.
The value after THEN is arbitrary. COUNT does not inspect it, only checks that it is not NULL.
`THEN 1`, `THEN 'yes'`, `THEN film_id` all count the same rows. The `1` is convention, not requirement.

**The ELSE decides whether non-matching rows are in the denominator.**
COUNT wants them gone, so no ELSE. AVG needs them present as zeros, so ELSE 0.
`AVG(CASE WHEN length > 120 THEN 1 ELSE 0 END)` gives the proportion, because a column of 1s and 0s
averages to the proportion of 1s. Without the ELSE, AVG drops the NULLs, divides the sum of the 1s by the
count of the 1s, and returns exactly 1.0 for every group. No error, just a wrong answer that looks valid.

**CASE in ORDER BY for custom sort orders.**
Ratings sort alphabetically as G, NC-17, PG, PG-13, R, which is meaningless. A CASE in the ORDER BY
assigns each value a sort position and SQL sorts by that number instead. No ELSE means an unrecognized
value returns NULL, and MySQL sorts NULLs first ascending, so it would silently jump to the top.

**COALESCE(value, 0) is the shorthand for the NULL-to-zero CASE.**
`COALESCE(a, b, 0)` returns the first non-NULL in the list. `COALESCE(SUM(x), 0)` replaces
`CASE WHEN SUM(x) IS NULL THEN 0 ELSE SUM(x) END`. Idiomatic and appears constantly in real SQL.

---

## Tier 8: Set Operations

**UNION stacks rows vertically; JOIN adds columns horizontally.**
Two full SELECT statements with UNION between them. One semicolon, at the very end. Both queries must
return the same number of columns with compatible types. Column names come from the FIRST query only;
an alias in the second query is ignored.

**A SELECT list accepts literals, not just column names.**
`SELECT first_name, 'staff' AS table_origin FROM staff` creates a column where every row holds 'staff'.
Useful for tagging which source a row came from in a UNION. (Same idea as `THEN 1` inside a CASE.)

**UNION deduplicates ENTIRE ROWS, not individual columns.**
Two rows are duplicates only when every column matches. Adding a source-label literal guarantees rows
from different halves can never match, which makes the dedup pass do nothing. Sakila staff+customer with
a table_origin label returns 601 rows either way.

**UNION vs UNION ALL: use UNION ALL by default.**
UNION removes duplicates, which costs a sort or hash pass. UNION ALL keeps everything and skips that work.
Most people reach for UNION reflexively and pay for a dedup they do not need. Only use UNION when you
specifically want duplicates removed.

**The distinction can change the answer dramatically.**
customer_id from rental UNION ALL customer_id from payment returns 32,088 rows (16,044 rentals plus
16,044 payments; ids repeat because customers transact many times). The same query with UNION returns 599,
one per distinct customer. That 599 matches the customer table's row count, which means every customer has
at least one rental and one payment. If it had returned 597, two customers never transacted. A real
analytical finding hiding in a set operation.

**UNION on a single column is SELECT DISTINCT in disguise.**
It deduplicates across AND within both queries, making the whole combined result distinct. That free dedup
is exactly why it is slower than UNION ALL.

---

## Tier 9: Synthesis

**Find the hub table first.**
For "top-grossing category per country," payment is the anchor: it holds the measure being summed (amount)
AND carries foreign keys to both directions needed (customer_id fans out to the country chain, rental_id
fans out to the category chain). The hub is the table that owns the measure and the keys, not the one
that is nearest to anything.

**Trace both chains on paper before writing SQL.**
customer -> address -> city -> country on one side. rental -> inventory -> film -> film_category ->
category on the other. Nine joins total. Writing them out first is what makes the query writeable.

**Join key errors run without erroring.**
`city.city_id = address.address_id` compares a city id to an address id. Both are numbers, both exist, the
query runs, the answer is garbage. The rule: join on the foreign key one table holds pointing at the
other's primary key. Address holds city_id, so the join is `city.city_id = address.city_id`.

**A column name matching what you want is not the same as meaning what you want. (The most valuable
lesson in this tier.)**
`customer.store_id` exists and is real, but it means the store the customer is REGISTERED at, one value,
permanent. The question "how much did they spend AT that store" is about where the transaction physically
happened, which lives in `inventory.store_id` (an inventory row is a physical copy sitting at a specific
store). The correct chain is store -> inventory -> rental -> payment -> customer.
  The tell: if a customer can only have one store_id, the question "how much at store 1 vs store 2" cannot
  even be asked. When the question implies something the schema forbids, the column is wrong.
  Checked empirically: the two store_ids frequently disagree, so customers do rent from both stores and
  the customer.store_id path would attribute revenue to the wrong branch.
  Habit: when two paths to the same concept exist, TEST whether they agree before picking one.

**GROUP BY on names merges distinct people.**
Grouping by first_name, last_name would combine two different customers who share a name. Group by
customer_id and include the names alongside (they are functionally dependent on the id, so they add no
extra groups).

**Not every problem needs a CTE, and pattern trapping is real.**
Q1 needed two chained CTEs because the steps are genuinely sequential: compute revenue per country-category,
THEN rank it (and a window function cannot be filtered in the query that computes it). Q3 needed only one,
for readability. The reflex to reach for CTEs because the last query used them leads to trying to stitch
independent result sets together with a comma cross join, which produces garbage.
  Test: can the inner query alone answer the question? If yes, the wrapper is redundant.

**A single value does not need a CTE or a join. Use a scalar subquery.**
A grand total is one number. `revenue / (SELECT SUM(amount) FROM payment) * 100` drops it directly into
the expression, evaluating once. Same move as the Tier 4 scalar subquery in a WHERE clause; it works
anywhere a value can go, including inside arithmetic in the SELECT.

**You cannot reference a SELECT alias elsewhere in the same SELECT.**
`SUM(amount) AS revenue` then `revenue / total` in the next line fails. Either repeat the expression, or
put the aggregation in a CTE so revenue becomes a plain column the outer query can name.

**To preserve a table at the far end of a chain, it has to be on the preserved side.**
An inner join from payment out to category drops any category with zero payments, because there is no
payment row for it to ride in on. A LEFT JOIN on category does nothing here for the same reason. RIGHT
JOIN on category preserves it (or restructure to anchor FROM category and LEFT JOIN outward, which is
the more conventional shape).

**SUM over zero rows returns NULL, not 0.**
And NULL propagates through arithmetic, so the percentage calculation also returns NULL. Wrap it:
`COALESCE(SUM(amount), 0)`.

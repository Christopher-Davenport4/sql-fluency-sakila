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
*(to be filled as queries are written)*

---

## Tier 5: CTEs
*(to be filled as queries are written)*

---

## Tier 6: Window Functions
*(to be filled as queries are written)*

---

## Tier 7: Conditional Logic
*(to be filled as queries are written)*

---

## Tier 8: Set Operations
*(to be filled as queries are written)*

---

## Tier 9: Synthesis
*(to be filled as queries are written)*

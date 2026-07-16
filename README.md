# SQL Analytics on a Relational Retail Database — Sakila

## Purpose

This project exists to build genuine SQL fluency through deliberate, repeated practice
against a real relational schema. No Python, no dashboards, no pipeline. Just a database
and a growing file of SQL queries.

The schema was chosen because it is hard. Sakila has 16 base tables, two many-to-many
junction relationships, and a four-table geographic chain, which means most questions
cannot be answered without multi-hop joins and a decision about which path through the
schema is the correct one. Every query here was written by hand, without generated code.

The work is organized into nine tiers, moving from single-table filtering through window
functions and set operations. Tier 9 combines all of it, with three multi-construct
queries answering business questions that require the full progression to reach.
---

## Dataset
**Sakila** — MySQL's native sample database. A fictional DVD rental store with 16 base
tables, two many-to-many junction relationships, and a four-table geographic chain. Designed
to force multi-table JOINs, subqueries, aggregation, and conditional logic.

Canonical row counts (verified at load):
| Table    | Expected | Loaded |
|----------|----------|--------|
| film     | 1000     | 1000   |
| rental   | 16044    | 16044  |
| payment  | 16049    | 16044  |
| customer | 599      | 599    |

Note: payment is 5 rows short of canonical. Confirmed as a source file issue,
not a load error. Does not affect any query in this project.

---

## Environment
- MySQL Server 8.0.46 (local)
- MySQL Workbench 8.0 (query editor)
- OS: Windows 10

---

## Setup — Reproducing This Environment
1. Install MySQL Server and MySQL Workbench via the MySQL Installer for Windows (mysql-installer-community). Workbench alone is only a client and will not run without a server.
2. During server configuration: choose Development Computer, strong password encryption, set root password, enable Windows service set to start at boot.
3. Download the Sakila zip from https://dev.mysql.com/doc/index-other.html under Example Databases.
4. Extract and load in order from the MySQL client, using forward slashes in the path (the MySQL client treats backslashes as escape characters):
   ```sql
   SOURCE C:/path/to/sakila-schema.sql;
   SOURCE C:/path/to/sakila-data.sql;
   ```
   Schema first, then data. The data file assumes the tables already exist.
5. Verify row counts against the table above before querying.

The Sakila source files are not committed to this repo. They are publicly available from
MySQL and are not original work, so the setup instructions above are the reproduction path.

---

## Skill Progression (Nine Tiers)
| Tier | Focus |
|------|-------|
| 0    | Schema orientation — relationships, foreign keys, junction tables |
| 1    | Single-table fundamentals — WHERE, ORDER BY, DISTINCT, LIKE, IN, BETWEEN |
| 2    | Aggregation — GROUP BY, COUNT, SUM, AVG, WHERE vs HAVING |
| 3    | Joins — INNER, LEFT, RIGHT, multi-hop chains, junction tables, self-joins |
| 4    | Subqueries — scalar, IN, correlated, EXISTS, derived tables |
| 5    | CTEs — single, chained, CTE vs subquery tradeoffs |
| 6    | Window functions — ROW_NUMBER, RANK, DENSE_RANK, LAG, LEAD, running totals |
| 7    | Conditional logic — CASE in SELECT, inside aggregation, in ORDER BY |
| 8    | Set operations — UNION vs UNION ALL |
| 9    | Synthesis — multi-construct queries combining all of the above |

All nine tiers are complete.

---

## Tier 9: Synthesis Queries
The final tier contains three multi-construct queries that combine the full progression:

1. **Top-grossing category per country.** Nine joins fanning out from payment in two
   directions (customer to country, rental to category), aggregated by country and category,
   then ranked with ROW_NUMBER partitioned by country and filtered to rank 1.

2. **Top-spending customer per store.** Required distinguishing `customer.store_id` (the
   customer's registered home branch, one value each) from `inventory.store_id` (where the
   transaction physically occurred). Checking the data confirmed the two frequently disagree,
   so the naive path would attribute revenue to the wrong store. Uses RANK rather than
   ROW_NUMBER so tied top spenders are both returned rather than one being dropped.

3. **Revenue by category with percentage of total.** Uses a RIGHT JOIN to preserve categories
   with zero revenue, COALESCE-equivalent CASE logic to convert the resulting NULL sum to 0,
   and a scalar subquery for the grand total rather than a redundant CTE.

---

## Repository Structure
```
project3/
├── README.md          — this file
├── queries.sql        — all queries organized by tier with comments
└── NOTES.md           — learning log, patterns, and gotchas
```

`queries.sql` contains every query written for this project, grouped by tier, each preceded
by a comment stating the question it answers and the reasoning behind the approach.

`NOTES.md` is the learning log. It records the conceptual distinctions and gotchas that
surfaced during the work — the datetime BETWEEN trap, why NOT IN breaks on NULLs and
NOT EXISTS does not, why window functions cannot be filtered in WHERE, when a derived table
is redundant versus necessary, and the store_id ambiguity in Tier 9.

# Project 3: SQL Fluency Drilling — Sakila Dataset

## Purpose
This project exists for one reason: to build genuine SQL fluency through deliberate,
repeated practice against a real relational schema. No Python, no dashboards, no pipeline.
Just a database and a growing file of SQL queries.

This is a direct response to an honest self-assessment: prior projects involved JOINs,
CTEs, and window functions once, with guidance, against a simple star schema. That is
familiarity, not fluency. This project is structured to close that gap.

---

## Dataset
**Sakila** — MySQL's native sample database. A fictional DVD rental store with 16 base
tables, multiple many-to-many relationships, and a four-table geographic chain. Designed
to force multi-table JOINs, subqueries, aggregation, and logic constructs.

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
1. Install MySQL Server and MySQL Workbench via the MySQL Installer for Windows (mysql-installer-community).
2. During server configuration: choose Development Computer, strong password encryption, set root password, enable Windows service set to start at boot.
3. Download the Sakila zip from https://dev.mysql.com/doc/index-other.html under Example Databases.
4. Extract and load in order from the MySQL client using forward slashes in the path:
   ```sql
   SOURCE C:/path/to/sakila-schema.sql;
   SOURCE C:/path/to/sakila-data.sql;
   ```
5. Verify row counts against the table above before querying.

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

---

## Repository Structure
```
project3/
├── README.md          — this file
├── queries.sql        — all queries organized by tier with comments
└── NOTES.md           — learning log, patterns, and gotchas
```

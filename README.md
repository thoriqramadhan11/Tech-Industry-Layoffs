# 🏭 Tech Industry Layoffs — SQL Data Analysis Project

![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?style=for-the-badge&logo=mysql&logoColor=white)
![Status](https://img.shields.io/badge/Status-Completed-27AE60?style=for-the-badge)
![Domain](https://img.shields.io/badge/Domain-Tech%20Industry-E67E22?style=for-the-badge)
![Type](https://img.shields.io/badge/Type-Data%20Cleaning%20%2B%20EDA-8E44AD?style=for-the-badge)

> **End-to-end SQL project** analyzing tech industry layoffs — from raw, messy data to structured insights using real-world data cleaning techniques and exploratory analysis.

---

## 📌 Project Overview

This project covers a **complete data analysis pipeline** built entirely in MySQL, working with a real-world dataset of global tech industry layoffs. The project is split into two scripts:

| Script | Description |
|---|---|
| `data_cleaning_layoffs.sql` | Removes duplicates, standardizes values, handles NULLs, and preps the data for analysis |
| `exploratory_data_analysis_layoffs.sql` | Uncovers trends across companies, countries, industries, and time periods |

---

## 🗂️ Dataset

The raw `layoffs` table contains records of tech company layoff events with the following fields:

| Column | Description |
|---|---|
| `company` | Name of the company |
| `location` | City where the layoff occurred |
| `industry` | Industry sector |
| `total_laid_off` | Absolute number of employees laid off |
| `percentage_laid_off` | Proportion of workforce laid off (0–1) |
| `date` | Date of the layoff event |
| `stage` | Funding stage of the company (Seed, Series A–E, Post-IPO, etc.) |
| `country` | Country of the company |
| `funds_raised_millions` | Total funds raised by the company (in USD millions) |

---

## 🧹 Part 1 — Data Cleaning

**File:** `data_cleaning_layoffs.sql`

A structured 4-step cleaning pipeline to transform raw data into an analysis-ready table.

### Step 1 — Remove Duplicates
- Created a **staging table** (`layoffs_staging`) to preserve the original raw data
- Used `ROW_NUMBER()` with a full-column `PARTITION BY` to flag exact duplicate rows
- Worked around MySQL's limitation (cannot `DELETE` directly from a CTE) by creating a second staging table (`layoffs_staging2`) with the `row_num` helper column

```sql
WITH duplicate_cte AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY company, location, industry,
                total_laid_off, percentage_laid_off, `date`,
                stage, country, funds_raised_millions
        ) AS row_num
    FROM layoffs_staging
)
SELECT * FROM duplicate_cte
WHERE row_num > 1;
```

### Step 2 — Standardize Data
Fixed four distinct data quality issues:
- **Whitespace** — Trimmed leading/trailing spaces from `company` names using `TRIM()`
- **Industry inconsistency** — Unified all `Crypto` variants (`'crypto'`, `'CryptoCurrency'`) into one standard label
- **Country inconsistency** — Removed trailing punctuation from `'United States.'` using `TRIM(TRAILING '.' FROM country)`
- **Date type mismatch** — Converted `date` from `TEXT` (stored as `MM/DD/YYYY`) to proper `DATE` type using `STR_TO_DATE()` and `ALTER TABLE`

### Step 3 — Handle NULL & Blank Values
- Used a **self-join** to backfill missing `industry` values — matching rows from the same company that had a known industry value
- Removed records where **both** `total_laid_off` and `percentage_laid_off` were `NULL`, as these rows carry no analytical value

### Step 4 — Remove Unnecessary Columns
- Dropped the `row_num` helper column after duplicate removal was complete

---

## 🔍 Part 2 — Exploratory Data Analysis (EDA)

**File:** `exploratory_data_analysis_layoffs.sql`

7 analysis sections designed to surface meaningful patterns from the cleaned data.

### Section 1 — Dataset Overview
- Date range check (`MIN` / `MAX` of the `date` column)
- Full chronological view of all records

### Section 2 — High-Level Statistics
- Identified the **single largest layoff event** and **highest workforce reduction percentage**
- Filtered for companies that laid off **100% of their workforce** (complete shutdowns), sorted by funds raised — revealing well-funded companies that still collapsed

### Section 3 — Company-Level Analysis
- Ranked all companies by **total cumulative layoffs** across the dataset period
- Spot-checked individual companies (e.g., Amazon) to verify data completeness

### Section 4 — Country-Level Analysis
Applied two different approaches to rank countries by total layoffs — demonstrating SQL problem-solving versatility:

**Subquery approach:**
```sql
SELECT * FROM (
    SELECT
        ROW_NUMBER() OVER (ORDER BY SUM(total_laid_off) DESC) AS `rank`,
        country,
        SUM(total_laid_off) AS total_laid_off
    FROM layoffs_staging2
    GROUP BY country
) AS ranked_countries
WHERE country = 'Indonesia';
```

**CTE approach** *(preferred — more readable and reusable)*:
```sql
WITH ranked_countries AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY SUM(total_laid_off) DESC) AS `rank`,
        country,
        SUM(total_laid_off) AS total_laid_off
    FROM layoffs_staging2
    GROUP BY country
)
SELECT * FROM ranked_countries
WHERE country = 'Indonesia';
```

### Section 5 — Industry & Funding Stage Analysis
- Aggregated total layoffs by **funding stage** to understand which stage of company growth was most impacted

### Section 6 — Time-Series Analysis
Built two rolling trend queries using **window functions**:
- **Global** monthly layoffs + running cumulative total
- **Per-country** monthly layoffs + running cumulative total (partitioned by country)

```sql
SELECT
    SUBSTRING(`date`, 1, 7)                                          AS `month`,
    SUM(total_laid_off)                                               AS monthly_layoffs,
    SUM(SUM(total_laid_off)) OVER (ORDER BY SUBSTRING(`date`, 1, 7)) AS cumulative_layoffs
FROM layoffs_staging2
WHERE SUBSTRING(`date`, 1, 7) IS NOT NULL
GROUP BY `month`
ORDER BY `month`;
```

### Section 7 — Top 5 Companies per Year (Ranking)
Chained two CTEs to identify the **top 5 companies with the most layoffs for each calendar year** — using `DENSE_RANK()` to handle ties without leaving gaps in ranking:

```sql
WITH company_year AS (
    SELECT company, YEAR(`date`) AS `year`, SUM(total_laid_off) AS total_laid_off
    FROM layoffs_staging2
    GROUP BY company, YEAR(`date`)
),
company_year_rank AS (
    SELECT *, DENSE_RANK() OVER (PARTITION BY `year` ORDER BY total_laid_off DESC) AS ranking
    FROM company_year
    WHERE `year` IS NOT NULL
)
SELECT * FROM company_year_rank
WHERE ranking <= 5
ORDER BY `year`, ranking;
```

---

## 🛠️ SQL Concepts & Techniques Used

| Category | Techniques |
|---|---|
| **Window Functions** | `ROW_NUMBER()`, `DENSE_RANK()`, `SUM() OVER()` |
| **CTEs** | Single CTE, chained CTEs (2-level), CTE for deduplication |
| **Subqueries** | Inline subqueries for ranking and filtering |
| **String Functions** | `TRIM()`, `TRIM(TRAILING ...)`, `SUBSTRING()`, `STR_TO_DATE()` |
| **Joins** | Self-join for NULL backfilling |
| **DDL** | `CREATE TABLE`, `ALTER TABLE`, `DROP COLUMN`, `MODIFY COLUMN` |
| **DML** | `INSERT INTO`, `UPDATE`, `DELETE` with conditions |
| **Aggregation** | `SUM()`, `MAX()`, `MIN()`, `GROUP BY`, `ORDER BY` |
| **Filtering** | `WHERE`, `LIKE`, `IS NULL`, `IS NOT NULL`, `DISTINCT` |

---

## 📁 Repository Structure

```
📦 layoffs-sql-analysis
 ┣ 📄 data_cleaning_layoffs.sql          ← Step-by-step data cleaning pipeline
 ┣ 📄 exploratory_data_analysis_layoffs.sql  ← 7-section EDA
 ┗ 📄 README.md
```

---

## 🚀 How to Run

1. Import the raw `layoffs` dataset into your MySQL database
2. Run `data_cleaning_layoffs.sql` first — this creates and populates `layoffs_staging2`
3. Run `exploratory_data_analysis_layoffs.sql` — all queries reference `layoffs_staging2`

> ⚠️ Both scripts are written for **MySQL 8.0+**. Window functions (`ROW_NUMBER`, `DENSE_RANK`, `SUM OVER`) require MySQL 8.0 or above.

---

## 👤 Author

**Muhammad Thoriq Ramadhan**
📧 thoriq.ramadhan11
🔗 [LinkedIn Profile]
💼 [Portfolio Link]

---

*If you found this project useful or interesting, feel free to ⭐ star the repository!*

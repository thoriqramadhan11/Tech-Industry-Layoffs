-- ============================================================
--  EXPLORATORY DATA ANALYSIS (EDA)
--  Dataset  : Tech Industry Layoffs
--  Tool     : MySQL
--  Author   : Muhammad Thoriq Ramadhan
--  Date     : March 16, 2026
-- ============================================================
--
--  OBJECTIVE
--  ---------
--  Explore the cleaned layoffs dataset to uncover trends,
--  patterns, and key insights across companies, industries,
--  countries, and time periods.
--
--  ANALYSIS SECTIONS
--  -----------------
--  1. Dataset Overview & Sanity Check
--  2. High-Level Statistics
--  3. Company-Level Analysis
--  4. Country-Level Analysis
--  5. Industry & Stage Analysis
--  6. Time-Series Analysis
--  7. Top Companies per Year (Ranking)
--
-- ============================================================


-- ============================================================
--  SECTION 1 — DATASET OVERVIEW & SANITY CHECK
-- ============================================================

-- Full dataset preview
SELECT *
FROM layoffs_staging2;

-- Date range of the dataset
SELECT
    MIN(`date`) AS earliest_date,
    MAX(`date`) AS latest_date
FROM layoffs_staging2;

-- Chronological view of all records
SELECT *
FROM layoffs_staging2
ORDER BY `date`;


-- ============================================================
--  SECTION 2 — HIGH-LEVEL STATISTICS
-- ============================================================

-- Peak single-event layoff and highest percentage laid off recorded
SELECT
    MAX(total_laid_off)        AS max_single_event_layoffs,
    MAX(percentage_laid_off)   AS max_percentage_laid_off
FROM layoffs_staging2;

-- Companies that laid off 100% of their workforce (shut down entirely)
-- Sorted by funds raised to highlight well-funded companies that still failed
SELECT *
FROM layoffs_staging2
WHERE percentage_laid_off = 1
ORDER BY funds_raised_millions DESC;


-- ============================================================
--  SECTION 3 — COMPANY-LEVEL ANALYSIS
-- ============================================================

-- Total layoffs per company, ranked highest to lowest
SELECT
    company,
    SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
GROUP BY company
ORDER BY total_laid_off DESC;

-- Spot check: layoff history for a specific company (Amazon)
SELECT *
FROM layoffs_staging2
WHERE company = 'Amazon';


-- ============================================================
--  SECTION 4 — COUNTRY-LEVEL ANALYSIS
-- ============================================================

-- Total layoffs per country with global rank
-- Useful for identifying which countries were hit hardest
SELECT
    ROW_NUMBER() OVER (ORDER BY SUM(total_laid_off) DESC) AS `rank`,
    country,
    SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
GROUP BY country
ORDER BY total_laid_off DESC;


-- Find the global rank of a specific country (Indonesia) — Subquery approach
SELECT *
FROM (
    SELECT
        ROW_NUMBER() OVER (ORDER BY SUM(total_laid_off) DESC) AS `rank`,
        country,
        SUM(total_laid_off) AS total_laid_off
    FROM layoffs_staging2
    GROUP BY country
    ORDER BY total_laid_off DESC
) AS ranked_countries
WHERE country = 'Indonesia';


-- Find the global rank of a specific country (Indonesia) — CTE approach
-- CTE is preferred for readability and reusability
WITH ranked_countries AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY SUM(total_laid_off) DESC) AS `rank`,
        country,
        SUM(total_laid_off) AS total_laid_off
    FROM layoffs_staging2
    GROUP BY country
    ORDER BY total_laid_off DESC
)
SELECT *
FROM ranked_countries
WHERE country = 'Indonesia';


-- ============================================================
--  SECTION 5 — INDUSTRY & FUNDING STAGE ANALYSIS
-- ============================================================

-- Total layoffs by funding stage
-- Reveals which stage of company growth was most affected
SELECT
    stage,
    SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
GROUP BY stage
ORDER BY total_laid_off DESC;


-- ============================================================
--  SECTION 6 — TIME-SERIES ANALYSIS
-- ============================================================

-- Monthly layoffs + running cumulative total (global)
-- Helps visualize the acceleration or deceleration of layoffs over time
SELECT
    SUBSTRING(`date`, 1, 7)                                                   AS `month`,
    SUM(total_laid_off)                                                        AS monthly_layoffs,
    SUM(SUM(total_laid_off)) OVER (ORDER BY SUBSTRING(`date`, 1, 7))           AS cumulative_layoffs
FROM layoffs_staging2
WHERE SUBSTRING(`date`, 1, 7) IS NOT NULL
GROUP BY `month`
ORDER BY `month`;


-- Monthly layoffs + running cumulative total broken down by country
-- Enables per-country trend analysis over time
SELECT
    country,
    SUBSTRING(`date`, 1, 7)                                                                       AS `month`,
    SUM(total_laid_off)                                                                            AS monthly_layoffs,
    SUM(SUM(total_laid_off)) OVER (PARTITION BY country ORDER BY SUBSTRING(`date`, 1, 7))          AS cumulative_layoffs
FROM layoffs_staging2
WHERE SUBSTRING(`date`, 1, 7) IS NOT NULL
GROUP BY country, `month`
ORDER BY country, `month`;


-- ============================================================
--  SECTION 7 — TOP COMPANIES PER YEAR (RANKING)
-- ============================================================
--
--  Goal: Identify the top 5 companies with the most layoffs
--  for each calendar year.
--
--  Approach:
--  - CTE 1 (company_year)      : Aggregate total layoffs per company per year
--  - CTE 2 (company_year_rank) : Apply DENSE_RANK() within each year
--  - Final SELECT               : Filter to top 5 per year
--
--  DENSE_RANK() is used instead of RANK() to avoid gaps in
--  ranking when companies are tied.
-- ============================================================

-- Step 1: Preview raw aggregation by company and year
SELECT
    company,
    YEAR(`date`)            AS `year`,
    SUM(total_laid_off)     AS total_laid_off
FROM layoffs_staging2
GROUP BY company, YEAR(`date`)
ORDER BY total_laid_off DESC;


-- Step 2: Final ranking query — Top 5 companies per year
WITH company_year AS (
    SELECT
        company,
        YEAR(`date`)            AS `year`,
        SUM(total_laid_off)     AS total_laid_off
    FROM layoffs_staging2
    GROUP BY company, YEAR(`date`)
),
company_year_rank AS (
    SELECT
        *,
        DENSE_RANK() OVER (
            PARTITION BY `year`
            ORDER BY total_laid_off DESC
        ) AS ranking
    FROM company_year
    WHERE `year` IS NOT NULL
)
SELECT *
FROM company_year_rank
WHERE ranking <= 5
ORDER BY `year`, ranking;


-- ============================================================
--  END OF EXPLORATORY DATA ANALYSIS
-- ============================================================

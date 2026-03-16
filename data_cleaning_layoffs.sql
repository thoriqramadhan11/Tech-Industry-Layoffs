-- ============================================================
--  DATA CLEANING PROJECT
--  Dataset  : Tech Industry Layoffs
--  Tool     : MySQL
--  Author   : Muhammad Thoriq Ramadhan
--  Date     : March 16, 2026
-- ============================================================
--
--  OBJECTIVE
--  ---------
--  Clean and standardize the raw `layoffs` dataset to ensure
--  data quality and consistency for downstream analysis.
--
--  CLEANING STEPS
--  --------------
--  1. Remove duplicate records
--  2. Standardize inconsistent values
--  3. Handle NULL and blank values
--  4. Drop unnecessary columns
--
-- ============================================================


-- ------------------------------------------------------------
--  INITIAL EXPLORATION
-- ------------------------------------------------------------

SELECT *
FROM layoffs;


-- ============================================================
--  STEP 1 — REMOVE DUPLICATES
-- ============================================================
--
--  Strategy:
--  Rather than modifying the original table directly, we work
--  on a staging copy to preserve raw data integrity.
--  We use ROW_NUMBER() with a full-column PARTITION to flag
--  rows that are exact duplicates across all relevant fields.
-- ============================================================

-- Create a staging table mirroring the original schema
CREATE TABLE layoffs_staging
LIKE layoffs;

-- Populate staging table with all raw records
INSERT INTO layoffs_staging
SELECT *
FROM layoffs;

-- Verify staging table was created and populated correctly
SELECT *
FROM layoffs_staging;


-- Identify duplicate rows using ROW_NUMBER()
-- Any row with row_num > 1 is a duplicate
SELECT *,
    ROW_NUMBER() OVER (
        PARTITION BY
            company, location, industry,
            total_laid_off, percentage_laid_off, `date`,
            stage, country, funds_raised_millions
    ) AS row_num
FROM layoffs_staging;


-- Preview duplicates before deletion
WITH duplicate_cte AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY
                company, location, industry,
                total_laid_off, percentage_laid_off, `date`,
                stage, country, funds_raised_millions
        ) AS row_num
    FROM layoffs_staging
)
SELECT *
FROM duplicate_cte
WHERE row_num > 1;


-- Spot check: verify a specific company flagged as duplicate
SELECT *
FROM layoffs_staging
WHERE company = 'Casper';


-- NOTE: MySQL does not support deleting directly from a CTE.
-- Solution: Create a second staging table that includes the
-- row_num column explicitly, so we can DELETE by row_num.

CREATE TABLE layoffs_staging2 (
    `company`               TEXT,
    `location`              TEXT,
    `industry`              TEXT,
    `total_laid_off`        INT          DEFAULT NULL,
    `percentage_laid_off`   TEXT,
    `date`                  TEXT,
    `stage`                 TEXT,
    `country`               TEXT,
    `funds_raised_millions` INT          DEFAULT NULL,
    `row_num`               INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- Populate staging2 with row numbers assigned
INSERT INTO layoffs_staging2
SELECT *,
    ROW_NUMBER() OVER (
        PARTITION BY
            company, location, industry,
            total_laid_off, percentage_laid_off, `date`,
            stage, country, funds_raised_millions
    ) AS row_num
FROM layoffs_staging;


-- Confirm duplicates are correctly flagged
SELECT *
FROM layoffs_staging2
WHERE row_num > 1;


-- Delete confirmed duplicate rows
DELETE
FROM layoffs_staging2
WHERE row_num > 1;


-- Verify duplicates have been removed
SELECT *
FROM layoffs_staging2;


-- ============================================================
--  STEP 2 — STANDARDIZE DATA
-- ============================================================
--
--  Issues addressed:
--  a) Leading/trailing whitespace in company names
--  b) Inconsistent industry naming (e.g. 'Crypto', 'crypto', 'CryptoCurrency')
--  c) Inconsistent country naming (e.g. 'United States.')
--  d) Date column stored as TEXT — convert to proper DATE type
-- ============================================================

-- (a) Trim whitespace from company names
SELECT company, TRIM(company) AS company_trimmed
FROM layoffs_staging2;

UPDATE layoffs_staging2
SET company = TRIM(company);


-- (b) Standardize industry: consolidate all Crypto variants into 'Crypto'
SELECT DISTINCT industry
FROM layoffs_staging2
ORDER BY industry;

-- Preview affected rows
SELECT *
FROM layoffs_staging2
WHERE industry LIKE 'Crypto%';

UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';


-- (c) Standardize country: remove trailing period from 'United States.'
SELECT DISTINCT country
FROM layoffs_staging2
ORDER BY country;

-- Preview the fix
SELECT DISTINCT
    country,
    TRIM(TRAILING '.' FROM country) AS country_cleaned
FROM layoffs_staging2
ORDER BY country;

UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';


-- (d) Convert `date` column from TEXT to proper DATE type
-- Raw format is MM/DD/YYYY
SELECT `date`
FROM layoffs_staging2;

UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

-- Alter column type from TEXT to DATE
ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;


-- Confirm all standardization changes
SELECT *
FROM layoffs_staging2;


-- ============================================================
--  STEP 3 — HANDLE NULL AND BLANK VALUES
-- ============================================================
--
--  Strategy:
--  - For `industry`: attempt to backfill NULLs/blanks using
--    other records of the same company that have a known value.
--  - For rows where BOTH `total_laid_off` AND
--    `percentage_laid_off` are NULL, the record provides no
--    analytical value and is removed.
-- ============================================================

-- Preview rows where both layoff columns are NULL (low value records)
SELECT *
FROM layoffs_staging2
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;


-- Identify rows with missing industry values
SELECT *
FROM layoffs_staging2
WHERE industry IS NULL
   OR industry = '';


-- Spot check a specific company
SELECT *
FROM layoffs_staging2
WHERE company LIKE 'Bally%';


-- Preview the self-join that will be used to backfill industry
-- (matches rows missing industry with rows from the same company that have it)
SELECT
    t1.company,
    t1.industry  AS industry_missing,
    t2.industry  AS industry_found
FROM layoffs_staging2 t1
JOIN layoffs_staging2 t2
    ON t1.company = t2.company
WHERE (t1.industry IS NULL OR t1.industry = '')
  AND (t2.industry IS NOT NULL AND t2.industry != '');


-- Backfill missing industry values using the self-join
UPDATE layoffs_staging2 t1
JOIN layoffs_staging2 t2
    ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE (t1.industry IS NULL OR t1.industry = '')
  AND (t2.industry IS NOT NULL AND t2.industry != '');


-- Delete rows where both layoff metrics are NULL
-- These records cannot contribute to layoff analysis
DELETE
FROM layoffs_staging2
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;


-- ============================================================
--  STEP 4 — REMOVE UNNECESSARY COLUMNS
-- ============================================================
--
--  The `row_num` column was a helper column used only for
--  duplicate detection. It carries no business meaning and
--  should be dropped before the table is used for analysis.
-- ============================================================

ALTER TABLE layoffs_staging2
DROP COLUMN row_num;


-- ============================================================
--  FINAL RESULT — CLEANED DATASET
-- ============================================================

SELECT *
FROM layoffs_staging2;

-- ============================================================
--  END OF DATA CLEANING SCRIPT
-- ============================================================

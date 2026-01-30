-- =============================================================================
-- Azure Blob to Snowflake - Raw Landing Table Approach
-- =============================================================================
-- This approach uses a single pipe to load ALL files into one raw table,
-- then transforms and routes data to final tables using a scheduled task.
--
-- Benefits:
--   - Only 1 stage, 1 pipe, 1 Event Grid subscription
--   - Easy to add new folders without Azure configuration changes
--   - All data lands in one place for debugging
--
-- Folder structure:
--   - sales/      → sales table
--   - customers/  → customers table
--   - orders/     → orders table
-- =============================================================================


-- =============================================================================
-- STEP 1: Storage Integration
-- =============================================================================

USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE STORAGE INTEGRATION azure_blob_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'AZURE'
  ENABLED = TRUE
  AZURE_TENANT_ID = '<your-azure-tenant-id>'
  STORAGE_ALLOWED_LOCATIONS = ('azure://<your-storage-account>.blob.core.windows.net/<your-container>/');

DESC STORAGE INTEGRATION azure_blob_integration;

GRANT USAGE ON INTEGRATION azure_blob_integration TO ROLE SYSADMIN;

-- =============================================================================
-- >>> PAUSE HERE <<<
-- 1. Open AZURE_CONSENT_URL in browser to grant consent
-- 2. In Azure Portal, grant "Storage Blob Data Reader" role
-- =============================================================================


-- =============================================================================
-- STEP 2: Database, Schema, File Format
-- =============================================================================

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS AZURE_DATA_DB;
CREATE SCHEMA IF NOT EXISTS AZURE_DATA_DB.RAW_DATA;

USE DATABASE AZURE_DATA_DB;
USE SCHEMA RAW_DATA;

CREATE OR REPLACE FILE FORMAT csv_format
  TYPE = 'CSV'
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  NULL_IF = ('NULL', 'null', '')
  EMPTY_FIELD_AS_NULL = TRUE
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  TRIM_SPACE = TRUE
  ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;


-- =============================================================================
-- STEP 3: Raw Landing Table
-- =============================================================================
-- All files land here first, regardless of folder

CREATE OR REPLACE TABLE raw_landing (
    raw_line        VARCHAR(10000),      -- Raw CSV line as string
    source_file     VARCHAR(500),        -- Full file path (includes folder)
    loaded_at       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    processed       BOOLEAN DEFAULT FALSE
);


-- =============================================================================
-- STEP 4: Final Destination Tables
-- =============================================================================

CREATE OR REPLACE TABLE sales (
    id              INTEGER,
    product         VARCHAR(255),
    amount          DECIMAL(18,2),
    date            DATE,
    _loaded_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_file    VARCHAR(500)
);

CREATE OR REPLACE TABLE customers (
    customer_id     INTEGER,
    name            VARCHAR(255),
    email           VARCHAR(255),
    phone           VARCHAR(50),
    _loaded_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_file    VARCHAR(500)
);

CREATE OR REPLACE TABLE orders (
    order_id        INTEGER,
    customer_id     INTEGER,
    total           DECIMAL(18,2),
    status          VARCHAR(50),
    _loaded_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_file    VARCHAR(500)
);


-- =============================================================================
-- STEP 5: Single Stage (points to root container)
-- =============================================================================

CREATE OR REPLACE STAGE azure_blob_stage
  STORAGE_INTEGRATION = azure_blob_integration
  URL = 'azure://<your-storage-account>.blob.core.windows.net/<your-container>/'
  FILE_FORMAT = csv_format;

LIST @azure_blob_stage;


-- =============================================================================
-- STEP 6: Single Pipe (loads everything to raw landing table)
-- =============================================================================

CREATE OR REPLACE PIPE raw_landing_pipe
  AUTO_INGEST = TRUE
  AS
  COPY INTO raw_landing (raw_line, source_file)
  FROM (
    SELECT
      $1::VARCHAR,
      METADATA$FILENAME
    FROM @azure_blob_stage
  )
  FILE_FORMAT = csv_format
  ON_ERROR = 'CONTINUE';

-- Get notification_channel for Azure Event Grid (only ONE needed)
DESC PIPE raw_landing_pipe;


-- =============================================================================
-- STEP 7: Processing Task
-- =============================================================================
-- This task runs every 5 minutes to process raw data and route to final tables

CREATE OR REPLACE TASK process_raw_landing
  WAREHOUSE = COMPUTE_WH
  SCHEDULE = '5 MINUTE'
  AS
  CALL process_raw_data();

-- Create the stored procedure for processing
CREATE OR REPLACE PROCEDURE process_raw_data()
  RETURNS STRING
  LANGUAGE SQL
  AS
  $$
  BEGIN
    -- Process SALES data
    INSERT INTO sales (id, product, amount, date, _source_file)
    SELECT
      SPLIT_PART(raw_line, ',', 1)::INTEGER,
      SPLIT_PART(raw_line, ',', 2)::VARCHAR,
      SPLIT_PART(raw_line, ',', 3)::DECIMAL(18,2),
      SPLIT_PART(raw_line, ',', 4)::DATE,
      source_file
    FROM raw_landing
    WHERE source_file LIKE '%/sales/%'
      AND processed = FALSE;

    -- Process CUSTOMERS data
    INSERT INTO customers (customer_id, name, email, phone, _source_file)
    SELECT
      SPLIT_PART(raw_line, ',', 1)::INTEGER,
      SPLIT_PART(raw_line, ',', 2)::VARCHAR,
      SPLIT_PART(raw_line, ',', 3)::VARCHAR,
      SPLIT_PART(raw_line, ',', 4)::VARCHAR,
      source_file
    FROM raw_landing
    WHERE source_file LIKE '%/customers/%'
      AND processed = FALSE;

    -- Process ORDERS data
    INSERT INTO orders (order_id, customer_id, total, status, _source_file)
    SELECT
      SPLIT_PART(raw_line, ',', 1)::INTEGER,
      SPLIT_PART(raw_line, ',', 2)::INTEGER,
      SPLIT_PART(raw_line, ',', 3)::DECIMAL(18,2),
      SPLIT_PART(raw_line, ',', 4)::VARCHAR,
      source_file
    FROM raw_landing
    WHERE source_file LIKE '%/orders/%'
      AND processed = FALSE;

    -- Mark all as processed
    UPDATE raw_landing SET processed = TRUE WHERE processed = FALSE;

    RETURN 'Processing complete';
  END;
  $$;

-- Enable the task
ALTER TASK process_raw_landing RESUME;


-- =============================================================================
-- UTILITY COMMANDS
-- =============================================================================

-- Check pipe status
-- SELECT SYSTEM$PIPE_STATUS('raw_landing_pipe');

-- Manually refresh pipe
-- ALTER PIPE raw_landing_pipe REFRESH;

-- Manually run processing task
-- CALL process_raw_data();

-- Check raw landing table
-- SELECT * FROM raw_landing ORDER BY loaded_at DESC LIMIT 100;

-- Check final tables
-- SELECT * FROM sales ORDER BY _loaded_at DESC LIMIT 100;
-- SELECT * FROM customers ORDER BY _loaded_at DESC LIMIT 100;
-- SELECT * FROM orders ORDER BY _loaded_at DESC LIMIT 100;

-- Check task status
-- SHOW TASKS;

-- Pause/Resume task
-- ALTER TASK process_raw_landing SUSPEND;
-- ALTER TASK process_raw_landing RESUME;

-- Cleanup old processed records (run periodically)
-- DELETE FROM raw_landing WHERE processed = TRUE AND loaded_at < DATEADD(DAY, -7, CURRENT_TIMESTAMP());

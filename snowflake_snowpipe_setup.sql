-- =============================================================================
-- Azure Blob to Snowflake - Multi-Folder Snowpipe Setup
-- =============================================================================
-- This script sets up automatic data ingestion from multiple Azure Blob folders
-- to separate Snowflake tables using Snowpipe.
--
-- Folders:
--   - sales     → sales table
--   - customers → customers table
--   - orders    → orders table
--
-- Instructions:
--   1. Replace all placeholder values (<your-...>) with your actual values
--   2. Run each section in order
--   3. After Step 1, configure Azure permissions before proceeding
--   4. After Step 4, configure Azure Event Grid for auto-ingest
-- =============================================================================


-- =============================================================================
-- STEP 1: Storage Integration
-- =============================================================================
-- Run this with ACCOUNTADMIN role
-- =============================================================================

USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE STORAGE INTEGRATION azure_blob_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'AZURE'
  ENABLED = TRUE
  AZURE_TENANT_ID = '<your-azure-tenant-id>'
  STORAGE_ALLOWED_LOCATIONS = ('azure://<your-storage-account>.blob.core.windows.net/<your-container>/');

-- Get consent URL and service principal info
DESC STORAGE INTEGRATION azure_blob_integration;

-- Grant usage to SYSADMIN role
GRANT USAGE ON INTEGRATION azure_blob_integration TO ROLE SYSADMIN;

-- =============================================================================
-- >>> PAUSE HERE <<<
-- 1. Open AZURE_CONSENT_URL in browser to grant consent
-- 2. In Azure Portal, grant "Storage Blob Data Reader" role to the
--    Snowflake service principal (AZURE_MULTI_TENANT_APP_NAME)
-- =============================================================================


-- =============================================================================
-- STEP 2: Database, Schema, File Format
-- =============================================================================

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS AZURE_DATA_DB;
CREATE SCHEMA IF NOT EXISTS AZURE_DATA_DB.RAW_DATA;

USE DATABASE AZURE_DATA_DB;
USE SCHEMA RAW_DATA;

-- File format for CSV files
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
-- STEP 3: Create Tables (one per folder)
-- =============================================================================

-- Table for sales folder
CREATE OR REPLACE TABLE sales (
    id              INTEGER,
    product         VARCHAR(255),
    amount          DECIMAL(18,2),
    date            DATE,
    _loaded_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_file    VARCHAR(500)
);

-- Table for customers folder
CREATE OR REPLACE TABLE customers (
    customer_id     INTEGER,
    name            VARCHAR(255),
    email           VARCHAR(255),
    phone           VARCHAR(50),
    _loaded_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_file    VARCHAR(500)
);

-- Table for orders folder
CREATE OR REPLACE TABLE orders (
    order_id        INTEGER,
    customer_id     INTEGER,
    total           DECIMAL(18,2),
    status          VARCHAR(50),
    _loaded_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_file    VARCHAR(500)
);


-- =============================================================================
-- STEP 4: Create Stages (one per folder)
-- =============================================================================

-- Stage for sales folder
CREATE OR REPLACE STAGE stage_sales
  STORAGE_INTEGRATION = azure_blob_integration
  URL = 'azure://<your-storage-account>.blob.core.windows.net/<your-container>/sales/'
  FILE_FORMAT = csv_format;

-- Stage for customers folder
CREATE OR REPLACE STAGE stage_customers
  STORAGE_INTEGRATION = azure_blob_integration
  URL = 'azure://<your-storage-account>.blob.core.windows.net/<your-container>/customers/'
  FILE_FORMAT = csv_format;

-- Stage for orders folder
CREATE OR REPLACE STAGE stage_orders
  STORAGE_INTEGRATION = azure_blob_integration
  URL = 'azure://<your-storage-account>.blob.core.windows.net/<your-container>/orders/'
  FILE_FORMAT = csv_format;

-- Verify stages
SHOW STAGES;
LIST @stage_sales;
LIST @stage_customers;
LIST @stage_orders;


-- =============================================================================
-- STEP 5: Create Snowpipes (one per folder)
-- =============================================================================

-- Pipe for sales folder
CREATE OR REPLACE PIPE pipe_sales
  AUTO_INGEST = TRUE
  AS
  COPY INTO sales (id, product, amount, date, _source_file)
  FROM (
    SELECT
      $1::INTEGER,
      $2::VARCHAR,
      $3::DECIMAL(18,2),
      $4::DATE,
      METADATA$FILENAME
    FROM @stage_sales
  )
  FILE_FORMAT = csv_format
  ON_ERROR = 'CONTINUE';

-- Pipe for customers folder
CREATE OR REPLACE PIPE pipe_customers
  AUTO_INGEST = TRUE
  AS
  COPY INTO customers (customer_id, name, email, phone, _source_file)
  FROM (
    SELECT
      $1::INTEGER,
      $2::VARCHAR,
      $3::VARCHAR,
      $4::VARCHAR,
      METADATA$FILENAME
    FROM @stage_customers
  )
  FILE_FORMAT = csv_format
  ON_ERROR = 'CONTINUE';

-- Pipe for orders folder
CREATE OR REPLACE PIPE pipe_orders
  AUTO_INGEST = TRUE
  AS
  COPY INTO orders (order_id, customer_id, total, status, _source_file)
  FROM (
    SELECT
      $1::INTEGER,
      $2::INTEGER,
      $3::DECIMAL(18,2),
      $4::VARCHAR,
      METADATA$FILENAME
    FROM @stage_orders
  )
  FILE_FORMAT = csv_format
  ON_ERROR = 'CONTINUE';

-- Get notification_channel URLs for Azure Event Grid setup
-- IMPORTANT: You need to create ONE Event Grid subscription per pipe
SHOW PIPES;

DESC PIPE pipe_sales;
DESC PIPE pipe_customers;
DESC PIPE pipe_orders;

-- =============================================================================
-- >>> CONFIGURE AZURE EVENT GRID <<<
-- Create 3 separate Event Grid subscriptions in Azure:
--   1. For sales folder     → use notification_channel from pipe_sales
--   2. For customers folder → use notification_channel from pipe_customers
--   3. For orders folder    → use notification_channel from pipe_orders
--
-- Each subscription should filter by folder prefix:
--   - Subject Begins With: /blobServices/default/containers/<container>/blobs/sales/
--   - Subject Begins With: /blobServices/default/containers/<container>/blobs/customers/
--   - Subject Begins With: /blobServices/default/containers/<container>/blobs/orders/
-- =============================================================================


-- =============================================================================
-- UTILITY COMMANDS
-- =============================================================================

-- Check all pipe statuses
-- SELECT SYSTEM$PIPE_STATUS('pipe_sales');
-- SELECT SYSTEM$PIPE_STATUS('pipe_customers');
-- SELECT SYSTEM$PIPE_STATUS('pipe_orders');

-- Manually refresh pipes (for existing files)
-- ALTER PIPE pipe_sales REFRESH;
-- ALTER PIPE pipe_customers REFRESH;
-- ALTER PIPE pipe_orders REFRESH;

-- View loaded data
-- SELECT * FROM sales ORDER BY _loaded_at DESC LIMIT 100;
-- SELECT * FROM customers ORDER BY _loaded_at DESC LIMIT 100;
-- SELECT * FROM orders ORDER BY _loaded_at DESC LIMIT 100;

-- Check copy history for each table
-- SELECT * FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
--   TABLE_NAME => 'SALES',
--   START_TIME => DATEADD(HOUR, -24, CURRENT_TIMESTAMP())
-- )) ORDER BY LAST_LOAD_TIME DESC;

-- Pause/Resume pipes
-- ALTER PIPE pipe_sales SET PIPE_EXECUTION_PAUSED = TRUE;
-- ALTER PIPE pipe_sales SET PIPE_EXECUTION_PAUSED = FALSE;

-- =============================================================================
-- Snowpipe Commands for Sales, Customers, Orders Tables
-- =============================================================================
-- Each pipe loads data from its folder directly to the destination table
-- =============================================================================

USE DATABASE AZURE_DATA_DB;
USE SCHEMA RAW_DATA;


-- =============================================================================
-- STAGES (one per folder)
-- =============================================================================

CREATE OR REPLACE STAGE stage_sales
  STORAGE_INTEGRATION = azure_blob_integration
  URL = 'azure://<your-storage-account>.blob.core.windows.net/<your-container>/sales/'
  FILE_FORMAT = csv_format;

CREATE OR REPLACE STAGE stage_customers
  STORAGE_INTEGRATION = azure_blob_integration
  URL = 'azure://<your-storage-account>.blob.core.windows.net/<your-container>/customers/'
  FILE_FORMAT = csv_format;

CREATE OR REPLACE STAGE stage_orders
  STORAGE_INTEGRATION = azure_blob_integration
  URL = 'azure://<your-storage-account>.blob.core.windows.net/<your-container>/orders/'
  FILE_FORMAT = csv_format;


-- =============================================================================
-- SNOWPIPE: Sales
-- =============================================================================

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


-- =============================================================================
-- SNOWPIPE: Customers
-- =============================================================================

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


-- =============================================================================
-- SNOWPIPE: Orders
-- =============================================================================

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


-- =============================================================================
-- GET NOTIFICATION CHANNELS
-- =============================================================================
-- Run these to get the notification_channel URLs for Azure Event Grid setup

DESC PIPE pipe_sales;
DESC PIPE pipe_customers;
DESC PIPE pipe_orders;


-- =============================================================================
-- UTILITY COMMANDS
-- =============================================================================

-- Check pipe status
-- SELECT SYSTEM$PIPE_STATUS('pipe_sales');
-- SELECT SYSTEM$PIPE_STATUS('pipe_customers');
-- SELECT SYSTEM$PIPE_STATUS('pipe_orders');

-- Manual refresh (load existing files)
-- ALTER PIPE pipe_sales REFRESH;
-- ALTER PIPE pipe_customers REFRESH;
-- ALTER PIPE pipe_orders REFRESH;

-- Pause pipes
-- ALTER PIPE pipe_sales SET PIPE_EXECUTION_PAUSED = TRUE;
-- ALTER PIPE pipe_customers SET PIPE_EXECUTION_PAUSED = TRUE;
-- ALTER PIPE pipe_orders SET PIPE_EXECUTION_PAUSED = TRUE;

-- Resume pipes
-- ALTER PIPE pipe_sales SET PIPE_EXECUTION_PAUSED = FALSE;
-- ALTER PIPE pipe_customers SET PIPE_EXECUTION_PAUSED = FALSE;
-- ALTER PIPE pipe_orders SET PIPE_EXECUTION_PAUSED = FALSE;

-- =============================================================================
-- Azure Blob to Snowflake - Snowpipe Setup
-- =============================================================================
-- This script sets up automatic data ingestion from Azure Blob Storage
-- to Snowflake using Snowpipe.
--
-- Prerequisites:
--   - Snowflake account with ACCOUNTADMIN access
--   - Azure Storage Account and Blob Container
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
-- Creates a secure connection between Snowflake and Azure Blob Storage
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
-- IMPORTANT: Note down AZURE_CONSENT_URL and AZURE_MULTI_TENANT_APP_NAME
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
-- STEP 2: Database, Schema, File Format, and Table
-- =============================================================================

USE ROLE SYSADMIN;

-- Create database and schema
CREATE DATABASE IF NOT EXISTS AZURE_DATA_DB;
CREATE SCHEMA IF NOT EXISTS AZURE_DATA_DB.RAW_DATA;

USE DATABASE AZURE_DATA_DB;
USE SCHEMA RAW_DATA;

-- File format for CSV files (adjust as needed)
CREATE OR REPLACE FILE FORMAT csv_format
  TYPE = 'CSV'
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  NULL_IF = ('NULL', 'null', '')
  EMPTY_FIELD_AS_NULL = TRUE
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  TRIM_SPACE = TRUE
  ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;

-- Target table (MODIFY to match your data structure)
CREATE OR REPLACE TABLE sample_data (
    id              INTEGER,
    name            VARCHAR(255),
    email           VARCHAR(255),
    created_date    DATE,
    amount          DECIMAL(18,2),
    status          VARCHAR(50),
    _loaded_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_file    VARCHAR(500)
);


-- =============================================================================
-- STEP 3: External Stage
-- =============================================================================

CREATE OR REPLACE STAGE azure_blob_stage
  STORAGE_INTEGRATION = azure_blob_integration
  URL = 'azure://<your-storage-account>.blob.core.windows.net/<your-container>/'
  FILE_FORMAT = csv_format;

-- Verify connectivity
SHOW STAGES;
LIST @azure_blob_stage;


-- =============================================================================
-- STEP 4: Snowpipe
-- =============================================================================

CREATE OR REPLACE PIPE azure_snowpipe
  AUTO_INGEST = TRUE
  AS
  COPY INTO sample_data (id, name, email, created_date, amount, status, _source_file)
  FROM (
    SELECT
      $1::INTEGER,
      $2::VARCHAR,
      $3::VARCHAR,
      $4::DATE,
      $5::DECIMAL(18,2),
      $6::VARCHAR,
      METADATA$FILENAME
    FROM @azure_blob_stage
  )
  FILE_FORMAT = csv_format
  ON_ERROR = 'CONTINUE';

-- Get notification_channel URL for Azure Event Grid setup
DESC PIPE azure_snowpipe;

-- =============================================================================
-- >>> CONFIGURE AZURE EVENT GRID <<<
-- 1. Go to Azure Portal → Storage Account → Events
-- 2. Create Event Subscription:
--    - Event Type: Blob Created
--    - Endpoint Type: Storage Queue
--    - Endpoint: Paste notification_channel URL from above
-- =============================================================================


-- =============================================================================
-- UTILITY COMMANDS (run as needed)
-- =============================================================================

-- Check pipe status
-- SELECT SYSTEM$PIPE_STATUS('azure_snowpipe');

-- Manually refresh pipe (load existing files)
-- ALTER PIPE azure_snowpipe REFRESH;

-- View loaded data
-- SELECT * FROM sample_data ORDER BY _loaded_at DESC LIMIT 100;

-- Check copy history
-- SELECT *
-- FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
--   TABLE_NAME => 'SAMPLE_DATA',
--   START_TIME => DATEADD(HOUR, -24, CURRENT_TIMESTAMP())
-- ))
-- ORDER BY LAST_LOAD_TIME DESC;

-- Pause/Resume pipe
-- ALTER PIPE azure_snowpipe SET PIPE_EXECUTION_PAUSED = TRUE;
-- ALTER PIPE azure_snowpipe SET PIPE_EXECUTION_PAUSED = FALSE;

-- Drop all objects (cleanup)
-- DROP PIPE IF EXISTS azure_snowpipe;
-- DROP STAGE IF EXISTS azure_blob_stage;
-- DROP TABLE IF EXISTS sample_data;
-- DROP FILE FORMAT IF EXISTS csv_format;
-- DROP SCHEMA IF EXISTS AZURE_DATA_DB.RAW_DATA;
-- DROP DATABASE IF EXISTS AZURE_DATA_DB;
-- DROP STORAGE INTEGRATION IF EXISTS azure_blob_integration;

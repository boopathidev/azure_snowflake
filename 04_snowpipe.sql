-- =============================================================================
-- Step 4: Create Snowpipe for Automatic Data Ingestion
-- =============================================================================
-- Snowpipe automatically loads data when new files arrive in Azure Blob
-- =============================================================================

USE ROLE SYSADMIN;
USE DATABASE AZURE_DATA_DB;
USE SCHEMA RAW_DATA;

-- Create Snowpipe with auto-ingest enabled
CREATE OR REPLACE PIPE azure_snowpipe
  AUTO_INGEST = TRUE
  AS
  COPY INTO sample_data (id, name, email, created_date, amount, status, _source_file)
  FROM (
    SELECT
      $1::INTEGER,           -- id
      $2::VARCHAR,           -- name
      $3::VARCHAR,           -- email
      $4::DATE,              -- created_date
      $5::DECIMAL(18,2),     -- amount
      $6::VARCHAR,           -- status
      METADATA$FILENAME      -- source file name
    FROM @azure_blob_stage
  )
  FILE_FORMAT = csv_format
  ON_ERROR = 'CONTINUE';

-- Get the notification channel URL for Azure Event Grid setup
-- IMPORTANT: Copy the 'notification_channel' value - you'll need it for Azure
SHOW PIPES;
DESC PIPE azure_snowpipe;

-- The notification_channel will look like:
-- https://<account>.queue.core.windows.net/<queue-name>

-- =============================================================================
-- Manual Operations (for testing or backfilling)
-- =============================================================================

-- Manually trigger pipe to load existing files
-- ALTER PIPE azure_snowpipe REFRESH;

-- Check pipe status
-- SELECT SYSTEM$PIPE_STATUS('azure_snowpipe');

-- View recent pipe activity
-- SELECT *
-- FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
--   TABLE_NAME => 'SAMPLE_DATA',
--   START_TIME => DATEADD(HOUR, -24, CURRENT_TIMESTAMP())
-- ))
-- ORDER BY LAST_LOAD_TIME DESC;

-- Pause/Resume pipe
-- ALTER PIPE azure_snowpipe SET PIPE_EXECUTION_PAUSED = TRUE;
-- ALTER PIPE azure_snowpipe SET PIPE_EXECUTION_PAUSED = FALSE;

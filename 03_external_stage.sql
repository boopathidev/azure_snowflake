-- =============================================================================
-- Step 3: Create External Stage pointing to Azure Blob Storage
-- =============================================================================
-- The stage is a pointer to your Azure Blob container
-- =============================================================================

USE ROLE SYSADMIN;
USE DATABASE AZURE_DATA_DB;
USE SCHEMA RAW_DATA;

-- Create external stage using the storage integration
CREATE OR REPLACE STAGE azure_blob_stage
  STORAGE_INTEGRATION = azure_blob_integration
  URL = 'azure://<your-storage-account>.blob.core.windows.net/<your-container>/'
  FILE_FORMAT = csv_format;

-- Verify the stage was created
SHOW STAGES;

-- List files in the stage (to verify connectivity)
-- This should show files from your Azure Blob container
LIST @azure_blob_stage;

-- Test reading a sample file (optional)
-- SELECT $1, $2, $3 FROM @azure_blob_stage/sample.csv LIMIT 10;

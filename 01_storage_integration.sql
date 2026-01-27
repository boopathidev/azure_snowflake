-- =============================================================================
-- Step 1: Create Storage Integration for Azure Blob Storage
-- =============================================================================
-- This creates a secure connection between Snowflake and Azure Blob Storage
-- Run this with ACCOUNTADMIN role
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- Create the storage integration
CREATE OR REPLACE STORAGE INTEGRATION azure_blob_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'AZURE'
  ENABLED = TRUE
  AZURE_TENANT_ID = '<your-azure-tenant-id>'
  STORAGE_ALLOWED_LOCATIONS = ('azure://<your-storage-account>.blob.core.windows.net/<your-container>/');

-- Describe the integration to get the consent URL and service principal
-- You'll need these values to configure Azure permissions
DESC STORAGE INTEGRATION azure_blob_integration;

-- IMPORTANT: After running DESC, note down:
-- 1. AZURE_CONSENT_URL - Open this in a browser to grant Snowflake access
-- 2. AZURE_MULTI_TENANT_APP_NAME - Use this to find the service principal in Azure AD

-- Grant usage to your role (replace SYSADMIN with your role if different)
GRANT USAGE ON INTEGRATION azure_blob_integration TO ROLE SYSADMIN;

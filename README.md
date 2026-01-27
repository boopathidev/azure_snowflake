# Azure Blob to Snowflake using Snowpipe

This repository contains SQL scripts to set up automatic data ingestion from Azure Blob Storage to Snowflake using Snowpipe.

## Architecture

```
Azure Blob Storage → Event Grid → Snowpipe → Snowflake Table
```

## Prerequisites

- Snowflake account with ACCOUNTADMIN access
- Azure subscription with:
  - Storage Account
  - Blob Container
  - Permissions to create Event Grid subscriptions

## Setup Steps

### Step 1: Configure Snowflake Storage Integration

1. Edit `01_storage_integration.sql` and replace:
   - `<your-azure-tenant-id>` - Your Azure AD tenant ID
   - `<your-storage-account>` - Your Azure storage account name
   - `<your-container>` - Your blob container name

2. Run the script in Snowflake with ACCOUNTADMIN role

3. Run `DESC STORAGE INTEGRATION azure_blob_integration;` and note:
   - **AZURE_CONSENT_URL** - Open this URL in browser to grant consent
   - **AZURE_MULTI_TENANT_APP_NAME** - The Snowflake service principal name

### Step 2: Configure Azure Permissions

1. In Azure Portal, go to your Storage Account → Access Control (IAM)

2. Click **Add role assignment**:
   - Role: `Storage Blob Data Reader`
   - Assign to: The service principal from Step 1 (AZURE_MULTI_TENANT_APP_NAME)

3. Grant consent by opening the AZURE_CONSENT_URL in your browser

### Step 3: Create Database Objects

1. Edit `02_file_format_and_table.sql`:
   - Modify the table schema to match your actual data structure
   - Adjust file format settings if needed (delimiter, header, etc.)

2. Run the script in Snowflake

### Step 4: Create External Stage

1. Edit `03_external_stage.sql` and replace:
   - `<your-storage-account>` - Your Azure storage account name
   - `<your-container>` - Your blob container name

2. Run the script in Snowflake

3. Verify with `LIST @azure_blob_stage;` - you should see your files

### Step 5: Create Snowpipe

1. Edit `04_snowpipe.sql`:
   - Modify the COPY INTO statement to match your table columns
   - Adjust data type conversions as needed

2. Run the script in Snowflake

3. Run `DESC PIPE azure_snowpipe;` and copy the **notification_channel** URL

### Step 6: Configure Azure Event Grid (for Auto-Ingest)

1. In Azure Portal, go to your Storage Account → Events

2. Click **+ Event Subscription**:
   - Name: `snowflake-snowpipe`
   - Event Types: Select only `Blob Created`
   - Endpoint Type: `Storage Queue`
   - Endpoint: Paste the **notification_channel** URL from Step 5

3. Click **Create**

## Testing

### Upload Sample File

Upload `sample_data.csv` to your Azure Blob container:

```bash
# Using Azure CLI
az storage blob upload \
  --account-name <your-storage-account> \
  --container-name <your-container> \
  --name sample_data.csv \
  --file sample_data.csv
```

### Verify Data Loading

```sql
-- Check pipe status
SELECT SYSTEM$PIPE_STATUS('azure_snowpipe');

-- View loaded data
SELECT * FROM sample_data;

-- Check copy history
SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
  TABLE_NAME => 'SAMPLE_DATA',
  START_TIME => DATEADD(HOUR, -24, CURRENT_TIMESTAMP())
))
ORDER BY LAST_LOAD_TIME DESC;
```

### Manual Refresh (for existing files)

```sql
ALTER PIPE azure_snowpipe REFRESH;
```

## Troubleshooting

### Files not loading automatically

1. Verify Event Grid subscription is active in Azure Portal
2. Check the notification_channel URL is correctly configured
3. Verify the storage integration consent was granted

### Permission errors

1. Ensure the Snowflake service principal has `Storage Blob Data Reader` role
2. Re-run the consent URL if needed

### Data type errors

1. Check the COPY_HISTORY for error details
2. Adjust data type conversions in the pipe definition

## Files

| File | Description |
|------|-------------|
| `01_storage_integration.sql` | Creates Azure storage integration |
| `02_file_format_and_table.sql` | Creates database, file format, and target table |
| `03_external_stage.sql` | Creates external stage pointing to Azure |
| `04_snowpipe.sql` | Creates Snowpipe for auto-ingestion |
| `sample_data.csv` | Sample CSV file for testing |

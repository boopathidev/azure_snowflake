# Azure Blob to Snowflake using Snowpipe

Automatic data ingestion from Azure Blob Storage to Snowflake using Snowpipe.

## Architecture

```
Azure Blob Storage → Event Grid → Snowpipe → Snowflake Table
```

## Files

| File | Description |
|------|-------------|
| `snowflake_snowpipe_setup.sql` | Complete Snowflake setup (integration, stage, table, pipe) |
| `azure_setup_guide.md` | Step-by-step Azure configuration guide |
| `sample_data.csv` | Sample CSV file for testing |

## Quick Start

### 1. Update Configuration

Edit `snowflake_snowpipe_setup.sql` and replace:
- `<your-azure-tenant-id>` - Azure AD tenant ID
- `<your-storage-account>` - Azure storage account name
- `<your-container>` - Blob container name

### 2. Run Snowflake Setup

Run the SQL script in Snowflake, pausing after Step 1 to configure Azure permissions:

```sql
-- Run Step 1, then get these values:
DESC STORAGE INTEGRATION azure_blob_integration;
-- Note: AZURE_CONSENT_URL and AZURE_MULTI_TENANT_APP_NAME
```

### 3. Configure Azure Permissions

1. Open **AZURE_CONSENT_URL** in browser to grant consent
2. In Azure Portal → Storage Account → Access Control (IAM):
   - Add role: `Storage Blob Data Reader`
   - Assign to: Snowflake service principal (AZURE_MULTI_TENANT_APP_NAME)

### 4. Complete Snowflake Setup

Run remaining steps (2-4) in the SQL script, then get the notification channel:

```sql
DESC PIPE azure_snowpipe;
-- Note: notification_channel URL
```

### 5. Configure Azure Event Grid

1. Azure Portal → Storage Account → Events → + Event Subscription
2. Configure:
   - Event Type: `Blob Created`
   - Endpoint Type: `Storage Queue`
   - Endpoint: Paste **notification_channel** URL

### 6. Test

Upload `sample_data.csv` to your Azure container:

```bash
az storage blob upload \
  --account-name <your-storage-account> \
  --container-name <your-container> \
  --name sample_data.csv \
  --file sample_data.csv
```

Verify in Snowflake:

```sql
SELECT * FROM sample_data;
```

## Troubleshooting

```sql
-- Check pipe status
SELECT SYSTEM$PIPE_STATUS('azure_snowpipe');

-- View copy history
SELECT * FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
  TABLE_NAME => 'SAMPLE_DATA',
  START_TIME => DATEADD(HOUR, -24, CURRENT_TIMESTAMP())
));

-- Manual refresh for existing files
ALTER PIPE azure_snowpipe REFRESH;
```

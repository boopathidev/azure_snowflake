# Azure Setup Guide for Snowpipe Integration

Step-by-step instructions to configure Azure Blob Storage for Snowflake Snowpipe.

This guide uses the Raw Landing Table approach:
- Only 1 Event Grid subscription needed (regardless of folder count)
- All files land in one raw table, then route to final tables

---

## Prerequisites

- Azure subscription with contributor access
- Completed Step 1 of snowflake_snowpipe_setup.sql in Snowflake

---

## Step 1: Create Storage Account

Skip this step if you already have a storage account.

1. Go to Azure Portal
2. Search for "Storage accounts" and click it
3. Click "+ Create"
4. Fill in the details:
   - Subscription: Select your subscription
   - Resource group: Create new or select existing
   - Storage account name: Enter a unique name (lowercase, no spaces)
   - Region: Choose closest to your Snowflake region
   - Performance: Standard
   - Redundancy: LRS
5. Click "Review + Create"
6. Click "Create"
7. Wait for deployment to complete

---

## Step 2: Create Blob Container and Folders

1. Go to your Storage Account
2. In the left menu, click "Containers"
3. Click "+ Container"
4. Enter container name (e.g., snowflake-data)
5. Set "Public access level" to Private
6. Click "Create"
7. Click on the new container to open it
8. Create folders as needed:
   - Click "Add Directory", enter "sales", click "Create"
   - Click "Add Directory", enter "customers", click "Create"
   - Click "Add Directory", enter "orders", click "Create"

---

## Step 3: Get Snowflake Service Principal Info

Run this in Snowflake after completing Step 1 of snowflake_snowpipe_setup.sql:

    DESC STORAGE INTEGRATION azure_blob_integration;

Note down these two values:
- AZURE_CONSENT_URL
- AZURE_MULTI_TENANT_APP_NAME

---

## Step 4: Grant Consent to Snowflake

1. Copy the AZURE_CONSENT_URL from Step 3
2. Open the URL in your browser
3. Sign in with an Azure AD admin account
4. Review the permissions requested
5. Click "Accept"

---

## Step 5: Assign Storage Blob Data Reader Role

1. Go to your Storage Account in Azure Portal
2. In the left menu, click "Access Control (IAM)"
3. Click "+ Add" button
4. Select "Add role assignment"
5. On the Role tab:
   - Search for "Storage Blob Data Reader"
   - Select it
   - Click "Next"
6. On the Members tab:
   - Select "User, group, or service principal"
   - Click "+ Select members"
   - Search for the AZURE_MULTI_TENANT_APP_NAME from Step 3
   - Select the Snowflake service principal
   - Click "Select"
7. Click "Review + assign"
8. Click "Review + assign" again to confirm

---

## Step 6: Get Notification Channel from Snowflake

Run this in Snowflake after completing Step 6 of snowflake_snowpipe_setup.sql:

    DESC PIPE raw_landing_pipe;

Note down the notification_channel value.

---

## Step 7: Configure Event Grid (Single Subscription)

Only ONE Event Grid subscription is needed for all folders.

1. Go to your Storage Account in Azure Portal
2. In the left menu, click "Events"
3. Click "+ Event Subscription"
4. Fill in the Basic tab:
   - Name: snowpipe-raw-landing
   - Event Schema: Event Grid Schema
5. Under Event Types:
   - Uncheck all options
   - Check only "Blob Created"
6. Under Endpoint Details:
   - Endpoint Type: Select "Storage Queues"
   - Click "Select an endpoint"
   - Use the notification_channel from Step 6
   - Click "Confirm Selection"
7. Click "Create"

That's it. No folder-specific filters needed.

---

## Step 8: Upload Test Files

Upload sample files to any folder:

1. Go to your Storage Account
2. Click "Containers"
3. Click on your container name
4. Navigate to a folder (e.g., sales/)
5. Click "Upload"
6. Select the corresponding sample file
7. Click "Upload"

Repeat for other folders as needed.

---

## Step 9: Verify in Snowflake

Run these queries to confirm data loaded successfully:

    -- Check pipe status (should show RUNNING)
    SELECT SYSTEM$PIPE_STATUS('raw_landing_pipe');

    -- Check raw landing table (data arrives here first)
    SELECT * FROM raw_landing ORDER BY loaded_at DESC;

    -- Manually process data (or wait for scheduled task)
    CALL process_raw_data();

    -- Check final tables
    SELECT * FROM sales;
    SELECT * FROM customers;
    SELECT * FROM orders;

---

## How Data Flows

1. File uploaded to Azure Blob (any folder)
2. Event Grid notifies Snowpipe
3. Snowpipe loads data into raw_landing table
4. Scheduled task (every 5 minutes) processes raw data
5. Data routed to final tables based on folder path

---

## Adding New Folders

To add a new folder (e.g., products/):

1. Create the folder in Azure Blob container
2. In Snowflake:
   - Create the destination table
   - Add processing logic to the stored procedure

No Azure configuration changes needed.

---

## Troubleshooting

### Data not appearing in raw_landing

1. Check Event Grid subscription is active
2. Verify pipe status: SELECT SYSTEM$PIPE_STATUS('raw_landing_pipe')
3. Check permissions were granted correctly

### Data in raw_landing but not in final tables

1. Check if task is running: SHOW TASKS
2. Manually run: CALL process_raw_data()
3. Check processed column: SELECT * FROM raw_landing WHERE processed = FALSE

### Manual load for existing files

    ALTER PIPE raw_landing_pipe REFRESH;

---

## Configuration Checklist

Before testing, confirm you have:

- [ ] Storage account created
- [ ] Blob container created with folders
- [ ] Consent granted via AZURE_CONSENT_URL
- [ ] Storage Blob Data Reader role assigned
- [ ] Event Grid subscription created (just one)
- [ ] Snowpipe created and running
- [ ] Processing task enabled

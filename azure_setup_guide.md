# Azure Setup Guide for Snowpipe Integration

Step-by-step instructions to configure Azure Blob Storage for Snowflake Snowpipe.

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

## Step 2: Create Blob Container

1. Go to your Storage Account
2. In the left menu, click "Containers"
3. Click "+ Container"
4. Enter container name (e.g., snowflake-data)
5. Set "Public access level" to Private
6. Click "Create"

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

Run this in Snowflake after completing Step 4 of snowflake_snowpipe_setup.sql:

    DESC PIPE azure_snowpipe;

Note down the notification_channel value. It looks like:

    https://accountname.queue.core.windows.net/queuename

---

## Step 7: Configure Event Grid

1. Go to your Storage Account in Azure Portal
2. In the left menu, click "Events"
3. Click "+ Event Subscription"
4. Fill in the Basic tab:
   - Name: snowflake-snowpipe-events
   - Event Schema: Event Grid Schema
5. Under Event Types:
   - Uncheck all options
   - Check only "Blob Created"
6. Under Endpoint Details:
   - Endpoint Type: Select "Storage Queues"
   - Click "Select an endpoint"
   - From the notification_channel URL, identify:
     - Storage account name (before .queue.core.windows.net)
     - Queue name (after the last /)
   - Select the storage account
   - Enter the queue name
   - Click "Confirm Selection"
7. Click "Create"

---

## Step 8: Upload Test File

1. Go to your Storage Account
2. Click "Containers"
3. Click on your container name
4. Click "Upload"
5. Select sample_data.csv from this repository
6. Click "Upload"

---

## Step 9: Verify in Snowflake

Run these queries to confirm data loaded successfully:

    -- Check pipe status (should show RUNNING)
    SELECT SYSTEM$PIPE_STATUS('azure_snowpipe');

    -- View loaded data (wait 1-2 minutes after upload)
    SELECT * FROM sample_data;

    -- Check copy history
    SELECT * FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
      TABLE_NAME => 'SAMPLE_DATA',
      START_TIME => DATEADD(HOUR, -1, CURRENT_TIMESTAMP())
    ));

---

## Troubleshooting

### Data not loading automatically

1. Check Event Grid subscription is active:
   - Go to Storage Account → Events → Event Subscriptions
   - Status should show "Active"

2. Verify permissions:
   - Ensure consent was granted in Step 4
   - Verify role assignment exists in Step 5

3. Check pipe status in Snowflake:
   - Run SELECT SYSTEM$PIPE_STATUS('azure_snowpipe')
   - Should show executionState as RUNNING

### Permission denied errors

1. Re-open the consent URL and accept again
2. Verify the service principal has Storage Blob Data Reader role
3. Check that the container path in Snowflake matches your actual container

### Manual load for existing files

If files existed before Event Grid was configured:

    ALTER PIPE azure_snowpipe REFRESH;

---

## Configuration Checklist

Before testing, confirm you have:

- [ ] Storage account created
- [ ] Blob container created
- [ ] Consent granted via AZURE_CONSENT_URL
- [ ] Storage Blob Data Reader role assigned to Snowflake service principal
- [ ] Event Grid subscription created with Blob Created event
- [ ] Snowpipe created and running

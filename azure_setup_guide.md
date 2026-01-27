# Azure Setup Guide for Snowpipe Integration

Step-by-step instructions to configure Azure Blob Storage for Snowflake Snowpipe.

---

## Prerequisites

- Azure subscription with contributor access
- Azure CLI installed (optional, for CLI commands)
- Completed Step 1 of `snowflake_snowpipe_setup.sql` in Snowflake

---

## Step 1: Create Storage Account (Skip if exists)

### Azure Portal

1. Go to **Azure Portal** → **Storage accounts** → **+ Create**
2. Configure:
   - **Subscription**: Select your subscription
   - **Resource group**: Create new or select existing
   - **Storage account name**: `<your-storage-account>` (lowercase, globally unique)
   - **Region**: Choose closest to your Snowflake region
   - **Performance**: Standard
   - **Redundancy**: LRS (or as needed)
3. Click **Review + Create** → **Create**

### Azure CLI

```bash
# Set variables
RESOURCE_GROUP="your-resource-group"
STORAGE_ACCOUNT="yourstorageaccount"
LOCATION="eastus"

# Create resource group (if needed)
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create storage account
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS \
  --kind StorageV2
```

---

## Step 2: Create Blob Container

### Azure Portal

1. Go to **Storage account** → **Containers** → **+ Container**
2. Configure:
   - **Name**: `<your-container>` (e.g., `snowflake-data`)
   - **Public access level**: Private
3. Click **Create**

### Azure CLI

```bash
CONTAINER_NAME="snowflake-data"

az storage container create \
  --name $CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT
```

---

## Step 3: Get Snowflake Service Principal Info

Run this in Snowflake (after Step 1 of snowflake_snowpipe_setup.sql):

```sql
DESC STORAGE INTEGRATION azure_blob_integration;
```

Note down these values:
- **AZURE_CONSENT_URL** - URL to grant Snowflake access
- **AZURE_MULTI_TENANT_APP_NAME** - Snowflake's service principal name

---

## Step 4: Grant Consent to Snowflake

1. Copy the **AZURE_CONSENT_URL** from Step 3
2. Open URL in browser (use an account with Azure AD admin rights)
3. Review permissions requested
4. Click **Accept** to grant consent

---

## Step 5: Assign Storage Blob Data Reader Role

### Azure Portal

1. Go to **Storage account** → **Access Control (IAM)**
2. Click **+ Add** → **Add role assignment**
3. **Role tab**:
   - Search and select: `Storage Blob Data Reader`
   - Click **Next**
4. **Members tab**:
   - **Assign access to**: User, group, or service principal
   - Click **+ Select members**
   - Search for the **AZURE_MULTI_TENANT_APP_NAME** from Step 3
   - Select the Snowflake service principal
   - Click **Select**
5. Click **Review + assign** → **Review + assign**

### Azure CLI

```bash
# Get the service principal object ID
# Replace with your AZURE_MULTI_TENANT_APP_NAME
SP_NAME="your-snowflake-service-principal-name"

SP_OBJECT_ID=$(az ad sp list --display-name "$SP_NAME" --query "[0].id" -o tsv)

# Get storage account resource ID
STORAGE_ID=$(az storage account show \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --query id -o tsv)

# Assign role
az role assignment create \
  --role "Storage Blob Data Reader" \
  --assignee-object-id $SP_OBJECT_ID \
  --assignee-principal-type ServicePrincipal \
  --scope $STORAGE_ID
```

---

## Step 6: Configure Event Grid for Auto-Ingest

First, get the notification channel from Snowflake:

```sql
DESC PIPE azure_snowpipe;
```

Note the **notification_channel** URL.

### Azure Portal

1. Go to **Storage account** → **Events**
2. Click **+ Event Subscription**
3. **Basic tab**:
   - **Name**: `snowflake-snowpipe-events`
   - **Event Schema**: Event Grid Schema
   - **System Topic Name**: `snowflake-topic` (auto-created)
4. **Event Types**:
   - Uncheck all except: **Blob Created**
5. **Endpoint Details**:
   - **Endpoint Type**: Storage Queues
   - **Endpoint**: Click **Select an endpoint**
     - Parse the notification_channel URL:
       - Format: `https://<account>.queue.core.windows.net/<queue-name>`
     - **Storage account**: Select the storage account from URL
     - **Queue**: Enter the queue name from URL
   - Click **Confirm Selection**
6. Click **Create**

### Azure CLI

```bash
# Variables from Snowflake notification_channel
# Example: https://mystorageaccount.queue.core.windows.net/snowpipe-queue
QUEUE_STORAGE_ACCOUNT="mystorageaccount"
QUEUE_NAME="snowpipe-queue"

# Get storage account resource ID
STORAGE_ID=$(az storage account show \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --query id -o tsv)

# Get queue resource ID
QUEUE_ID="/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$QUEUE_STORAGE_ACCOUNT/queueServices/default/queues/$QUEUE_NAME"

# Create event subscription
az eventgrid event-subscription create \
  --name "snowflake-snowpipe-events" \
  --source-resource-id $STORAGE_ID \
  --endpoint-type storagequeue \
  --endpoint $QUEUE_ID \
  --included-event-types "Microsoft.Storage.BlobCreated"
```

---

## Step 7: Test the Setup

### Upload Sample File

#### Azure Portal

1. Go to **Storage account** → **Containers** → **your-container**
2. Click **Upload**
3. Select `sample_data.csv` from this repository
4. Click **Upload**

#### Azure CLI

```bash
az storage blob upload \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER_NAME \
  --name sample_data.csv \
  --file sample_data.csv \
  --auth-mode login
```

### Verify in Snowflake

```sql
-- Check pipe status (should show "RUNNING")
SELECT SYSTEM$PIPE_STATUS('azure_snowpipe');

-- Wait 1-2 minutes, then check data
SELECT * FROM sample_data;

-- Check copy history for details
SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
  TABLE_NAME => 'SAMPLE_DATA',
  START_TIME => DATEADD(HOUR, -1, CURRENT_TIMESTAMP())
));
```

---

## Troubleshooting

### Event Grid subscription fails

- Ensure the queue endpoint URL is correct
- Verify the storage account exists and is accessible

### No data loading

1. Check Event Grid subscription is active:
   - Storage account → Events → Event Subscriptions
   - Status should be "Active"

2. Verify permissions:
   - Ensure consent was granted (Step 4)
   - Verify role assignment exists (Step 5)

3. Check Snowflake:
   ```sql
   -- Pipe status
   SELECT SYSTEM$PIPE_STATUS('azure_snowpipe');

   -- Recent errors
   SELECT *
   FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
     TABLE_NAME => 'SAMPLE_DATA',
     START_TIME => DATEADD(HOUR, -24, CURRENT_TIMESTAMP())
   ))
   WHERE STATUS = 'LOAD_FAILED';
   ```

### Permission denied errors

- Re-run the consent URL
- Verify the service principal has the correct role on the storage account
- Check that STORAGE_ALLOWED_LOCATIONS in Snowflake matches your container path

---

## Configuration Summary

| Setting | Value |
|---------|-------|
| Storage Account | `<your-storage-account>` |
| Container | `<your-container>` |
| Azure Tenant ID | `<your-azure-tenant-id>` |
| Snowflake Service Principal | From DESC STORAGE INTEGRATION |
| Notification Channel | From DESC PIPE |

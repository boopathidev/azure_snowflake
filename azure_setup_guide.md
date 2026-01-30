# Azure Setup Guide for Snowpipe Integration

Step-by-step instructions to configure Azure Blob Storage for Snowflake Snowpipe.

This guide covers multi-folder setup with 3 folders:
- sales → sales table
- customers → customers table
- orders → orders table

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
8. Create the 3 folders:
   - Click "Add Directory", enter "sales", click "Create"
   - Click "Add Directory", enter "customers", click "Create"
   - Click "Add Directory", enter "orders", click "Create"

Your folder structure should look like:

    container/
    ├── sales/
    ├── customers/
    └── orders/

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

## Step 6: Get Notification Channels from Snowflake

Run these in Snowflake after completing Step 5 of snowflake_snowpipe_setup.sql:

    DESC PIPE pipe_sales;
    DESC PIPE pipe_customers;
    DESC PIPE pipe_orders;

Note down the notification_channel value for each pipe:

| Pipe | Notification Channel |
|------|---------------------|
| pipe_sales | (copy the URL) |
| pipe_customers | (copy the URL) |
| pipe_orders | (copy the URL) |

---

## Step 7: Configure Event Grid (3 Subscriptions)

You need to create 3 separate Event Grid subscriptions, one for each folder.

### 7a: Create Event Subscription for Sales

1. Go to your Storage Account in Azure Portal
2. In the left menu, click "Events"
3. Click "+ Event Subscription"
4. Fill in the Basic tab:
   - Name: snowpipe-sales
   - Event Schema: Event Grid Schema
5. Under Event Types:
   - Uncheck all options
   - Check only "Blob Created"
6. Click "Filters" tab:
   - Check "Enable subject filtering"
   - Subject Begins With: /blobServices/default/containers/YOUR-CONTAINER/blobs/sales/
   - (Replace YOUR-CONTAINER with your actual container name)
7. Go back to "Basic" tab
8. Under Endpoint Details:
   - Endpoint Type: Select "Storage Queues"
   - Click "Select an endpoint"
   - Use the notification_channel from pipe_sales
   - Click "Confirm Selection"
9. Click "Create"

### 7b: Create Event Subscription for Customers

1. Go to Storage Account → Events
2. Click "+ Event Subscription"
3. Fill in the Basic tab:
   - Name: snowpipe-customers
   - Event Schema: Event Grid Schema
4. Under Event Types:
   - Uncheck all options
   - Check only "Blob Created"
5. Click "Filters" tab:
   - Check "Enable subject filtering"
   - Subject Begins With: /blobServices/default/containers/YOUR-CONTAINER/blobs/customers/
6. Go back to "Basic" tab
7. Under Endpoint Details:
   - Endpoint Type: Select "Storage Queues"
   - Click "Select an endpoint"
   - Use the notification_channel from pipe_customers
   - Click "Confirm Selection"
8. Click "Create"

### 7c: Create Event Subscription for Orders

1. Go to Storage Account → Events
2. Click "+ Event Subscription"
3. Fill in the Basic tab:
   - Name: snowpipe-orders
   - Event Schema: Event Grid Schema
4. Under Event Types:
   - Uncheck all options
   - Check only "Blob Created"
5. Click "Filters" tab:
   - Check "Enable subject filtering"
   - Subject Begins With: /blobServices/default/containers/YOUR-CONTAINER/blobs/orders/
6. Go back to "Basic" tab
7. Under Endpoint Details:
   - Endpoint Type: Select "Storage Queues"
   - Click "Select an endpoint"
   - Use the notification_channel from pipe_orders
   - Click "Confirm Selection"
8. Click "Create"

---

## Step 8: Upload Test Files

Upload sample files to each folder:

1. Go to your Storage Account
2. Click "Containers"
3. Click on your container name
4. For each folder (sales, customers, orders):
   - Click on the folder
   - Click "Upload"
   - Select the corresponding sample file
   - Click "Upload"

---

## Step 9: Verify in Snowflake

Run these queries to confirm data loaded successfully:

    -- Check all pipe statuses (should show RUNNING)
    SELECT SYSTEM$PIPE_STATUS('pipe_sales');
    SELECT SYSTEM$PIPE_STATUS('pipe_customers');
    SELECT SYSTEM$PIPE_STATUS('pipe_orders');

    -- View loaded data (wait 1-2 minutes after upload)
    SELECT * FROM sales;
    SELECT * FROM customers;
    SELECT * FROM orders;

---

## Troubleshooting

### Data not loading for a specific folder

1. Verify the Event Grid subscription exists for that folder
2. Check the subject filter matches the folder path exactly
3. Check the correct notification_channel was used

### Check Event Grid subscriptions

1. Go to Storage Account → Events → Event Subscriptions
2. All 3 subscriptions should show "Active" status:
   - snowpipe-sales
   - snowpipe-customers
   - snowpipe-orders

### Manual load for existing files

If files existed before Event Grid was configured:

    ALTER PIPE pipe_sales REFRESH;
    ALTER PIPE pipe_customers REFRESH;
    ALTER PIPE pipe_orders REFRESH;

---

## Configuration Checklist

Before testing, confirm you have:

- [ ] Storage account created
- [ ] Blob container created with 3 folders (sales, customers, orders)
- [ ] Consent granted via AZURE_CONSENT_URL
- [ ] Storage Blob Data Reader role assigned to Snowflake service principal
- [ ] Event Grid subscription created for sales folder
- [ ] Event Grid subscription created for customers folder
- [ ] Event Grid subscription created for orders folder
- [ ] All 3 Snowpipes created and running

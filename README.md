# Azure Blob to Snowflake using Snowpipe

Automatic data ingestion from Azure Blob Storage to Snowflake using Snowpipe.

## Approach: Raw Landing Table

This implementation uses the Raw Landing Table approach:

```
Azure Blob (all folders) → 1 Event Grid → 1 Pipe → Raw Table → Task → Final Tables
```

Benefits:
- Only 1 pipe and 1 Event Grid subscription (scales to any number of folders)
- Easy to add new folders without Azure changes
- All data visible in one place for debugging

## Files

| File | Description |
|------|-------------|
| `snowflake_snowpipe_setup.sql` | Snowflake setup (integration, stage, raw table, pipe, task) |
| `azure_setup_guide.md` | Step-by-step Azure configuration guide |
| `sample_sales.csv` | Sample data for sales folder |
| `sample_customers.csv` | Sample data for customers folder |
| `sample_orders.csv` | Sample data for orders folder |

## Data Flow

1. File uploaded to any folder in Azure Blob
2. Event Grid notifies Snowpipe
3. Snowpipe loads raw data into `raw_landing` table
4. Scheduled task (every 5 min) routes data to final tables based on folder path

## Quick Start

1. Edit `snowflake_snowpipe_setup.sql` - replace placeholder values
2. Run Snowflake Steps 1-6
3. Configure Azure (see `azure_setup_guide.md`)
4. Run Snowflake Step 7 (create and enable task)
5. Upload sample files to test

## Components

| Component | Count | Name |
|-----------|-------|------|
| Storage Integration | 1 | azure_blob_integration |
| Stage | 1 | azure_blob_stage |
| Pipe | 1 | raw_landing_pipe |
| Event Grid | 1 | snowpipe-raw-landing |
| Raw Table | 1 | raw_landing |
| Task | 1 | process_raw_landing |
| Final Tables | 3 | sales, customers, orders |

## Adding New Folders

1. Create folder in Azure Blob (no Event Grid changes needed)
2. Create destination table in Snowflake
3. Add processing logic to the stored procedure

See `azure_setup_guide.md` for detailed instructions.

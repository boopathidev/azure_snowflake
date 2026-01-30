# Azure Blob to Snowflake using Snowpipe

Automatic data ingestion from Azure Blob Storage to Snowflake using Snowpipe.

## Architecture

```
Azure Blob Storage → Event Grid → Snowpipe → Snowflake Table
```

Multi-folder setup:
- sales/ → sales table
- customers/ → customers table
- orders/ → orders table

## Files

| File | Description |
|------|-------------|
| `snowflake_snowpipe_setup.sql` | Snowflake setup (integration, stages, tables, pipes) |
| `azure_setup_guide.md` | Step-by-step Azure configuration guide |
| `sample_sales.csv` | Sample data for sales folder |
| `sample_customers.csv` | Sample data for customers folder |
| `sample_orders.csv` | Sample data for orders folder |

## Quick Start

1. Edit `snowflake_snowpipe_setup.sql` - replace placeholder values
2. Run Snowflake Steps 1-2
3. Configure Azure permissions (see `azure_setup_guide.md`)
4. Run Snowflake Steps 3-5
5. Configure Azure Event Grid (3 subscriptions)
6. Upload sample files to test

See `azure_setup_guide.md` for detailed instructions.

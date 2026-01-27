-- =============================================================================
-- Step 2: Create Database, Schema, File Format, and Target Table
-- =============================================================================
-- This sets up the destination for your data
-- =============================================================================

USE ROLE SYSADMIN;

-- Create database and schema (modify names as needed)
CREATE DATABASE IF NOT EXISTS AZURE_DATA_DB;
CREATE SCHEMA IF NOT EXISTS AZURE_DATA_DB.RAW_DATA;

USE DATABASE AZURE_DATA_DB;
USE SCHEMA RAW_DATA;

-- Create file format for CSV files
-- Adjust parameters based on your actual file format
CREATE OR REPLACE FILE FORMAT csv_format
  TYPE = 'CSV'
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  NULL_IF = ('NULL', 'null', '')
  EMPTY_FIELD_AS_NULL = TRUE
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  TRIM_SPACE = TRUE
  ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;

-- Create target table for sample data
-- MODIFY THIS to match your actual data structure
CREATE OR REPLACE TABLE sample_data (
    id              INTEGER,
    name            VARCHAR(255),
    email           VARCHAR(255),
    created_date    DATE,
    amount          DECIMAL(18,2),
    status          VARCHAR(50),
    -- Metadata columns (automatically populated)
    _loaded_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_file    VARCHAR(500)
);

-- Alternative: Create a flexible table that accepts any CSV structure
-- Useful for initial testing when you don't know the exact schema
CREATE OR REPLACE TABLE sample_data_raw (
    raw_data        VARIANT,
    _loaded_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_file    VARCHAR(500)
);

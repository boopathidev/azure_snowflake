-- =============================================================================
-- DDL for Final Destination Tables
-- =============================================================================
-- These tables receive processed data from the raw_landing table
-- =============================================================================

USE DATABASE AZURE_DATA_DB;
USE SCHEMA RAW_DATA;

-- =============================================================================
-- SALES Table
-- =============================================================================
-- Source: sales/ folder
-- Columns: id, product, amount, date

CREATE OR REPLACE TABLE sales (
    id              INTEGER         NOT NULL,
    product         VARCHAR(255)    NOT NULL,
    amount          DECIMAL(18,2)   NOT NULL,
    date            DATE            NOT NULL,
    _loaded_at      TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    _source_file    VARCHAR(500)
);


-- =============================================================================
-- CUSTOMERS Table
-- =============================================================================
-- Source: customers/ folder
-- Columns: customer_id, name, email, phone

CREATE OR REPLACE TABLE customers (
    customer_id     INTEGER         NOT NULL,
    name            VARCHAR(255)    NOT NULL,
    email           VARCHAR(255)    NOT NULL,
    phone           VARCHAR(50),
    _loaded_at      TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    _source_file    VARCHAR(500)
);


-- =============================================================================
-- ORDERS Table
-- =============================================================================
-- Source: orders/ folder
-- Columns: order_id, customer_id, total, status

CREATE OR REPLACE TABLE orders (
    order_id        INTEGER         NOT NULL,
    customer_id     INTEGER         NOT NULL,
    total           DECIMAL(18,2)   NOT NULL,
    status          VARCHAR(50)     NOT NULL,
    _loaded_at      TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    _source_file    VARCHAR(500)
);

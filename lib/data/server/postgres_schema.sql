-- =============================================================================
-- Phase 2 — Authoritative Server PostgreSQL / Supabase Database Schema
-- Parent Document: Database Specification v2.0 (Finalized)
-- Contains: 28 Tables, Foreign Keys, Composite FKs, CHECK Constraints, RLS Policies
-- =============================================================================

-- Enable pgcrypto for UUID v4 generation if needed
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================================
-- DOMAIN 1: CORE / AUTH TABLES (01 - 03)
-- =============================================================================

-- 01. companies
CREATE TABLE IF NOT EXISTS companies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL UNIQUE,
    fiscal_year_start VARCHAR(5) NOT NULL DEFAULT '01-01',
    fiscal_year_end VARCHAR(5) NOT NULL DEFAULT '12-31',
    currency VARCHAR(3) NOT NULL DEFAULT 'IQD',
    number_format VARCHAR(20) NOT NULL DEFAULT 'western' CHECK (number_format IN ('western', 'arabic_indic')),
    settings_json JSONB NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INT NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    device_id TEXT NOT NULL,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'pending'
);

-- 03. roles (Defined before users for FK reference)
CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    name VARCHAR(100) NOT NULL,
    permissions_json JSONB NOT NULL DEFAULT '{}',
    is_system BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INT NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    device_id TEXT NOT NULL,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    CONSTRAINT uq_roles_company_name UNIQUE (company_id, name)
);

-- 02. users
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY, -- Matches Supabase auth.users.id
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE RESTRICT,
    email VARCHAR(255) NOT NULL UNIQUE,
    display_name VARCHAR(255) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INT NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    device_id TEXT NOT NULL,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'pending'
);

-- Add composite unique constraint on companies for composite FK references
ALTER TABLE companies ADD CONSTRAINT uq_companies_id UNIQUE (id);
ALTER TABLE users ADD CONSTRAINT uq_users_company_id UNIQUE (company_id, id);

-- =============================================================================
-- DOMAIN 2: ACCOUNTING LEDGER TABLES (04 - 06)
-- =============================================================================

-- 04. accounts
CREATE TABLE IF NOT EXISTS accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    code VARCHAR(20) NOT NULL,
    name_ar VARCHAR(255) NOT NULL,
    name_en VARCHAR(255) NULL,
    type VARCHAR(20) NOT NULL CHECK (type IN ('asset', 'liability', 'equity', 'revenue', 'cogs', 'expense')),
    normal_balance VARCHAR(10) NOT NULL CHECK (normal_balance IN ('debit', 'credit')),
    parent_id UUID NULL REFERENCES accounts(id) ON DELETE RESTRICT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_system BOOLEAN NOT NULL DEFAULT FALSE,
    linked_entity_type VARCHAR(20) NULL CHECK (linked_entity_type IS NULL OR linked_entity_type IN ('customer', 'supplier', 'worker')),
    linked_entity_id UUID NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INT NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    device_id TEXT NOT NULL,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    CONSTRAINT uq_accounts_company_code UNIQUE (company_id, code),
    CONSTRAINT uq_accounts_company_id UNIQUE (company_id, id)
);

-- 05. journal_entries
CREATE TABLE IF NOT EXISTS journal_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    entry_number INT NOT NULL,
    date DATE NOT NULL,
    description TEXT NOT NULL,
    reference VARCHAR(100) NULL,
    source_type VARCHAR(30) NOT NULL CHECK (source_type IN ('sale', 'purchase', 'customer_payment', 'supplier_payment', 'expense', 'worker_advance', 'worker_salary', 'owner_withdrawal', 'manufacturing', 'reversal')),
    source_id UUID NOT NULL,
    is_reversal BOOLEAN NOT NULL DEFAULT FALSE,
    reversed_entry_id UUID NULL REFERENCES journal_entries(id) ON DELETE RESTRICT,
    status VARCHAR(10) NOT NULL DEFAULT 'posted' CHECK (status IN ('posted', 'reversed')),
    currency_code VARCHAR(3) NOT NULL DEFAULT 'IQD',
    idempotency_key VARCHAR(100) NOT NULL UNIQUE,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    device_id TEXT NOT NULL,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    CONSTRAINT uq_je_company_number UNIQUE (company_id, entry_number),
    CONSTRAINT uq_je_company_id UNIQUE (company_id, id)
);

-- 06. journal_entry_lines
CREATE TABLE IF NOT EXISTS journal_entry_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    journal_entry_id UUID NOT NULL REFERENCES journal_entries(id) ON DELETE RESTRICT,
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
    debit_amount BIGINT NOT NULL DEFAULT 0 CHECK (debit_amount >= 0),
    credit_amount BIGINT NOT NULL DEFAULT 0 CHECK (credit_amount >= 0),
    description TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_jel_debit_credit_mutual_exclusion CHECK (NOT (debit_amount > 0 AND credit_amount > 0)),
    CONSTRAINT chk_jel_must_have_amount CHECK (debit_amount > 0 OR credit_amount > 0),
    CONSTRAINT fk_jel_company_entry FOREIGN KEY (company_id, journal_entry_id) REFERENCES journal_entries(company_id, id) ON DELETE RESTRICT,
    CONSTRAINT fk_jel_company_account FOREIGN KEY (company_id, account_id) REFERENCES accounts(company_id, id) ON DELETE RESTRICT
);

-- =============================================================================
-- DOMAIN 3: MASTER DATA TABLES (07 - 10)
-- =============================================================================

-- 07. customers
CREATE TABLE IF NOT EXISTS customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(50) NULL,
    address TEXT NULL,
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
    notes TEXT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INT NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    device_id TEXT NOT NULL,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    CONSTRAINT uq_customers_company_name UNIQUE (company_id, name),
    CONSTRAINT uq_customers_company_id UNIQUE (company_id, id)
);

-- 08. suppliers
CREATE TABLE IF NOT EXISTS suppliers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(50) NULL,
    address TEXT NULL,
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
    notes TEXT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INT NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    device_id TEXT NOT NULL,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    CONSTRAINT uq_suppliers_company_name UNIQUE (company_id, name),
    CONSTRAINT uq_suppliers_company_id UNIQUE (company_id, id)
);

-- 09. workers
CREATE TABLE IF NOT EXISTS workers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(50) NULL,
    specialty VARCHAR(100) NULL,
    daily_rate BIGINT NULL,
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
    notes TEXT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INT NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    device_id TEXT NOT NULL,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    CONSTRAINT uq_workers_company_name UNIQUE (company_id, name),
    CONSTRAINT uq_workers_company_id UNIQUE (company_id, id)
);

-- 10. workshops
CREATE TABLE IF NOT EXISTS workshops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    name VARCHAR(255) NOT NULL,
    is_own_workshop BOOLEAN NOT NULL DEFAULT TRUE,
    address TEXT NULL,
    notes TEXT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INT NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    device_id TEXT NOT NULL,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    CONSTRAINT uq_workshops_company_name UNIQUE (company_id, name),
    CONSTRAINT uq_workshops_company_id UNIQUE (company_id, id)
);

-- =============================================================================
-- DOMAIN 4 & 5: BUSINESS DOCUMENTS & CONFIG (11 - 22)
-- =============================================================================

-- 18. expense_categories (Defined before expenses)
CREATE TABLE IF NOT EXISTS expense_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    name_ar VARCHAR(255) NOT NULL,
    name_en VARCHAR(255) NULL,
    group_name VARCHAR(20) NOT NULL CHECK (group_name IN ('general', 'operating')),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_system BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INT NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    device_id TEXT NOT NULL,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    CONSTRAINT uq_expcat_company_name UNIQUE (company_id, name_ar),
    CONSTRAINT uq_expcat_company_id UNIQUE (company_id, id)
);

-- 11. sales
CREATE TABLE IF NOT EXISTS sales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    customer_id UUID NULL REFERENCES customers(id) ON DELETE RESTRICT,
    sale_number INT NOT NULL,
    date DATE NOT NULL,
    total_amount BIGINT NOT NULL CHECK (total_amount > 0),
    cash_received BIGINT NOT NULL DEFAULT 0 CHECK (cash_received >= 0),
    credit_amount BIGINT NOT NULL DEFAULT 0 CHECK (credit_amount >= 0),
    payment_type VARCHAR(10) NOT NULL CHECK (payment_type IN ('cash', 'credit', 'mixed')),
    currency_code VARCHAR(3) NOT NULL DEFAULT 'IQD',
    journal_entry_id UUID NOT NULL REFERENCES journal_entries(id) ON DELETE RESTRICT,
    status VARCHAR(10) NOT NULL DEFAULT 'posted' CHECK (status IN ('posted', 'reversed')),
    notes TEXT NULL,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    idempotency_key VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INT NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    device_id TEXT NOT NULL,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    CONSTRAINT chk_sales_split_sum CHECK (cash_received + credit_amount = total_amount),
    CONSTRAINT uq_sales_company_number UNIQUE (company_id, sale_number),
    CONSTRAINT uq_sales_company_id UNIQUE (company_id, id)
);

-- 12. sale_items
CREATE TABLE IF NOT EXISTS sale_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    sale_id UUID NOT NULL REFERENCES sales(id) ON DELETE RESTRICT,
    description TEXT NOT NULL,
    quantity BIGINT NOT NULL CHECK (quantity > 0),
    unit_price BIGINT NOT NULL CHECK (unit_price >= 0),
    total_price BIGINT NOT NULL CHECK (total_price >= 0),
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_sale_items_company_sale FOREIGN KEY (company_id, sale_id) REFERENCES sales(company_id, id) ON DELETE RESTRICT
);

-- 13. purchases
CREATE TABLE IF NOT EXISTS purchases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    supplier_id UUID NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
    purchase_number INT NOT NULL,
    date DATE NOT NULL,
    total_amount BIGINT NOT NULL CHECK (total_amount > 0),
    cash_paid BIGINT NOT NULL DEFAULT 0 CHECK (cash_paid >= 0),
    credit_amount BIGINT NOT NULL DEFAULT 0 CHECK (credit_amount >= 0),
    payment_type VARCHAR(10) NOT NULL CHECK (payment_type IN ('cash', 'credit', 'mixed')),
    accounting_nature VARCHAR(20) NOT NULL CHECK (accounting_nature IN ('inventory', 'materials', 'operating_expense', 'service', 'other')),
    target_account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
    currency_code VARCHAR(3) NOT NULL DEFAULT 'IQD',
    journal_entry_id UUID NOT NULL REFERENCES journal_entries(id) ON DELETE RESTRICT,
    status VARCHAR(10) NOT NULL DEFAULT 'posted' CHECK (status IN ('posted', 'reversed')),
    notes TEXT NULL,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    idempotency_key VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INT NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    device_id TEXT NOT NULL,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    CONSTRAINT chk_purchases_split_sum CHECK (cash_paid + credit_amount = total_amount),
    CONSTRAINT uq_purchases_company_number UNIQUE (company_id, purchase_number),
    CONSTRAINT uq_purchases_company_id UNIQUE (company_id, id)
);

-- 14. purchase_items
CREATE TABLE IF NOT EXISTS purchase_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    purchase_id UUID NOT NULL REFERENCES purchases(id) ON DELETE RESTRICT,
    description TEXT NOT NULL,
    quantity BIGINT NOT NULL CHECK (quantity > 0),
    unit_price BIGINT NOT NULL CHECK (unit_price >= 0),
    total_price BIGINT NOT NULL CHECK (total_price >= 0),
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_purchase_items_company_purchase FOREIGN KEY (company_id, purchase_id) REFERENCES purchases(company_id, id) ON DELETE RESTRICT
);

-- 15. payments
CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    payment_number INT NOT NULL,
    date DATE NOT NULL,
    amount BIGINT NOT NULL CHECK (amount > 0),
    payment_method VARCHAR(20) NOT NULL CHECK (payment_method IN ('cash', 'bank', 'other')),
    direction VARCHAR(10) NOT NULL CHECK (direction IN ('incoming', 'outgoing')),
    customer_id UUID NULL REFERENCES customers(id) ON DELETE RESTRICT,
    supplier_id UUID NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
    currency_code VARCHAR(3) NOT NULL DEFAULT 'IQD',
    journal_entry_id UUID NOT NULL REFERENCES journal_entries(id) ON DELETE RESTRICT,
    status VARCHAR(10) NOT NULL DEFAULT 'posted' CHECK (status IN ('posted', 'reversed')),
    notes TEXT NULL,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    idempotency_key VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INT NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    device_id TEXT NOT NULL,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    CONSTRAINT chk_payment_entity_alignment CHECK (
        (direction = 'incoming' AND customer_id IS NOT NULL AND supplier_id IS NULL) OR
        (direction = 'outgoing' AND supplier_id IS NOT NULL AND customer_id IS NULL)
    ),
    CONSTRAINT uq_payments_company_number UNIQUE (company_id, payment_number),
    CONSTRAINT uq_payments_company_id UNIQUE (company_id, id)
);

-- 16. payment_allocations (Explicit Dual Foreign Keys + Exclusive Arc)
CREATE TABLE IF NOT EXISTS payment_allocations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    payment_id UUID NOT NULL REFERENCES payments(id) ON DELETE RESTRICT,
    sale_id UUID NULL REFERENCES sales(id) ON DELETE RESTRICT,
    purchase_id UUID NULL REFERENCES purchases(id) ON DELETE RESTRICT,
    allocated_amount BIGINT NOT NULL CHECK (allocated_amount > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INT NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    device_id TEXT NOT NULL,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    CONSTRAINT chk_pa_exclusive_arc CHECK (
        (sale_id IS NOT NULL AND purchase_id IS NULL) OR
        (sale_id IS NULL AND purchase_id IS NOT NULL)
    ),
    CONSTRAINT fk_pa_company_payment FOREIGN KEY (company_id, payment_id) REFERENCES payments(company_id, id) ON DELETE RESTRICT,
    CONSTRAINT fk_pa_company_sale FOREIGN KEY (company_id, sale_id) REFERENCES sales(company_id, id) ON DELETE RESTRICT,
    CONSTRAINT fk_pa_company_purchase FOREIGN KEY (company_id, purchase_id) REFERENCES purchases(company_id, id) ON DELETE RESTRICT
);

-- 17. expenses
CREATE TABLE IF NOT EXISTS expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    expense_number INT NOT NULL,
    date DATE NOT NULL,
    amount BIGINT NOT NULL CHECK (amount > 0),
    expense_category_id UUID NOT NULL REFERENCES expense_categories(id) ON DELETE RESTRICT,
    payment_method VARCHAR(20) NOT NULL CHECK (payment_method IN ('cash', 'bank', 'other')),
    description TEXT NULL,
    currency_code VARCHAR(3) NOT NULL DEFAULT 'IQD',
    journal_entry_id UUID NOT NULL REFERENCES journal_entries(id) ON DELETE RESTRICT,
    status VARCHAR(10) NOT NULL DEFAULT 'posted' CHECK (status IN ('posted', 'reversed')),
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    idempotency_key VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INT NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    device_id TEXT NOT NULL,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    CONSTRAINT uq_expenses_company_number UNIQUE (company_id, expense_number),
    CONSTRAINT uq_expenses_company_id UNIQUE (company_id, id)
);

-- 19. worker_advances
CREATE TABLE IF NOT EXISTS worker_advances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    worker_id UUID NOT NULL REFERENCES workers(id) ON DELETE RESTRICT,
    date DATE NOT NULL,
    amount BIGINT NOT NULL CHECK (amount > 0),
    payment_method VARCHAR(20) NOT NULL DEFAULT 'cash',
    journal_entry_id UUID NOT NULL REFERENCES journal_entries(id) ON DELETE RESTRICT,
    status VARCHAR(10) NOT NULL DEFAULT 'posted' CHECK (status IN ('posted', 'reversed')),
    notes TEXT NULL,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    idempotency_key VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INT NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    device_id TEXT NOT NULL,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    CONSTRAINT fk_wa_company_worker FOREIGN KEY (company_id, worker_id) REFERENCES workers(company_id, id) ON DELETE RESTRICT
);

-- 20. worker_salaries
CREATE TABLE IF NOT EXISTS worker_salaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    worker_id UUID NOT NULL REFERENCES workers(id) ON DELETE RESTRICT,
    date DATE NOT NULL,
    gross_salary BIGINT NOT NULL CHECK (gross_salary > 0),
    advance_deduction BIGINT NOT NULL DEFAULT 0 CHECK (advance_deduction >= 0),
    net_payment BIGINT NOT NULL CHECK (net_payment >= 0),
    payment_method VARCHAR(20) NOT NULL DEFAULT 'cash',
    journal_entry_id UUID NOT NULL REFERENCES journal_entries(id) ON DELETE RESTRICT,
    status VARCHAR(10) NOT NULL DEFAULT 'posted' CHECK (status IN ('posted', 'reversed')),
    notes TEXT NULL,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    idempotency_key VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INT NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    device_id TEXT NOT NULL,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    CONSTRAINT chk_ws_net_salary CHECK (net_payment = gross_salary - advance_deduction),
    CONSTRAINT fk_ws_company_worker FOREIGN KEY (company_id, worker_id) REFERENCES workers(company_id, id) ON DELETE RESTRICT
);

-- 21. owner_withdrawals
CREATE TABLE IF NOT EXISTS owner_withdrawals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    date DATE NOT NULL,
    amount BIGINT NOT NULL CHECK (amount > 0),
    payment_method VARCHAR(20) NOT NULL DEFAULT 'cash',
    description TEXT NULL,
    journal_entry_id UUID NOT NULL REFERENCES journal_entries(id) ON DELETE RESTRICT,
    status VARCHAR(10) NOT NULL DEFAULT 'posted' CHECK (status IN ('posted', 'reversed')),
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    idempotency_key VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INT NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    device_id TEXT NOT NULL,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'pending'
);

-- 22. manufacturing_jobs
CREATE TABLE IF NOT EXISTS manufacturing_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    job_number INT NOT NULL,
    workshop_id UUID NOT NULL REFERENCES workshops(id) ON DELETE RESTRICT,
    work_type VARCHAR(255) NOT NULL,
    scenario VARCHAR(20) NOT NULL CHECK (scenario IN ('external', 'owner_internal', 'internal_cost')),
    accounting_treatment VARCHAR(30) NOT NULL CHECK (accounting_treatment IN ('revenue', 'cost_of_manufacturing', 'direct_labor', 'materials', 'overhead')),
    total_cost BIGINT NOT NULL CHECK (total_cost > 0),
    date DATE NOT NULL,
    customer_id UUID NULL REFERENCES customers(id) ON DELETE RESTRICT,
    responsible_person VARCHAR(255) NULL,
    payment_method VARCHAR(20) NOT NULL DEFAULT 'cash',
    journal_entry_id UUID NOT NULL REFERENCES journal_entries(id) ON DELETE RESTRICT,
    status VARCHAR(10) NOT NULL DEFAULT 'posted' CHECK (status IN ('posted', 'reversed')),
    notes TEXT NULL,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    idempotency_key VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INT NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    device_id TEXT NOT NULL,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    CONSTRAINT uq_mj_company_number UNIQUE (company_id, job_number),
    CONSTRAINT uq_mj_company_id UNIQUE (company_id, id)
);

-- =============================================================================
-- DOMAIN 6: OPERATIONAL TABLES (23)
-- =============================================================================

-- 23. production_records
CREATE TABLE IF NOT EXISTS production_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    worker_id UUID NOT NULL REFERENCES workers(id) ON DELETE RESTRICT,
    manufacturing_job_id UUID NULL REFERENCES manufacturing_jobs(id) ON DELETE RESTRICT,
    work_type VARCHAR(255) NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    production_date DATE NOT NULL,
    notes TEXT NULL,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INT NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    device_id TEXT NOT NULL,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    CONSTRAINT fk_pr_company_worker FOREIGN KEY (company_id, worker_id) REFERENCES workers(company_id, id) ON DELETE RESTRICT
);

-- =============================================================================
-- DOMAIN 7: SYSTEM & SECURITY TABLES (24 - 28)
-- =============================================================================

-- 24. audit_logs (Push-only immutable log)
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    entity_type VARCHAR(30) NOT NULL,
    entity_id UUID NOT NULL,
    action VARCHAR(20) NOT NULL CHECK (action IN ('create', 'reverse', 'allocate', 'deallocate', 'update', 'soft_delete')),
    field_name VARCHAR(100) NULL,
    old_value TEXT NULL,
    new_value TEXT NULL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    device_id TEXT NOT NULL,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'pending'
);

-- 25. devices
CREATE TABLE IF NOT EXISTS devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_name VARCHAR(255) NOT NULL,
    platform VARCHAR(20) NOT NULL CHECK (platform IN ('windows', 'android', 'ios')),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    push_token TEXT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 28. shared_statements
CREATE TABLE IF NOT EXISTS shared_statements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    entity_type VARCHAR(20) NOT NULL CHECK (entity_type IN ('customer', 'supplier')),
    entity_id UUID NOT NULL,
    access_token_hash TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    is_revoked BOOLEAN NOT NULL DEFAULT FALSE,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- SUPABASE ROW-LEVEL SECURITY (RLS) POLICIES
-- Multi-Company Isolation Enforcement
-- =============================================================================

ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE journal_entry_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE workers ENABLE ROW LEVEL SECURITY;
ALTER TABLE workshops ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE expense_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE worker_advances ENABLE ROW LEVEL SECURITY;
ALTER TABLE worker_salaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE owner_withdrawals ENABLE ROW LEVEL SECURITY;
ALTER TABLE manufacturing_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE production_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE shared_statements ENABLE ROW LEVEL SECURITY;

-- Helper function to extract user's company_id from Supabase JWT auth token
CREATE OR REPLACE FUNCTION auth.user_company() RETURNS UUID AS $$
    SELECT (auth.jwt() -> 'user_metadata' ->> 'company_id')::UUID;
$$ LANGUAGE sql STABLE;

-- Generic company isolation policy macro for company-owned tables
CREATE POLICY company_isolation_policy ON accounts FOR ALL USING (company_id = auth.user_company());
CREATE POLICY company_isolation_policy ON journal_entries FOR ALL USING (company_id = auth.user_company());
CREATE POLICY company_isolation_policy ON journal_entry_lines FOR ALL USING (company_id = auth.user_company());
CREATE POLICY company_isolation_policy ON customers FOR ALL USING (company_id = auth.user_company());
CREATE POLICY company_isolation_policy ON suppliers FOR ALL USING (company_id = auth.user_company());
CREATE POLICY company_isolation_policy ON workers FOR ALL USING (company_id = auth.user_company());
CREATE POLICY company_isolation_policy ON workshops FOR ALL USING (company_id = auth.user_company());
CREATE POLICY company_isolation_policy ON sales FOR ALL USING (company_id = auth.user_company());
CREATE POLICY company_isolation_policy ON sale_items FOR ALL USING (company_id = auth.user_company());
CREATE POLICY company_isolation_policy ON purchases FOR ALL USING (company_id = auth.user_company());
CREATE POLICY company_isolation_policy ON purchase_items FOR ALL USING (company_id = auth.user_company());
CREATE POLICY company_isolation_policy ON payments FOR ALL USING (company_id = auth.user_company());
CREATE POLICY company_isolation_policy ON payment_allocations FOR ALL USING (company_id = auth.user_company());
CREATE POLICY company_isolation_policy ON expenses FOR ALL USING (company_id = auth.user_company());
CREATE POLICY company_isolation_policy ON expense_categories FOR ALL USING (company_id = auth.user_company());
CREATE POLICY company_isolation_policy ON worker_advances FOR ALL USING (company_id = auth.user_company());
CREATE POLICY company_isolation_policy ON worker_salaries FOR ALL USING (company_id = auth.user_company());
CREATE POLICY company_isolation_policy ON owner_withdrawals FOR ALL USING (company_id = auth.user_company());
CREATE POLICY company_isolation_policy ON manufacturing_jobs FOR ALL USING (company_id = auth.user_company());
CREATE POLICY company_isolation_policy ON production_records FOR ALL USING (company_id = auth.user_company());
CREATE POLICY company_isolation_policy ON audit_logs FOR ALL USING (company_id = auth.user_company());
CREATE POLICY company_isolation_policy ON shared_statements FOR ALL USING (company_id = auth.user_company());

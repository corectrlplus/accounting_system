-- =============================================================================
-- Phase 2 — Authoritative PostgreSQL Triggers & Financial Safeguards
-- Parent Document: Database Specification v2.0 (Finalized)
-- Contains: Deferred Journal Balance Check, Payment Direction Validation, Immutability Block
-- =============================================================================

-- =============================================================================
-- 1. DEFERRED JOURNAL BALANCE ATOMICITY TRIGGER
-- Enforces SUM(debit_amount) == SUM(credit_amount) at COMMIT moment.
-- =============================================================================

CREATE OR REPLACE FUNCTION verify_journal_entry_balance()
RETURNS TRIGGER AS $$
DECLARE
    v_total_debit BIGINT;
    v_total_credit BIGINT;
    v_target_entry_id UUID;
BEGIN
    IF (TG_OP = 'DELETE') THEN
        v_target_entry_id := OLD.journal_entry_id;
    ELSE
        v_target_entry_id := NEW.journal_entry_id;
    END IF;

    -- Calculate net debits and credits for the target entry
    SELECT 
        COALESCE(SUM(debit_amount), 0),
        COALESCE(SUM(credit_amount), 0)
    INTO 
        v_total_debit,
        v_total_credit
    FROM journal_entry_lines
    WHERE journal_entry_id = v_target_entry_id;

    -- Verify exact equality
    IF v_total_debit <> v_total_credit THEN
        RAISE EXCEPTION 'Journal Entry Imbalance Violation: Entry ID % has Total Debits (%) != Total Credits (%)',
            v_target_entry_id, v_total_debit, v_total_credit
            USING ERRCODE = '23514'; -- check_violation
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create DEFERRABLE INITIALLY DEFERRED constraint trigger on journal_entry_lines
DROP TRIGGER IF EXISTS trg_check_journal_entry_balance ON journal_entry_lines;

CREATE CONSTRAINT TRIGGER trg_check_journal_entry_balance
AFTER INSERT OR UPDATE OR DELETE ON journal_entry_lines
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION verify_journal_entry_balance();

-- =============================================================================
-- 2. PAYMENT DIRECTION INTEGRITY TRIGGER
-- Enforces incoming payments -> sale_id NOT NULL; outgoing -> purchase_id NOT NULL.
-- =============================================================================

CREATE OR REPLACE FUNCTION check_payment_allocation_direction()
RETURNS TRIGGER AS $$
DECLARE
    v_payment_direction VARCHAR(10);
BEGIN
    -- Fetch payment direction
    SELECT direction INTO v_payment_direction
    FROM payments
    WHERE id = NEW.payment_id;

    IF v_payment_direction IS NULL THEN
        RAISE EXCEPTION 'Payment Allocation Violation: Target payment % does not exist', NEW.payment_id;
    END IF;

    -- Verify direction alignment
    IF v_payment_direction = 'incoming' AND NEW.sale_id IS NULL THEN
        RAISE EXCEPTION 'Payment Direction Alignment Violation: Incoming payment % can only be allocated to a Sale (sale_id cannot be NULL)', NEW.payment_id;
    END IF;

    IF v_payment_direction = 'outgoing' AND NEW.purchase_id IS NULL THEN
        RAISE EXCEPTION 'Payment Direction Alignment Violation: Outgoing payment % can only be allocated to a Purchase (purchase_id cannot be NULL)', NEW.payment_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_payment_allocation_direction ON payment_allocations;

CREATE TRIGGER trg_check_payment_allocation_direction
BEFORE INSERT OR UPDATE ON payment_allocations
FOR EACH ROW
EXECUTE FUNCTION check_payment_allocation_direction();

-- =============================================================================
-- 3. POSTED LEDGER IMMUTABILITY TRIGGER
-- Blocks UPDATE and DELETE on posted journal entries and lines.
-- =============================================================================

CREATE OR REPLACE FUNCTION block_posted_ledger_mutation()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_TABLE_NAME = 'journal_entry_lines') THEN
        RAISE EXCEPTION 'Immutable Ledger Violation: Journal entry lines are append-only and cannot be updated or deleted.'
            USING ERRCODE = '55000'; -- object_not_in_prerequisite_state
    END IF;

    IF (TG_TABLE_NAME = 'journal_entries') THEN
        -- Allow status transition from 'posted' -> 'reversed'
        IF OLD.status = 'posted' AND NEW.status = 'reversed' THEN
            RETURN NEW;
        END IF;

        RAISE EXCEPTION 'Immutable Ledger Violation: Posted journal entries cannot be updated or deleted. Use reversal.'
            USING ERRCODE = '55000';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_block_jel_mutation ON journal_entry_lines;
CREATE TRIGGER trg_block_jel_mutation
BEFORE UPDATE OR DELETE ON journal_entry_lines
FOR EACH ROW
EXECUTE FUNCTION block_posted_ledger_mutation();

DROP TRIGGER IF EXISTS trg_block_je_mutation ON journal_entries;
CREATE TRIGGER trg_block_je_mutation
BEFORE UPDATE OR DELETE ON journal_entries
FOR EACH ROW
EXECUTE FUNCTION block_posted_ledger_mutation();

# Phase 3 — Accounting Engine Technical Architecture & Documentation

## Overview
The **Accounting Engine** is the central, authoritative gateway for all financial operations in the system. Repositories, services, UI screens, and external sync processes never directly create or modify journal entries or lines; all financial state transitions flow exclusively through the Accounting Engine.

---

## 1. Architecture & Core Invariants

### 10 Non-Negotiable Financial Invariants
1. **Double-Entry Balance Invariant:** Every posted journal entry must balance ($\sum \text{debits} = \sum \text{credits}$).
2. **Single Financial Gateway:** No financial transaction may bypass the Accounting Engine.
3. **Zero Floating-Point Financial Calculations:** Monetary values use integer Int64 minor units (scale = 1000) wrapped by the immutable `Money` Value Object.
4. **No Mutable Derived Balances:** Account, customer, supplier, and worker balances are dynamically derived from immutable ledger activity.
5. **Ledger Immutability:** Posted journal entries and journal entry lines cannot be directly updated or deleted.
6. **Immutable Correction Protocol:** Corrections are executed strictly via an atomic Reversal Transaction (swapping debits and credits) followed by a corrected transaction.
7. **Company Multi-Tenant Isolation:** Every transaction context, account, document, and ledger row is strictly scoped to a `company_id`.
8. **Deterministic Idempotency Safeguard:** Every financial operation uses a deterministic idempotency key (`{companyId}:{sourceType}:{sourceId}`); repeating or retrying the same business operation after network timeouts or app restarts returns original committed results without creating duplicate ledger entries.
9. **Atomic Execution:** Business document creation and double-entry journal entry persistence are atomic (all-or-nothing rollback on failure).
10. **TOCTOU Concurrency Lock:** Payment allocation limits are checked under exclusive transaction locks.

---

## 2. Domain Abstractions (Step 1 Foundation)

### Transaction Contexts
- **`TransactionContext`**: Carries `companyId`, `userId`, `deviceId`, and `timestampMs` for tenancy and auditing.
- **`IdempotencyContext`**: Wraps unique transaction idempotency keys generated via `IdempotencyGenerator.generateKey(companyId, sourceType, sourceId, deviceId)`. Omits execution timestamp to ensure 100% determinism across retries.

### Journal Draft Models
- **`JournalLineDraft`**: Represents an unpersisted double-entry line. Enforces:
  - Both `debitAmount >= 0` and `creditAmount >= 0`.
  - Exactly one side $> 0$ (no zero-amount lines, no double-populated lines).
  - Matches entry currency.
- **`JournalEntryDraft`**: Represents an unpersisted journal entry header with lines. Evaluates:
  - `totalDebit` ($\sum \text{debitAmount}$)
  - `totalCredit` ($\sum \text{creditAmount}$)
  - `isBalanced` (`totalDebit == totalCredit`)
  - `validateBalance()` returning `AccountingResult<void>` (`Success` or `ImbalanceError`).

### Result & Error Handling
- **`AccountingResult<T>`**: Functional Result wrapper (`isSuccess`, `isFailure`, `fold()`).
- **`AccountingError`**: Strongly typed domain error hierarchy (`ValidationError`, `ImbalanceError`, `IdempotencyError`, `ConcurrencyError`, `DirectionMismatchError`, `InsufficientAdvanceBalanceError`, `ImmutableLedgerError`, `CompanyMismatchError`).

---

## 3. Reusable Journal Entry Builder & Persistence Pipeline (Step 2)

### Responsibilities
- **`JournalEntryBuilder`**: Centralized, fluent builder for constructing `JournalEntryDraft` objects. Serves as the single reusable builder for all business transaction modules (Sales, Purchases, Payments, Expenses, Withdrawals, Workers, Manufacturing).
- **`JournalEntryRepository` / `JournalEntryRepositoryImpl`**: Data layer repository responsible for account verification, idempotency checking, and atomic database persistence.

### Validation Pipeline
1. **Builder Validation (`build()`):**
   - Context, source identity, description, and currency presence.
   - At least 2 lines required ($\ge 2$).
   - Line currency match ($\text{line.currency} == \text{entry.currency}$).
   - Double-entry balance equality ($\sum \text{debits} == \sum \text{credits}$). Returns `ImbalanceError` on failure.
2. **Repository Validation (`persistJournalEntry()`):**
   - **Company Isolation Check:** Rejects requests where `draft.companyId != context.companyId`.
   - **Account Verification:** Checks that every line `accountId` exists in `accounts`, belongs to `context.companyId`, and has `isActive == true`. Rejects cross-company or inactive account usage.
   - **Idempotency Verification:** Queries `journalEntries` by `idempotencyKey` + `companyId`. Rejects duplicates with `IdempotencyError`.
3. **Atomic Database Execution:**
   - Wraps header insertion and line insertions inside `db.insertJournalEntryAtomic()`.
   - All operations commit together or roll back completely on failure.

# Autonomous Warehouse Receiving & Inventory Reconciliation Engine

**TechCrush AI Automation Capstone — Cohort 8 · Group 11**

An n8n automation that reconciles what a business **ordered**, what the supplier **delivered**, what the warehouse **scanned** and what the supplier **invoiced**. Clean matches update stock automatically; every discrepancy becomes an AI-written investigation case that a person approves or rejects by email.

---

## What it does

| Capability | How |
|---|---|
| Ingests four document types | Purchase orders, delivery notes, barcode scans and invoices arrive through one webhook |
| Normalises supplier item codes | `KN/7741-B`, `kn 7741 b` and `KN_7742_A` are cleaned and mapped to internal SKUs through a lookup table |
| Reconciles the chain | Ordered → Delivered → Scanned → Invoiced, per order line |
| Categorises discrepancies | under-shipment, over-shipment, damage, over-billing, receiving shortage/overage, unmapped SKU, SKU mismatch |
| Investigates with AI | An AI agent writes a claim summary, recommended action and severity for each discrepancy |
| Keeps a human in control | Every case is approved or rejected by email; the decision updates the PO line and its delivery, scan and invoice rows; rejections trigger an escalation |
| Updates inventory | Stock is increased automatically for lines that match on all four documents |
| Handles failures | Node retries, plus an error workflow that emails an administrator and logs the failure (tested: 5 of 5 bad documents rejected and alerted) |
| Keeps an audit trail | Every state change and error is written to an audit log |

---

## Architecture

![Architecture](architecture.png)

Four workflows, each with one job, share a single Google Sheets database.

| Workflow | Trigger | Job |
|---|---|---|
| **1 – Ingest documents** | Webhook `POST /webhook/warehouse-ingest` | Validate incoming documents, assign IDs, store them as `pending` |
| **2 – Reconcile receiving** | Schedule (every 5 min) + manual trigger | Normalise SKUs, four-way match, update stock for matches, log results, hand discrepancies to Workflow 3 |
| **3 – Investigate discrepancy** | Called by Workflow 2 (sub-workflow) | Loop over cases: AI summary → investigation case → email approval → record the decision on the case and all four documents; escalate rejections |
| **4 – Error handler** | Error Trigger (linked to Workflows 1–3) | Email the administrator and write a `WORKFLOW_ERROR` audit row |

**External services:** Google Sheets (storage), Gmail (approvals, escalations, alerts), AI model via n8n AI Agent (Baseten chat model).

### Data store (Google Sheets, 8 tabs)

| Tab | Holds |
|---|---|
| Purchase_Orders | Order lines (`line_id`, `po_number`, `supplier_id`, `internal_sku`, `ordered_qty`, `unit_price`, `status`) |
| Deliveries | Delivery note lines (`delivery_id`, `supplier_sku_raw`, `delivered_qty`, `status`) |
| Warehouse_Scans | Scan counts (`scan_id`, `scanned_sku_raw`, `good_qty`, `damaged_qty`, `status`) |
| Invoices | Invoice lines (`invoice_id`, `supplier_sku_raw`, `invoiced_qty`, `unit_price`, `status`) |
| SKU_Map | `supplier_id`, `supplier_sku_clean`, `internal_sku` |
| Inventory | `internal_sku`, `on_hand` |
| Investigations | One case per discrepancy, with AI summary and approval status |
| Audit_Log | Every state change and error |

### Record lifecycle

`pending` → `processed` (clean match, stock updated)
`pending` → `discrepancy` → `approved` / `rejected` (human decision)
The PO line and its delivery, scan and invoice rows always share the same status.
A line missing any document stays `pending` until it arrives, then completes on the next run.

---

## Discrepancy rules

| Category | Rule |
|---|---|
| `under_shipment` | delivered < ordered |
| `over_shipment` | delivered > ordered |
| `receiving_shortage` | good + damaged < delivered |
| `receiving_overage` | good + damaged > delivered |
| `damage` | damaged > 0 |
| `over_billing` | invoiced > good |
| `unmapped_sku` | supplier code not in SKU_Map |
| `sku_mismatch` | code maps to a SKU that is not on the PO |

**Claim amount:** (invoiced − good) × unit price when billed above good units received; otherwise (ordered − good) × unit price for an under-shipment; 0 for SKU problems.

---

## AI guardrails

- The prompt includes only the case's real figures and instructs the model not to invent any.
- A guard stops the workflow if a case arrives without a PO number or line ID.
- The parser rejects any AI summary that does not name the case's own PO number, and forces `recommended_action` and `severity` into allowed values.
- A person approves or rejects every case before it becomes a claim.

---

## Repository contents

```
README.md                         this file
TEAM_MEMBERS.md                   active team members
architecture.png                  architecture diagram
workflows/
  1_ingest_documents.json         n8n workflow exports
  2_reconcile_receiving.json
  3_investigate_discrepancy.json
  4_error_handler.json
tests/
  test_e2e_v4.ps1                 normal path: 7 POs, auto-unique PO numbers
  test_e2e_v5.ps1                 error path: 3 good POs + 5 deliberately bad documents
docs/
  Project_Build_Note.pdf          build and test log, compliance, open items
  Architecture_and_Workflow_Reference.pdf   node-by-node reference
deployment/
  docker-compose.yml, .env.example, Caddyfile, backup.sh   on-site server setup
```

---

## Setup

1. **Google Sheet:** create one spreadsheet with the eight tabs above; put headers in row 1. Add SKU_Map and Inventory rows.
2. **n8n:** import the four workflow files (n8n 2.x; built on 2.30.7 self-hosted).
3. **Credentials:** create Google Sheets OAuth, Gmail OAuth and the AI model credential; select them on each node.
4. **Sheets nodes:** choose Document and Sheet **From list**; set write nodes to **Map Each Column Manually**.
5. **Links:** in Workflow 2 point the Execute Workflow node to Workflow 3 (Wait For Sub-Workflow Completion **off**); in Workflows 1–3 set **Settings → Error workflow** to Workflow 4, then **publish each workflow again** (a settings change only takes effect once published).
6. **Publish** Workflows 1, 3 and 4 (and Workflow 2 for scheduled production use).

---

## Testing

Both test paths passed on 9 October 2026.

**Normal path**

```powershell
.\tests\test_e2e_v4.ps1        # sends 4 batches to the webhook
# then run Workflow 2 (manual trigger) and answer the approval emails
```

Result: 3 matched lines (stock +10 rice, +50 sugar, +60 oil), 4 investigation cases (approve -03, -04, -06; reject -05 → escalation email), every decided PO showing the same status in all four document tabs, and PO -07 left `pending` because its delivery note has not arrived.

**Error path**

```powershell
.\tests\test_e2e_v5.ps1        # 3 good POs + 5 deliberately bad documents
```

| Bad document | Error raised by Validate and shape |
|---|---|
| Unknown document type | `Invalid doc_type "RECEIPT"` |
| Invoice with no quantity | `INVOICE row 1 is missing: invoiced_qty` |
| Scan with a negative count | `SCAN row 1: good_qty must be a non-negative number` |
| Delivery quantity as text | `DELIVERY row 1: delivered_qty must be a non-negative number` |
| PO batch with one bad row | `PO row 2 is missing: unit_price` (nothing from the batch stored) |

Result: 5 failed Workflow 1 runs, 5 Workflow 4 runs, 5 alert emails to the administrator, no bad record stored; the 3 good POs reconciled normally.

---

## Known limitations

- The webhook acknowledges a request before validation, so senders are not told about rejected records.
- A line can remain in `discrepancy` without a case if Workflow 3 fails before creating one; Workflow 4 alerts the administrator, but the line must be reset by hand.
- Approval emails have no timeout.
- Audit rows do not yet include the n8n execution ID or a payload hash.
- Google Sheets limits throughput; production use should move the data to PostgreSQL or Supabase.

# test_e2e_v5.ps1 - normal data PLUS five deliberately bad documents, to test error handling.
#
# PO numbers come from the current date and time (e.g. PO-ERR-091130-01), so every run is unique.
# Workflow 1 must be PUBLISHED and its Settings > Error workflow must be "4 - Error handler".
#
# PART A - good documents (3 POs). Expected after workflow 2:
#   -01  matched                    INV-SOAP-BAR  on_hand +200
#   -02  damage,over_billing        claim 38000   <- REJECT (escalation email)
#   -03  under_shipment             claim 24000   (approve)
#
# PART B - bad documents. Each is rejected by "Validate and shape", so workflow 1 fails
# and workflow 4 should email the admin and write a WORKFLOW_ERROR row:
#   E1  unknown document type        Invalid doc_type "RECEIPT"
#   E2  invoice missing quantity     INVOICE row 1 is missing: invoiced_qty
#   E3  scan with negative count     SCAN row 1: good_qty must be a non-negative number
#   E4  delivery quantity as text    DELIVERY row 1: delivered_qty must be a non-negative number
#   E5  PO batch with one bad row    PO row 2 is missing: unit_price   (row 1 is NOT stored either)
#   => 5 failed runs in workflow 1, 5 runs in workflow 4, 5 alert emails, 5 WORKFLOW_ERROR rows.
#
# PowerShell prints "sent" for every request: the webhook replies before validation runs.
# The real result is in n8n's executions, the inbox and Audit_Log.

$Run  = Get-Date -Format "ddHHmm"
$Base = "http://localhost:5678"
$Uri  = "$Base/webhook/warehouse-ingest"

function Post($payload) {
    $body = ($payload | ConvertTo-Json -Depth 6) -replace "PO-ERR-TEST-", "PO-ERR-$Run-"
    Invoke-RestMethod -Uri $Uri -Method POST -ContentType "application/json" -Body $body | Out-Null
}
function Send-Batch($label, $payload) {
    try { Post $payload; Write-Host "[$label] sent" -ForegroundColor Green }
    catch { Write-Host "[$label] FAILED TO SEND: $($_.Exception.Message) $($_.ErrorDetails.Message)" -ForegroundColor Red }
}
function Send-Bad($label, $payload) {
    try { Post $payload; Write-Host "[$label] sent (should FAIL in n8n)" -ForegroundColor Yellow }
    catch { Write-Host "[$label] FAILED TO SEND: $($_.Exception.Message) $($_.ErrorDetails.Message)" -ForegroundColor Red }
    Start-Sleep -Seconds 3
}

Write-Host "PART A - good documents" -ForegroundColor Cyan
Send-Batch "POs" @{
    doc_type = "PO"
    rows = @(
        @{ po_number = "PO-ERR-TEST-01"; supplier_id = "SUP-LAGOS"; internal_sku = "INV-SOAP-BAR"; ordered_qty = 200; unit_price = 350 },
        @{ po_number = "PO-ERR-TEST-02"; supplier_id = "SUP-LAGOS"; internal_sku = "INV-OIL-5L"; ordered_qty = 80; unit_price = 9500 },
        @{ po_number = "PO-ERR-TEST-03"; supplier_id = "SUP-KANO"; internal_sku = "INV-SUGAR-1KG"; ordered_qty = 120; unit_price = 1200 }
    )
}

Send-Batch "DELIVERIES" @{
    doc_type = "DELIVERY"
    rows = @(
        @{ po_number = "PO-ERR-TEST-01"; supplier_id = "SUP-LAGOS"; supplier_sku_raw = "LG 5531"; delivered_qty = 200 },
        @{ po_number = "PO-ERR-TEST-02"; supplier_id = "SUP-LAGOS"; supplier_sku_raw = "lg5520"; delivered_qty = 80 },
        @{ po_number = "PO-ERR-TEST-03"; supplier_id = "SUP-KANO"; supplier_sku_raw = "KN-7742-A"; delivered_qty = 100 }
    )
}

Send-Batch "SCANS" @{
    doc_type = "SCAN"
    rows = @(
        @{ po_number = "PO-ERR-TEST-01"; scanned_sku_raw = "lg-5531"; good_qty = 200; damaged_qty = 0; scanned_by = "m.ibrahim" },
        @{ po_number = "PO-ERR-TEST-02"; scanned_sku_raw = "LG.5520"; good_qty = 76; damaged_qty = 4; scanned_by = "m.ibrahim" },
        @{ po_number = "PO-ERR-TEST-03"; scanned_sku_raw = "kn7742a"; good_qty = 100; damaged_qty = 0; scanned_by = "o.nwosu" }
    )
}

Send-Batch "INVOICES" @{
    doc_type = "INVOICE"
    rows = @(
        @{ po_number = "PO-ERR-TEST-01"; supplier_id = "SUP-LAGOS"; supplier_sku_raw = "LG5531"; invoiced_qty = 200; unit_price = 350 },
        @{ po_number = "PO-ERR-TEST-02"; supplier_id = "SUP-LAGOS"; supplier_sku_raw = "LG 5520"; invoiced_qty = 80; unit_price = 9500 },
        @{ po_number = "PO-ERR-TEST-03"; supplier_id = "SUP-KANO"; supplier_sku_raw = "KN/7742/A"; invoiced_qty = 100; unit_price = 1200 }
    )
}

Write-Host "`nPART B - bad documents" -ForegroundColor Cyan
Send-Bad "E1 unknown document type" @{ doc_type = "RECEIPT"; po_number = "PO-ERR-TEST-91"; supplier_id = "SUP-KANO" }
Send-Bad "E2 invoice missing quantity" @{ doc_type = "INVOICE"; po_number = "PO-ERR-TEST-92"; supplier_id = "SUP-KANO"; supplier_sku_raw = "KN7741B"; unit_price = 45000 }
Send-Bad "E3 scan with negative count" @{ doc_type = "SCAN"; po_number = "PO-ERR-TEST-93"; scanned_sku_raw = "KN7741B"; good_qty = -5 }
Send-Bad "E4 delivery quantity as text" @{ doc_type = "DELIVERY"; po_number = "PO-ERR-TEST-94"; supplier_id = "SUP-ENUGU"; supplier_sku_raw = "EN8800X"; delivered_qty = "ten" }
Send-Bad "E5 PO batch with one bad row" @{ doc_type = "PO"; rows = @(
            @{ po_number = "PO-ERR-TEST-95"; supplier_id = "SUP-ENUGU"; internal_sku = "INV-FLOUR-10KG"; ordered_qty = 40; unit_price = 18000 },
            @{ po_number = "PO-ERR-TEST-95"; supplier_id = "SUP-ENUGU"; internal_sku = "INV-RICE-50KG"; ordered_qty = 10 }
        ) }

Write-Host "`nDone v5 (good: PO-ERR-$Run-01 to -03; bad: E1 to E5)." -ForegroundColor Cyan
Write-Host "Check: workflow 1 executions (5 errors), workflow 4 executions (5 runs), inbox (5 alerts), Audit_Log (5 WORKFLOW_ERROR rows)."
Write-Host "Then run workflow 2 (manual trigger) for PART A."

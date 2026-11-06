# End-to-end test data: five fresh POs sent through the ingest webhook.
# Uses supplier codes already in SKU_Map (S01 AB..., S02 BX..., S03 CG...).
#
# Change $Run before every new test (21 -> 22 -> 23 ...) so PO numbers never repeat.
# With $Run = 21 the POs are PO-2101 ... PO-2105.
#
# Expected after running workflow 2:
#   PO-xx01  matched                -> WH-1001 on_hand +50, status processed
#   PO-xx02  under_shipment         -> claim 40    (reject this one: tests escalation)
#   PO-xx03  damage, over_billing   -> claim 70    (approve)
#   PO-xx04  over_billing           -> claim 12    (approve)
#   PO-xx05  unmapped_sku           -> claim 0, AI should recommend fix_sku_mapping (approve)
#   (4 discrepancies = 4 approval emails, 1 escalation email)
#
# Mode "test": uses /webhook-test/ and pauses before each call. In n8n click
#              "Listen for test event" on the ingest Webhook node first (ONE call per click).
# Mode "prod": uses /webhook/ and sends everything at once. Workflow 1 must be published.

$Run  = 21       # change for every new test run
$Mode = "prod"   # "test" or "prod"
$Base = "http://localhost:5678"
$Path = if ($Mode -eq "prod") { "webhook" } else { "webhook-test" }
$Uri  = "$Base/$Path/warehouse-ingest"

$P1 = "PO-$($Run)01"; $P2 = "PO-$($Run)02"; $P3 = "PO-$($Run)03"; $P4 = "PO-$($Run)04"; $P5 = "PO-$($Run)05"

function Send-Batch($label, $payload) {
    if ($Mode -eq "test") {
        Read-Host "[$label] Click 'Listen for test event' in n8n, then press Enter"
    }
    $body = $payload | ConvertTo-Json -Depth 5
    try {
        Invoke-RestMethod -Uri $Uri -Method POST -ContentType "application/json" -Body $body | Out-Null
        Write-Host "[$label] sent OK" -ForegroundColor Green
    }
    catch {
        Write-Host "[$label] FAILED: $($_.Exception.Message) $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
}

Send-Batch "POs" @{
    doc_type = "PO"
    rows = @(
        @{ po_number = $P1; supplier_id = "S01"; internal_sku = "WH-1001"; ordered_qty = 50;  unit_price = 12.50 },
        @{ po_number = $P2; supplier_id = "S02"; internal_sku = "WH-2001"; ordered_qty = 100; unit_price = 2.00 },
        @{ po_number = $P3; supplier_id = "S03"; internal_sku = "WH-3001"; ordered_qty = 20;  unit_price = 35.00 },
        @{ po_number = $P4; supplier_id = "S01"; internal_sku = "WH-1002"; ordered_qty = 30;  unit_price = 4.00 },
        @{ po_number = $P5; supplier_id = "S02"; internal_sku = "WH-2001"; ordered_qty = 60;  unit_price = 2.00 }
    )
}

Send-Batch "DELIVERIES" @{
    doc_type = "DELIVERY"
    rows = @(
        @{ po_number = $P1; supplier_id = "S01"; supplier_sku_raw = "AB-1001"; delivered_qty = 50 },
        @{ po_number = $P2; supplier_id = "S02"; supplier_sku_raw = "BX-2001"; delivered_qty = 80 },
        @{ po_number = $P3; supplier_id = "S03"; supplier_sku_raw = "CG3001";  delivered_qty = 20 },
        @{ po_number = $P4; supplier_id = "S01"; supplier_sku_raw = "AB 1002"; delivered_qty = 30 },
        @{ po_number = $P5; supplier_id = "S02"; supplier_sku_raw = "ZZ-9999"; delivered_qty = 60 }
    )
}

Send-Batch "SCANS" @{
    doc_type = "SCAN"
    rows = @(
        @{ po_number = $P1; scanned_sku_raw = "ab1001";  good_qty = 50; damaged_qty = 0; scanned_by = "j.okafor" },
        @{ po_number = $P2; scanned_sku_raw = "BX2001";  good_qty = 80; damaged_qty = 0; scanned_by = "j.okafor" },
        @{ po_number = $P3; scanned_sku_raw = "CG-3001"; good_qty = 18; damaged_qty = 2; scanned_by = "a.musa" },
        @{ po_number = $P4; scanned_sku_raw = "AB1002";  good_qty = 30; damaged_qty = 0; scanned_by = "a.musa" },
        @{ po_number = $P5; scanned_sku_raw = "ZZ9999";  good_qty = 60; damaged_qty = 0; scanned_by = "a.musa" }
    )
}

Send-Batch "INVOICES" @{
    doc_type = "INVOICE"
    rows = @(
        @{ po_number = $P1; supplier_id = "S01"; supplier_sku_raw = "AB-1001"; invoiced_qty = 50; unit_price = 12.50 },
        @{ po_number = $P2; supplier_id = "S02"; supplier_sku_raw = "BX-2001"; invoiced_qty = 80; unit_price = 2.00 },
        @{ po_number = $P3; supplier_id = "S03"; supplier_sku_raw = "CG 3001"; invoiced_qty = 20; unit_price = 35.00 },
        @{ po_number = $P4; supplier_id = "S01"; supplier_sku_raw = "AB-1002"; invoiced_qty = 33; unit_price = 4.00 },
        @{ po_number = $P5; supplier_id = "S02"; supplier_sku_raw = "ZZ-9999"; invoiced_qty = 60; unit_price = 2.00 }
    )
}

Write-Host "`nDone ($P1 to $P5). Check the four sheet tabs, then run workflow 2 (manual trigger)." -ForegroundColor Cyan

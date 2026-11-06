# End-to-end test data: four fresh POs (2001-2004) sent through the ingest webhook.
# Uses supplier codes already in SKU_Map (S01 AB..., S02 BX..., S03 CG...).
#
# Expected after running workflow 2:
#   PO-2001  matched                      -> WH-1001 on_hand +50, status processed
#   PO-2002  under_shipment               -> claim 40
#   PO-2003  damage, over_billing         -> claim 70
#   PO-2004  over_billing                 -> claim 12
#   (3 discrepancies = 3 approval emails)
#
# Mode "test": uses /webhook-test/ and pauses before each call. In n8n click
#              "Listen for test event" on the ingest Webhook node first (ONE call per click).
# Mode "prod": uses /webhook/ and sends everything at once. Ingest workflow must be Active.

$Mode = "prod"   # "test" or "prod"
$Base = "http://localhost:5678"
$Path = if ($Mode -eq "prod") { "webhook" } else { "webhook-test" }
$Uri  = "$Base/$Path/warehouse-ingest"

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
        Write-Host "[$label] FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Send-Batch "POs" @{
    doc_type = "PO"
    rows = @(
        @{ po_number = "PO-2001"; supplier_id = "S01"; internal_sku = "WH-1001"; description = "Widget, standard"; ordered_qty = 50;  unit_price = 12.50 },
        @{ po_number = "PO-2002"; supplier_id = "S02"; internal_sku = "WH-2001"; description = "USB-C cable 1m";   ordered_qty = 100; unit_price = 2.00 },
        @{ po_number = "PO-2003"; supplier_id = "S03"; internal_sku = "WH-3001"; description = "Pressure sensor"; ordered_qty = 20;  unit_price = 35.00 },
        @{ po_number = "PO-2004"; supplier_id = "S01"; internal_sku = "WH-1002"; description = "Mounting bracket"; ordered_qty = 30; unit_price = 4.00 }
    )
}

Send-Batch "DELIVERIES" @{
    doc_type = "DELIVERY"
    rows = @(
        @{ po_number = "PO-2001"; supplier_id = "S01"; supplier_sku_raw = "AB-1001"; delivered_qty = 50 },
        @{ po_number = "PO-2002"; supplier_id = "S02"; supplier_sku_raw = "BX-2001"; delivered_qty = 80 },
        @{ po_number = "PO-2003"; supplier_id = "S03"; supplier_sku_raw = "CG3001";  delivered_qty = 20 },
        @{ po_number = "PO-2004"; supplier_id = "S01"; supplier_sku_raw = "AB 1002"; delivered_qty = 30 }
    )
}

Send-Batch "SCANS" @{
    doc_type = "SCAN"
    rows = @(
        @{ po_number = "PO-2001"; scanned_sku_raw = "ab1001";  good_qty = 50; damaged_qty = 0; scanned_by = "j.okafor" },
        @{ po_number = "PO-2002"; scanned_sku_raw = "BX2001";  good_qty = 80; damaged_qty = 0; scanned_by = "j.okafor" },
        @{ po_number = "PO-2003"; scanned_sku_raw = "CG-3001"; good_qty = 18; damaged_qty = 2; scanned_by = "a.musa" },
        @{ po_number = "PO-2004"; scanned_sku_raw = "AB1002";  good_qty = 30; damaged_qty = 0; scanned_by = "a.musa" }
    )
}

Send-Batch "INVOICES" @{
    doc_type = "INVOICE"
    rows = @(
        @{ po_number = "PO-2001"; supplier_id = "S01"; supplier_sku_raw = "AB-1001"; invoiced_qty = 50; unit_price = 12.50 },
        @{ po_number = "PO-2002"; supplier_id = "S02"; supplier_sku_raw = "BX-2001"; invoiced_qty = 80; unit_price = 2.00 },
        @{ po_number = "PO-2003"; supplier_id = "S03"; supplier_sku_raw = "CG 3001"; invoiced_qty = 20; unit_price = 35.00 },
        @{ po_number = "PO-2004"; supplier_id = "S01"; supplier_sku_raw = "AB-1002"; invoiced_qty = 33; unit_price = 4.00 }
    )
}

Write-Host "`nDone. Now run workflow 2 (manual trigger) and check your email." -ForegroundColor Cyan

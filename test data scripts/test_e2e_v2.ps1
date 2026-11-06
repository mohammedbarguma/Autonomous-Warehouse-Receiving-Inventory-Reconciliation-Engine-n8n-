# test_e2e_v2.ps1 - second end-to-end data set (8 POs, 3 suppliers, 5 internal SKUs)
#
# BEFORE RUNNING: SKU_Map and Inventory must contain the rows in sku_map_and_inventory_v2.txt
#
# Expected after workflow 2 (with $Run = 32):
#   PO-NG-3101  matched            INV-RICE-50KG  on_hand 15 -> 55
#   PO-NG-3102  matched            INV-OIL-5L     on_hand 0 -> 120
#   PO-NG-3103  under_shipment     claim 270000
#   PO-NG-3104  damage,over_billing claim 14400
#   PO-NG-3105  over_billing       claim 7000   <- REJECT this one (tests escalation)
#   PO-NG-3106  sku_mismatch       claim 0      (sugar code delivered against a rice PO)
#   PO-NG-3107  unmapped_sku       claim 0      (supplier code EN-9999-Z not in SKU_Map)
#   PO-NG-3108  no invoice yet     stays pending, no email
#   => 5 approval emails, 1 escalation email
#
# Mode "prod" needs workflow 1 published. Mode "test" pauses before each call
# (click "Listen for test event" on the Webhook node first).

$Run  = "31"     # change for every new run (31 -> 32 -> 33) so PO numbers never repeat
$Mode = "prod"
$Base = "http://localhost:5678"
$Path = if ($Mode -eq "prod") { "webhook" } else { "webhook-test" }
$Uri  = "$Base/$Path/warehouse-ingest"

function Send-Batch($label, $payload) {
    if ($Mode -eq "test") { Read-Host "[$label] Click 'Listen for test event' in n8n, then press Enter" }
    $body = ($payload | ConvertTo-Json -Depth 5) -replace "PO-NG-31", "PO-NG-$Run"
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
        @{ po_number = "PO-NG-3101"; supplier_id = "SUP-KANO"; internal_sku = "INV-RICE-50KG"; ordered_qty = 40; unit_price = 45000 },
        @{ po_number = "PO-NG-3102"; supplier_id = "SUP-LAGOS"; internal_sku = "INV-OIL-5L"; ordered_qty = 120; unit_price = 9500 },
        @{ po_number = "PO-NG-3103"; supplier_id = "SUP-ENUGU"; internal_sku = "INV-FLOUR-10KG"; ordered_qty = 80; unit_price = 18000 },
        @{ po_number = "PO-NG-3104"; supplier_id = "SUP-KANO"; internal_sku = "INV-SUGAR-1KG"; ordered_qty = 200; unit_price = 1200 },
        @{ po_number = "PO-NG-3105"; supplier_id = "SUP-LAGOS"; internal_sku = "INV-SOAP-BAR"; ordered_qty = 500; unit_price = 350 },
        @{ po_number = "PO-NG-3106"; supplier_id = "SUP-KANO"; internal_sku = "INV-RICE-50KG"; ordered_qty = 30; unit_price = 45000 },
        @{ po_number = "PO-NG-3107"; supplier_id = "SUP-ENUGU"; internal_sku = "INV-FLOUR-10KG"; ordered_qty = 25; unit_price = 18000 },
        @{ po_number = "PO-NG-3108"; supplier_id = "SUP-LAGOS"; internal_sku = "INV-SOAP-BAR"; ordered_qty = 100; unit_price = 350 }
    )
}

Send-Batch "DELIVERIES" @{
    doc_type = "DELIVERY"
    rows = @(
        @{ po_number = "PO-NG-3101"; supplier_id = "SUP-KANO"; supplier_sku_raw = "KN/7741-B"; delivered_qty = 40 },
        @{ po_number = "PO-NG-3102"; supplier_id = "SUP-LAGOS"; supplier_sku_raw = "lg.5520"; delivered_qty = 120 },
        @{ po_number = "PO-NG-3103"; supplier_id = "SUP-ENUGU"; supplier_sku_raw = "EN 8800 X"; delivered_qty = 65 },
        @{ po_number = "PO-NG-3104"; supplier_id = "SUP-KANO"; supplier_sku_raw = "KN/7742-A"; delivered_qty = 200 },
        @{ po_number = "PO-NG-3105"; supplier_id = "SUP-LAGOS"; supplier_sku_raw = "LG-5531"; delivered_qty = 500 },
        @{ po_number = "PO-NG-3106"; supplier_id = "SUP-KANO"; supplier_sku_raw = "KN/7742-A"; delivered_qty = 30 },
        @{ po_number = "PO-NG-3107"; supplier_id = "SUP-ENUGU"; supplier_sku_raw = "EN-9999-Z"; delivered_qty = 25 },
        @{ po_number = "PO-NG-3108"; supplier_id = "SUP-LAGOS"; supplier_sku_raw = "LG-5531"; delivered_qty = 100 }
    )
}

Send-Batch "SCANS" @{
    doc_type = "SCAN"
    rows = @(
        @{ po_number = "PO-NG-3101"; scanned_sku_raw = "kn7741b"; good_qty = 40; damaged_qty = 0; scanned_by = "b.adamu" },
        @{ po_number = "PO-NG-3102"; scanned_sku_raw = "LG5520"; good_qty = 120; damaged_qty = 0; scanned_by = "b.adamu" },
        @{ po_number = "PO-NG-3103"; scanned_sku_raw = "en8800x"; good_qty = 65; damaged_qty = 0; scanned_by = "c.eze" },
        @{ po_number = "PO-NG-3104"; scanned_sku_raw = "KN7742A"; good_qty = 188; damaged_qty = 12; scanned_by = "c.eze" },
        @{ po_number = "PO-NG-3105"; scanned_sku_raw = "lg5531"; good_qty = 500; damaged_qty = 0; scanned_by = "b.adamu" },
        @{ po_number = "PO-NG-3106"; scanned_sku_raw = "KN-7742-A"; good_qty = 30; damaged_qty = 0; scanned_by = "c.eze" },
        @{ po_number = "PO-NG-3107"; scanned_sku_raw = "EN9999Z"; good_qty = 25; damaged_qty = 0; scanned_by = "c.eze" },
        @{ po_number = "PO-NG-3108"; scanned_sku_raw = "LG5531"; good_qty = 100; damaged_qty = 0; scanned_by = "b.adamu" }
    )
}

Send-Batch "INVOICES" @{
    doc_type = "INVOICE"
    rows = @(
        @{ po_number = "PO-NG-3101"; supplier_id = "SUP-KANO"; supplier_sku_raw = "KN-7741-B"; invoiced_qty = 40; unit_price = 45000 },
        @{ po_number = "PO-NG-3102"; supplier_id = "SUP-LAGOS"; supplier_sku_raw = "LG 5520"; invoiced_qty = 120; unit_price = 9500 },
        @{ po_number = "PO-NG-3103"; supplier_id = "SUP-ENUGU"; supplier_sku_raw = "EN-8800-X"; invoiced_qty = 65; unit_price = 18000 },
        @{ po_number = "PO-NG-3104"; supplier_id = "SUP-KANO"; supplier_sku_raw = "KN 7742 A"; invoiced_qty = 200; unit_price = 1200 },
        @{ po_number = "PO-NG-3105"; supplier_id = "SUP-LAGOS"; supplier_sku_raw = "LG.5531"; invoiced_qty = 520; unit_price = 350 },
        @{ po_number = "PO-NG-3106"; supplier_id = "SUP-KANO"; supplier_sku_raw = "KN/7742-A"; invoiced_qty = 30; unit_price = 45000 },
        @{ po_number = "PO-NG-3107"; supplier_id = "SUP-ENUGU"; supplier_sku_raw = "EN 9999 Z"; invoiced_qty = 25; unit_price = 18000 }
    )
}

Write-Host "`nDone v2 (PO-NG-$($Run)01 to PO-NG-$($Run)08). Check the four sheet tabs, then run workflow 2 (manual trigger)." -ForegroundColor Cyan

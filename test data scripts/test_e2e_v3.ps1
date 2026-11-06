# test_e2e_v3.ps1 - third data set: 8 POs, same suppliers and SKU_Map as v2 (no sheet setup needed)
#
# PO numbers are generated from the current date and time (e.g. PO-ABJ-051630-01),
# so every run is unique automatically. Nothing to edit between runs.
#
# Expected after workflow 2:
#   -01  matched                         INV-RICE-50KG  on_hand +25
#   -02  matched                         INV-SUGAR-1KG  on_hand +150
#   -03  under_shipment                  claim 285000
#   -04  damage                          claim 0        (supplier only invoiced the 290 good units)
#   -05  over_shipment                   claim 0        (48 delivered against 40 ordered)
#   -06  receiving_shortage,over_billing claim 66500    <- REJECT this one (tests escalation)
#   -07  sku_mismatch                    claim 0        (oil code delivered against a soap PO)
#   -08  no scan yet                     stays pending, no email
#   => 2 matched, 5 approval emails, 1 escalation email
#
# Workflow 1 must be published.

$Run  = Get-Date -Format "ddHHmm"
$Base = "http://localhost:5678"
$Uri  = "$Base/webhook/warehouse-ingest"

function Send-Batch($label, $payload) {
    $body = ($payload | ConvertTo-Json -Depth 5) -replace "PO-ABJ-TEST-", "PO-ABJ-$Run-"
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
        @{ po_number = "PO-ABJ-TEST-01"; supplier_id = "SUP-KANO"; internal_sku = "INV-RICE-50KG"; ordered_qty = 25; unit_price = 45000 },
        @{ po_number = "PO-ABJ-TEST-02"; supplier_id = "SUP-KANO"; internal_sku = "INV-SUGAR-1KG"; ordered_qty = 150; unit_price = 1200 },
        @{ po_number = "PO-ABJ-TEST-03"; supplier_id = "SUP-LAGOS"; internal_sku = "INV-OIL-5L"; ordered_qty = 200; unit_price = 9500 },
        @{ po_number = "PO-ABJ-TEST-04"; supplier_id = "SUP-LAGOS"; internal_sku = "INV-SOAP-BAR"; ordered_qty = 300; unit_price = 350 },
        @{ po_number = "PO-ABJ-TEST-05"; supplier_id = "SUP-ENUGU"; internal_sku = "INV-FLOUR-10KG"; ordered_qty = 40; unit_price = 18000 },
        @{ po_number = "PO-ABJ-TEST-06"; supplier_id = "SUP-LAGOS"; internal_sku = "INV-OIL-5L"; ordered_qty = 100; unit_price = 9500 },
        @{ po_number = "PO-ABJ-TEST-07"; supplier_id = "SUP-LAGOS"; internal_sku = "INV-SOAP-BAR"; ordered_qty = 80; unit_price = 350 },
        @{ po_number = "PO-ABJ-TEST-08"; supplier_id = "SUP-ENUGU"; internal_sku = "INV-FLOUR-10KG"; ordered_qty = 60; unit_price = 18000 }
    )
}

Send-Batch "DELIVERIES" @{
    doc_type = "DELIVERY"
    rows = @(
        @{ po_number = "PO-ABJ-TEST-01"; supplier_id = "SUP-KANO"; supplier_sku_raw = "kn 7741 b"; delivered_qty = 25 },
        @{ po_number = "PO-ABJ-TEST-02"; supplier_id = "SUP-KANO"; supplier_sku_raw = "KN_7742_A"; delivered_qty = 150 },
        @{ po_number = "PO-ABJ-TEST-03"; supplier_id = "SUP-LAGOS"; supplier_sku_raw = "LG/5520"; delivered_qty = 170 },
        @{ po_number = "PO-ABJ-TEST-04"; supplier_id = "SUP-LAGOS"; supplier_sku_raw = "lg-5531"; delivered_qty = 300 },
        @{ po_number = "PO-ABJ-TEST-05"; supplier_id = "SUP-ENUGU"; supplier_sku_raw = "EN.8800.X"; delivered_qty = 48 },
        @{ po_number = "PO-ABJ-TEST-06"; supplier_id = "SUP-LAGOS"; supplier_sku_raw = "LG5520"; delivered_qty = 100 },
        @{ po_number = "PO-ABJ-TEST-07"; supplier_id = "SUP-LAGOS"; supplier_sku_raw = "LG-5520"; delivered_qty = 80 },
        @{ po_number = "PO-ABJ-TEST-08"; supplier_id = "SUP-ENUGU"; supplier_sku_raw = "EN8800X"; delivered_qty = 60 }
    )
}

Send-Batch "SCANS" @{
    doc_type = "SCAN"
    rows = @(
        @{ po_number = "PO-ABJ-TEST-01"; scanned_sku_raw = "KN7741B"; good_qty = 25; damaged_qty = 0; scanned_by = "f.bello" },
        @{ po_number = "PO-ABJ-TEST-02"; scanned_sku_raw = "kn7742a"; good_qty = 150; damaged_qty = 0; scanned_by = "f.bello" },
        @{ po_number = "PO-ABJ-TEST-03"; scanned_sku_raw = "LG 5520"; good_qty = 170; damaged_qty = 0; scanned_by = "t.okon" },
        @{ po_number = "PO-ABJ-TEST-04"; scanned_sku_raw = "LG5531"; good_qty = 290; damaged_qty = 10; scanned_by = "t.okon" },
        @{ po_number = "PO-ABJ-TEST-05"; scanned_sku_raw = "en-8800-x"; good_qty = 48; damaged_qty = 0; scanned_by = "f.bello" },
        @{ po_number = "PO-ABJ-TEST-06"; scanned_sku_raw = "lg5520"; good_qty = 93; damaged_qty = 0; scanned_by = "t.okon" },
        @{ po_number = "PO-ABJ-TEST-07"; scanned_sku_raw = "LG5520"; good_qty = 80; damaged_qty = 0; scanned_by = "t.okon" }
    )
}

Send-Batch "INVOICES" @{
    doc_type = "INVOICE"
    rows = @(
        @{ po_number = "PO-ABJ-TEST-01"; supplier_id = "SUP-KANO"; supplier_sku_raw = "KN-7741-B"; invoiced_qty = 25; unit_price = 45000 },
        @{ po_number = "PO-ABJ-TEST-02"; supplier_id = "SUP-KANO"; supplier_sku_raw = "KN 7742 A"; invoiced_qty = 150; unit_price = 1200 },
        @{ po_number = "PO-ABJ-TEST-03"; supplier_id = "SUP-LAGOS"; supplier_sku_raw = "LG-5520"; invoiced_qty = 170; unit_price = 9500 },
        @{ po_number = "PO-ABJ-TEST-04"; supplier_id = "SUP-LAGOS"; supplier_sku_raw = "LG 5531"; invoiced_qty = 290; unit_price = 350 },
        @{ po_number = "PO-ABJ-TEST-05"; supplier_id = "SUP-ENUGU"; supplier_sku_raw = "EN 8800 X"; invoiced_qty = 48; unit_price = 18000 },
        @{ po_number = "PO-ABJ-TEST-06"; supplier_id = "SUP-LAGOS"; supplier_sku_raw = "LG.5520"; invoiced_qty = 100; unit_price = 9500 },
        @{ po_number = "PO-ABJ-TEST-07"; supplier_id = "SUP-LAGOS"; supplier_sku_raw = "LG-5520"; invoiced_qty = 80; unit_price = 350 },
        @{ po_number = "PO-ABJ-TEST-08"; supplier_id = "SUP-ENUGU"; supplier_sku_raw = "EN-8800-X"; invoiced_qty = 60; unit_price = 18000 }
    )
}

Write-Host "`nDone v3 (PO-ABJ-$Run-01 to PO-ABJ-$Run-08). Check the four sheet tabs, then run workflow 2 (manual trigger)." -ForegroundColor Cyan

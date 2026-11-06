# test_e2e_v4.ps1 - fourth data set: 7 POs (one with two lines), same suppliers and SKU_Map as v2/v3
#
# PO numbers come from the current date and time (e.g. PO-LOS-061015-01), so every run is unique.
#
# Expected after workflow 2:
#   -01 line A  matched                          INV-RICE-50KG  on_hand +10   (two-line PO)
#   -01 line B  matched                          INV-SUGAR-1KG  on_hand +50
#   -02         matched                          INV-OIL-5L     on_hand +60
#   -03         receiving_overage                claim 0        (104 counted, 100 on the delivery note)
#   -04         under_shipment,over_billing      claim 90000    (45 delivered, 50 billed)
#   -05         damage,over_billing              claim 135000   <- REJECT this one (tests escalation)
#   -06         unmapped_sku                     claim 0        (supplier code LG-0000 not in SKU_Map)
#   -07         no delivery note yet             stays pending, no email
#   => 3 matched lines, 4 approval emails (one at a time), 1 escalation email
#
# Workflow 1 must be published.

$Run  = Get-Date -Format "ddHHmm"
$Base = "http://localhost:5678"
$Uri  = "$Base/webhook/warehouse-ingest"

function Send-Batch($label, $payload) {
    $body = ($payload | ConvertTo-Json -Depth 5) -replace "PO-LOS-TEST-", "PO-LOS-$Run-"
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
        @{ po_number = "PO-LOS-TEST-01"; supplier_id = "SUP-KANO"; internal_sku = "INV-RICE-50KG"; ordered_qty = 10; unit_price = 45000 },
        @{ po_number = "PO-LOS-TEST-01"; supplier_id = "SUP-KANO"; internal_sku = "INV-SUGAR-1KG"; ordered_qty = 50; unit_price = 1200 },
        @{ po_number = "PO-LOS-TEST-02"; supplier_id = "SUP-LAGOS"; internal_sku = "INV-OIL-5L"; ordered_qty = 60; unit_price = 9500 },
        @{ po_number = "PO-LOS-TEST-03"; supplier_id = "SUP-LAGOS"; internal_sku = "INV-SOAP-BAR"; ordered_qty = 100; unit_price = 350 },
        @{ po_number = "PO-LOS-TEST-04"; supplier_id = "SUP-ENUGU"; internal_sku = "INV-FLOUR-10KG"; ordered_qty = 50; unit_price = 18000 },
        @{ po_number = "PO-LOS-TEST-05"; supplier_id = "SUP-KANO"; internal_sku = "INV-RICE-50KG"; ordered_qty = 20; unit_price = 45000 },
        @{ po_number = "PO-LOS-TEST-06"; supplier_id = "SUP-LAGOS"; internal_sku = "INV-SOAP-BAR"; ordered_qty = 40; unit_price = 350 },
        @{ po_number = "PO-LOS-TEST-07"; supplier_id = "SUP-ENUGU"; internal_sku = "INV-FLOUR-10KG"; ordered_qty = 30; unit_price = 18000 }
    )
}

Send-Batch "DELIVERIES" @{
    doc_type = "DELIVERY"
    rows = @(
        @{ po_number = "PO-LOS-TEST-01"; supplier_id = "SUP-KANO"; supplier_sku_raw = "KN-7741-B"; delivered_qty = 10 },
        @{ po_number = "PO-LOS-TEST-01"; supplier_id = "SUP-KANO"; supplier_sku_raw = "kn/7742/a"; delivered_qty = 50 },
        @{ po_number = "PO-LOS-TEST-02"; supplier_id = "SUP-LAGOS"; supplier_sku_raw = "LG 5520"; delivered_qty = 60 },
        @{ po_number = "PO-LOS-TEST-03"; supplier_id = "SUP-LAGOS"; supplier_sku_raw = "LG.5531"; delivered_qty = 100 },
        @{ po_number = "PO-LOS-TEST-04"; supplier_id = "SUP-ENUGU"; supplier_sku_raw = "en-8800-x"; delivered_qty = 45 },
        @{ po_number = "PO-LOS-TEST-05"; supplier_id = "SUP-KANO"; supplier_sku_raw = "KN 7741 B"; delivered_qty = 20 },
        @{ po_number = "PO-LOS-TEST-06"; supplier_id = "SUP-LAGOS"; supplier_sku_raw = "LG-0000"; delivered_qty = 40 }
    )
}

Send-Batch "SCANS" @{
    doc_type = "SCAN"
    rows = @(
        @{ po_number = "PO-LOS-TEST-01"; scanned_sku_raw = "KN7741B"; good_qty = 10; damaged_qty = 0; scanned_by = "h.yusuf" },
        @{ po_number = "PO-LOS-TEST-01"; scanned_sku_raw = "KN-7742-A"; good_qty = 50; damaged_qty = 0; scanned_by = "h.yusuf" },
        @{ po_number = "PO-LOS-TEST-02"; scanned_sku_raw = "lg5520"; good_qty = 60; damaged_qty = 0; scanned_by = "h.yusuf" },
        @{ po_number = "PO-LOS-TEST-03"; scanned_sku_raw = "LG5531"; good_qty = 104; damaged_qty = 0; scanned_by = "r.ade" },
        @{ po_number = "PO-LOS-TEST-04"; scanned_sku_raw = "EN8800X"; good_qty = 45; damaged_qty = 0; scanned_by = "r.ade" },
        @{ po_number = "PO-LOS-TEST-05"; scanned_sku_raw = "kn7741b"; good_qty = 17; damaged_qty = 3; scanned_by = "r.ade" },
        @{ po_number = "PO-LOS-TEST-06"; scanned_sku_raw = "LG0000"; good_qty = 40; damaged_qty = 0; scanned_by = "h.yusuf" },
        @{ po_number = "PO-LOS-TEST-07"; scanned_sku_raw = "EN8800X"; good_qty = 30; damaged_qty = 0; scanned_by = "r.ade" }
    )
}

Send-Batch "INVOICES" @{
    doc_type = "INVOICE"
    rows = @(
        @{ po_number = "PO-LOS-TEST-01"; supplier_id = "SUP-KANO"; supplier_sku_raw = "KN7741B"; invoiced_qty = 10; unit_price = 45000 },
        @{ po_number = "PO-LOS-TEST-01"; supplier_id = "SUP-KANO"; supplier_sku_raw = "KN 7742 A"; invoiced_qty = 50; unit_price = 1200 },
        @{ po_number = "PO-LOS-TEST-02"; supplier_id = "SUP-LAGOS"; supplier_sku_raw = "LG-5520"; invoiced_qty = 60; unit_price = 9500 },
        @{ po_number = "PO-LOS-TEST-03"; supplier_id = "SUP-LAGOS"; supplier_sku_raw = "LG 5531"; invoiced_qty = 100; unit_price = 350 },
        @{ po_number = "PO-LOS-TEST-04"; supplier_id = "SUP-ENUGU"; supplier_sku_raw = "EN 8800 X"; invoiced_qty = 50; unit_price = 18000 },
        @{ po_number = "PO-LOS-TEST-05"; supplier_id = "SUP-KANO"; supplier_sku_raw = "KN-7741-B"; invoiced_qty = 20; unit_price = 45000 },
        @{ po_number = "PO-LOS-TEST-06"; supplier_id = "SUP-LAGOS"; supplier_sku_raw = "LG 0000"; invoiced_qty = 40; unit_price = 350 },
        @{ po_number = "PO-LOS-TEST-07"; supplier_id = "SUP-ENUGU"; supplier_sku_raw = "EN-8800-X"; invoiced_qty = 30; unit_price = 18000 }
    )
}

Write-Host "`nDone v4 (PO-LOS-$Run-01 to PO-LOS-$Run-07). Check the four sheet tabs, then run workflow 2 (manual trigger)." -ForegroundColor Cyan

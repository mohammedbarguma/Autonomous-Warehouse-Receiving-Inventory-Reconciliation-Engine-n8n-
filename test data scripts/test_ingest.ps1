# Test the ingest webhook for all four document types.
# Scenario: PO-007 (SUP-001, LAP-001). Ordered 100, delivered 90, scanned 85 good + 5 damaged, invoiced 100.
#
# Mode "test": uses /webhook-test/ and pauses before each call. In n8n, click
#              "Listen for test event" on the Webhook node first (it accepts ONE call per click).
# Mode "prod": uses /webhook/ and sends everything at once. The workflow must be Active (toggle on).

$Mode = "test"   # change to "prod" once the workflow is Active
$Base = "http://localhost:5678"
$Path = if ($Mode -eq "prod") { "webhook" } else { "webhook-test" }
$Uri  = "$Base/$Path/warehouse-ingest"

function Send-Doc($label, $payload) {
    if ($Mode -eq "test") {
        Read-Host "[$label] Click 'Listen for test event' in n8n, then press Enter"
    }
    $body = $payload | ConvertTo-Json
    try {
        $result = Invoke-RestMethod -Uri $Uri -Method POST -ContentType "application/json" -Body $body
        Write-Host "[$label] sent OK" -ForegroundColor Green
        $result | ConvertTo-Json -Depth 5
    }
    catch {
        Write-Host "[$label] FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 1. Purchase order  -> Purchase_Orders
Send-Doc "PO" @{
    doc_type     = "PO"
    po_number    = "PO-007"
    supplier_id  = "SUP-001"
    internal_sku = "WH-4001"
    description  = "Laptop, 14 inch"
    ordered_qty  = 100
    unit_price   = 650
}

# 2. Delivery note   -> Deliveries
Send-Doc "DELIVERY" @{
    doc_type          = "DELIVERY"
    po_number         = "PO-007"
    supplier_id       = "SUP-001"
    supplier_sku_raw  = "LAP-001"
    delivered_qty     = 90
}

# 3. Warehouse scan  -> Warehouse_Scans
Send-Doc "SCAN" @{
    doc_type         = "SCAN"
    po_number        = "PO-007"
    scanned_sku_raw  = "lap001"
    good_qty         = 85
    damaged_qty      = 5
    scanned_by       = "j.okafor"
}

# 4. Invoice         -> Invoices
Send-Doc "INVOICE" @{
    doc_type          = "INVOICE"
    po_number         = "PO-007"
    supplier_id       = "SUP-001"
    supplier_sku_raw  = "LAP 001"
    invoiced_qty      = 100
    unit_price        = 650
}

# 5. Negative test: should FAIL validation (bad doc_type), nothing is written to any sheet
Send-Doc "BAD DOC_TYPE (expected to fail)" @{
    doc_type  = "RECEIPT"
    po_number = "PO-007"
}

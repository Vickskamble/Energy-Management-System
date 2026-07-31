# ============================================================
# Seed 30 Days of Dummy Data for PowerEMS Testing
# ============================================================
$ErrorActionPreference = "Stop"

$SUPABASE_URL = "https://onfovsadlqeebguuswzg.supabase.co"
$ANON_KEY = "sb_publishable_REDACTED"

# ---------- Constants (match app_constants.dart) ----------
$MULTIPLYING_FACTOR = 5.0
$TARIFF_PER_UNIT = 8.68
$CONTRACT_DEMAND = 400.00
$DEMAND_CHARGE_PER_KVA = 320.00
$FAC_RATE_PER_UNIT = 0.85
$WHEELING_CHARGE_PER_UNIT = 0.65
$ELECTRICITY_DUTY_PCT = 5.0
$TAX_PCT = 0.5
$PF_REBATE_PCT = 1.0
$PF_SURCHARGE_PCT = 5.0
$PF_REBATE_THRESHOLD = 0.95
$PF_SURCHARGE_THRESHOLD = 0.90

# ---------- Helpers ----------
function Round2($val) { [Math]::Round($val, 2) }
function Round3($val) { [Math]::Round($val, 3) }
function Round4($val) { [Math]::Round($val, 4) }

# ---------- Step 1: Create test user ----------
Write-Host "=== Creating test user ==="
$testEmail = "demo@example.com"
$testPass = "REDACTED_PASSWORD"

$body = @{ email = $testEmail; password = $testPass } | ConvertTo-Json
try {
    $signup = Invoke-RestMethod -Uri "$SUPABASE_URL/auth/v1/signup" -Method Post `
        -Headers @{ "apikey" = $ANON_KEY; "Content-Type" = "application/json" } `
        -Body $body -ErrorAction Stop
    Write-Host "  User created: $testEmail"
} catch {
    Write-Host "  User may already exist (continue with sign-in)"
}

# ---------- Step 2: Sign in to get session ----------
Write-Host "=== Signing in ==="
$body = @{ email = $testEmail; password = $testPass } | ConvertTo-Json
$login = Invoke-RestMethod -Uri "$SUPABASE_URL/auth/v1/token?grant_type=password" -Method Post `
    -Headers @{ "apikey" = $ANON_KEY; "Content-Type" = "application/json" } `
    -Body $body -ErrorAction Stop

$userId = $login.user.id
$accessToken = $login.access_token
Write-Host "  User ID: $userId"

$headers = @{
    "apikey" = $ANON_KEY
    "Authorization" = "Bearer $accessToken"
    "Content-Type" = "application/json"
    "Prefer" = "return=minimal"
}

# ---------- Step 3: Generate & insert 30 days of data ----------
Write-Host "=== Generating 30 days of data ==="

$meters = @(
    @{ name = "Main Meter - LT"; kwhBase = 950; kwhRange = 300; mdBase = 75; mdRange = 25 },
    @{ name = "Feeder 1 - HT"; kwhBase = 1300; kwhRange = 400; mdBase = 100; mdRange = 30 },
    @{ name = "Feeder 2 - LT"; kwhBase = 600; kwhRange = 200; mdBase = 45; mdRange = 15 }
)

$startDate = (Get-Date).AddDays(-30).Date
$total = 0

foreach ($meter in $meters) {
    Write-Host "  Meter: $($meter.name)"
    $records = @()

    for ($day = 0; $day -lt 30; $day++) {
        $date = $startDate.AddDays($day)
        $isWeekend = ($date.DayOfWeek -eq [DayOfWeek]::Saturday) -or ($date.DayOfWeek -eq [DayOfWeek]::Sunday)

        # Vary kWh by day
        $dayFactor = 1.0 - 0.4 * $isWeekend.GetHashCode()  # 0.6 on weekends
        $randomFactor = 0.85 + (Get-Random -Min 0 -Max 30) / 100  # 0.85 - 1.15
        $kwh = Round2($meter.kwhBase * $dayFactor * $randomFactor)

        # Some days have low PF to trigger penalty
        $pfLow = ($day -ge 10 -and $day -le 12) -or ($day -eq 21)
        $pfRand = if ($pfLow) { 0.80 + (Get-Random -Min 0 -Max 10) / 100 } else { 0.88 + (Get-Random -Min 0 -Max 12) / 100 }
        $powerFactor = Round3([Math]::Min(1.0, $pfRand))

        $kvah = if ($powerFactor -gt 0) { Round2($kwh / $powerFactor) } else { Round2($kwh / 0.9) }

        # Reactive energy
        $rkvarhLag = Round2($kvah * (0.05 + (Get-Random -Min 0 -Max 15) / 100))
        $rkvarhLead = Round2($kvah * (0.02 + (Get-Random -Min 0 -Max 8) / 100))

        # MD Recorded
        $mdRand = 0.85 + (Get-Random -Min 0 -Max 25) / 100
        $mdRecorded = Round2($meter.mdBase * $mdRand)

        # ---------- Billing calculations (match CalculationEngine) ----------
        $totalUnits = $kwh * $MULTIPLYING_FACTOR
        $billingDemand = [Math]::Max($mdRecorded, $CONTRACT_DEMAND * 0.75)
        $billingDemand = Round2($billingDemand)

        $energyCharges = Round2($totalUnits * $TARIFF_PER_UNIT)
        $demandCharges = Round2($billingDemand * $DEMAND_CHARGE_PER_KVA)
        $facCharges = Round2($totalUnits * $FAC_RATE_PER_UNIT)
        $wheelingCharges = Round2($totalUnits * $WHEELING_CHARGE_PER_UNIT)

        $subtotal = $energyCharges + $demandCharges + $facCharges + $wheelingCharges
        $electricityDuty = Round2($subtotal * $ELECTRICITY_DUTY_PCT / 100)
        $taxes = Round2(($subtotal + $electricityDuty) * $TAX_PCT / 100)

        $pfRebate = if ($powerFactor -ge $PF_REBATE_THRESHOLD) {
            Round2(($energyCharges + $demandCharges) * $PF_REBATE_PCT / 100)
        } else { 0 }

        $pfSurcharge = if ($powerFactor -lt $PF_SURCHARGE_THRESHOLD) {
            Round2(($energyCharges + $demandCharges) * $PF_SURCHARGE_PCT / 100)
        } else { 0 }

        $subsidy = 0
        $netBill = Round2($energyCharges + $demandCharges + $facCharges + $wheelingCharges + $electricityDuty + $taxes + $pfSurcharge - $pfRebate - $subsidy)

        $avgUnitCost = if ($totalUnits -gt 0) { Round2($netBill / $totalUnits) } else { 0 }
        $estimatedBill = Round2($totalUnits * $TARIFF_PER_UNIT)
        $loadFactor = Round4($kwh / ([Math]::Max($mdRecorded, 1) * 24))

        $record = @{
            "id" = [Guid]::NewGuid().ToString()
            "meter_name" = $meter.name
            "kwh" = $kwh
            "kvah" = $kvah
            "rkvarh_lag" = $rkvarhLag
            "rkvarh_lead" = $rkvarhLead
            "power_factor" = $powerFactor
            "md_recorded" = $mdRecorded
            "contract_demand" = $CONTRACT_DEMAND
            "estimated_bill" = $estimatedBill
            "logged_at" = $date.ToString("yyyy-MM-ddT00:00:00Z")
            "user_id" = $userId
            "energy_charges" = $energyCharges
            "demand_charges" = $demandCharges
            "fac_charges" = $facCharges
            "wheeling_charges" = $wheelingCharges
            "electricity_duty" = $electricityDuty
            "taxes" = $taxes
            "pf_rebate" = $pfRebate
            "pf_surcharge" = $pfSurcharge
            "subsidy" = $subsidy
            "net_bill" = $netBill
            "billing_demand" = $billingDemand
            "load_factor" = $loadFactor
            "avg_unit_cost" = $avgUnitCost
        }
        $records += $record
    }

    # Insert in batches of 10
    for ($i = 0; $i -lt $records.Count; $i += 10) {
        $batch = $records[$i..([Math]::Min($i + 9, $records.Count - 1))]
        $jsonBatch = $batch | ConvertTo-Json -Depth 5

        try {
            Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/energy_logs" -Method Post `
                -Headers $headers -Body $jsonBatch -ErrorAction Stop | Out-Null
            $total += $batch.Count
            Write-Host "    Inserted batch $([Math]::Floor($i/10)+1)/$([Math]::Ceiling($records.Count/10)) ($($batch.Count) records)"
        } catch {
            Write-Host "    ERROR inserting batch $([Math]::Floor($i/10)+1): $_"
        }
    }
}

Write-Host ""
Write-Host "============================================"
Write-Host "  Done! $total records inserted."
Write-Host "  Email: $testEmail"
Write-Host "  Password: $testPass"
Write-Host "============================================"

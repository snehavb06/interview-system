# scripts/test.ps1
param(
    [Parameter(Mandatory=$false)]
    [string]$FunctionAppName = "interview-system-func-india-dev",
    
    [Parameter(Mandatory=$false)]
    [string]$MasterKey = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "centralindia"
)

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Testing Interview System - India Region" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Function App: $FunctionAppName" -ForegroundColor Yellow
Write-Host "Region: $Region (India)" -ForegroundColor Yellow
Write-Host ""

$baseUrl = "https://$FunctionAppName.azurewebsites.net/api"

# Get master key if not provided
if ([string]::IsNullOrEmpty($MasterKey)) {
    try {
        $MasterKey = az functionapp keys list --name $FunctionAppName --resource-group "interview-system-dev-rg-india" --query "masterKey" --output tsv
        Write-Host "✅ Retrieved master key from Azure" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️ Could not retrieve master key. Using empty key (functions with anonymous auth only)" -ForegroundColor Yellow
        $MasterKey = ""
    }
}

$codeParam = if ($MasterKey) { "?code=$MasterKey" } else { "" }

# Test 1: StartInterview
Write-Host "`n1. Testing StartInterview..." -ForegroundColor Magenta
$startBody = @{
    candidateEmail = "test.india@example.com"
    interviewerEmail = "interviewer.india@example.com"
    scheduledTime = (Get-Date).AddHours(1).ToString("yyyy-MM-ddTHH:mm:ssZ")
    idempotencyKey = [Guid]::NewGuid().ToString()
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$baseUrl/StartInterview$codeParam" `
        -Method Post `
        -ContentType "application/json" `
        -Body $startBody `
        -ErrorAction Stop
    
    Write-Host "✅ StartInterview succeeded!" -ForegroundColor Green
    Write-Host "Instance ID: $($response.instanceId)" -ForegroundColor Cyan
    $instanceId = $response.instanceId
}
catch {
    Write-Host "❌ StartInterview failed: $($_.Exception.Message)" -ForegroundColor Red
    $instanceId = $null
}

# Test 2: negotiate
Write-Host "`n2. Testing SignalR negotiate..." -ForegroundColor Magenta
$negotiateBody = @{
    userId = "interviewer1"
    interviewId = "test-interview-123"
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$baseUrl/negotiate$codeParam" `
        -Method Post `
        -ContentType "application/json" `
        -Body $negotiateBody `
        -ErrorAction Stop
    
    Write-Host "✅ negotiate succeeded!" -ForegroundColor Green
    Write-Host "SignalR URL: $($response.url)" -ForegroundColor Cyan
}
catch {
    Write-Host "❌ negotiate failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Check Function List
Write-Host "`n3. Listing deployed functions..." -ForegroundColor Magenta
try {
    $functions = az functionapp function list --name $FunctionAppName --resource-group "interview-system-dev-rg-india" --query "[].name" -o table
    Write-Host "✅ Functions deployed:" -ForegroundColor Green
    $functions
}
catch {
    Write-Host "❌ Could not list functions: $_" -ForegroundColor Red
}

# Test 4: Check Application Insights (if available)
Write-Host "`n4. Checking Application Insights..." -ForegroundColor Magenta
try {
    $aiName = "interview-system-insights-india-dev"
    $aiQuery = "traces | where timestamp > ago(15m) | count"
    $result = az monitor app-insights query --app $aiName --analytics-query $aiQuery --resource-group "interview-system-dev-rg-india" -o tsv
    
    if ($result -and $result -gt 0) {
        Write-Host "✅ Application Insights receiving data: $result logs in last 15 minutes" -ForegroundColor Green
    } else {
        Write-Host "⚠️ No recent logs in Application Insights" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "⚠️ Could not query Application Insights: $_" -ForegroundColor Yellow
}

Write-Host "`n=====================================" -ForegroundColor Cyan
if ($instanceId) {
    Write-Host "✅ Testing complete! Interview started with ID: $instanceId" -ForegroundColor Green
    Write-Host "To track progress: https://$FunctionAppName.azurewebsites.net/api/runtime/webhooks/durabletask/instances/$instanceId"
}
else {
    Write-Host "⚠️ Testing completed with some failures" -ForegroundColor Yellow
}
Write-Host "=====================================" -ForegroundColor Cyan
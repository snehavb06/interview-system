# scripts/deploy.ps1
param(
    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "centralindia",
    
    [Parameter(Mandatory=$false)]
    [switch]$DeployInfrastructure,
    
    [Parameter(Mandatory=$false)]
    [switch]$DeployFunction,
    
    [Parameter(Mandatory=$false)]
    [switch]$FullDeploy
)

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Interview System Deployment - India Region" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Region: $Region (India)" -ForegroundColor Yellow
Write-Host ""

# Set variables
$ProjectRoot = "C:\Users\hp\Desktop\my files\test6\InterviewWorkflow"
$TerraformDir = Join-Path $ProjectRoot "terraform"
$FunctionDir = Join-Path $ProjectRoot "src\InterviewWorkflow"

# Function to check if Azure CLI is logged in
function Test-AzureLogin {
    try {
        $account = az account show | ConvertFrom-Json
        Write-Host "✅ Azure CLI logged in as: $($account.user.name)" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "❌ Azure CLI not logged in. Please run 'az login' first." -ForegroundColor Red
        return $false
    }
}

# Function to deploy infrastructure with Terraform
function Deploy-Infrastructure {
    Write-Host "`n📦 Deploying Infrastructure with Terraform..." -ForegroundColor Magenta
    
    if (-not (Test-Path $TerraformDir)) {
        Write-Host "❌ Terraform directory not found: $TerraformDir" -ForegroundColor Red
        return $false
    }
    
    Push-Location $TerraformDir
    
    try {
        # Initialize Terraform
        Write-Host "Initializing Terraform..." -ForegroundColor Yellow
        terraform init
        
        # Create terraform.tfvars if not exists
        if (-not (Test-Path "terraform.tfvars")) {
            Write-Host "Creating terraform.tfvars from example..." -ForegroundColor Yellow
            Copy-Item "terraform.tfvars.example" "terraform.tfvars"
        }
        
        # Plan
        Write-Host "Creating Terraform plan..." -ForegroundColor Yellow
        terraform plan -out=tfplan
        
        # Apply
        Write-Host "Applying Terraform plan..." -ForegroundColor Yellow
        terraform apply -auto-approve tfplan
        
        # Get outputs
        $functionName = terraform output -raw function_app_name
        $apimUrl = terraform output -raw apim_gateway_url
        $functionUrl = terraform output -raw function_app_url
        
        Write-Host "✅ Infrastructure deployed successfully!" -ForegroundColor Green
        Write-Host "Function App: $functionUrl" -ForegroundColor Green
        Write-Host "APIM Gateway: $apimUrl" -ForegroundColor Green
        
        return $true
    }
    catch {
        Write-Host "❌ Infrastructure deployment failed: $_" -ForegroundColor Red
        return $false
    }
    finally {
        Pop-Location
    }
}

# Function to deploy function app
function Deploy-FunctionApp {
    Write-Host "`n📦 Deploying Function App..." -ForegroundColor Magenta
    
    if (-not (Test-Path $FunctionDir)) {
        Write-Host "❌ Function App directory not found: $FunctionDir" -ForegroundColor Red
        return $false
    }
    
    Push-Location $FunctionDir
    
    try {
        # Build
        Write-Host "Building function app..." -ForegroundColor Yellow
        dotnet build -c Release
        
        # Publish
        Write-Host "Publishing function app..." -ForegroundColor Yellow
        dotnet publish -c Release -o ./publish
        
        # Get function app name from Terraform outputs
        $functionAppName = if (Test-Path "../terraform") {
            Push-Location "../terraform"
            $name = terraform output -raw function_app_name 2>$null
            Pop-Location
            $name
        } else {
            "interview-system-func-india-$Environment"
        }
        
        if ([string]::IsNullOrEmpty($functionAppName)) {
            $functionAppName = "interview-system-func-india-$Environment"
        }
        
        # Deploy
        Write-Host "Deploying to Azure Function App: $functionAppName..." -ForegroundColor Yellow
        func azure functionapp publish $functionAppName --force
        
        Write-Host "✅ Function App deployed successfully!" -ForegroundColor Green
        
        return $true
    }
    catch {
        Write-Host "❌ Function App deployment failed: $_" -ForegroundColor Red
        return $false
    }
    finally {
        Pop-Location
    }
}

# Main execution
if (-not (Test-AzureLogin)) {
    exit 1
}

$success = $true

if ($FullDeploy -or $DeployInfrastructure) {
    $infraSuccess = Deploy-Infrastructure
    $success = $success -and $infraSuccess
}

if ($FullDeploy -or $DeployFunction) {
    $funcSuccess = Deploy-FunctionApp
    $success = $success -and $funcSuccess
}

if (-not ($DeployInfrastructure -or $DeployFunction -or $FullDeploy)) {
    Write-Host "`n⚠️ No deployment option selected. Use -FullDeploy, -DeployInfrastructure, or -DeployFunction" -ForegroundColor Yellow
}

if ($success) {
    Write-Host "`n✅ Deployment completed successfully!" -ForegroundColor Green
    Write-Host "Your Interview System is now running in India region ($Region)" -ForegroundColor Green
}
else {
    Write-Host "`n❌ Deployment failed. Please check the errors above." -ForegroundColor Red
    exit 1
}
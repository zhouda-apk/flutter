Write-Host "Starting OCR LLM backend..." -ForegroundColor Cyan

if (-not (Test-Path "venv")) {
    Write-Host "Creating Python virtual environment..." -ForegroundColor Yellow
    python -m venv venv
}

Write-Host "Activating virtual environment..." -ForegroundColor Yellow
& ".\venv\Scripts\Activate.ps1"

Write-Host "Installing dependencies..." -ForegroundColor Yellow
pip install -r requirements.txt

if (-not (Test-Path ".env")) {
    Write-Host ".env not found. Copy .env.example to .env and set your API key." -ForegroundColor Red
    Write-Host "Example: copy .env.example .env" -ForegroundColor Yellow
    exit 1
}

$envContent = Get-Content ".env" -Raw
$provider = "gemini"
if ($envContent -match "(?m)^LLM_PROVIDER\s*=\s*(.+)$") {
    $provider = $Matches[1].Trim().ToLower()
}

if ($provider -eq "google") {
    $provider = "gemini"
}

if ($provider -eq "gemini") {
    $googleKey = $env:GOOGLE_API_KEY
    if ($envContent -match "(?m)^GOOGLE_API_KEY\s*=\s*(.+)$") {
        $googleKey = $Matches[1].Trim()
    }
    if (-not $googleKey -or $googleKey -like "your-*") {
        Write-Host "Set GOOGLE_API_KEY in .env before starting with LLM_PROVIDER=gemini." -ForegroundColor Red
        exit 1
    }
} elseif ($provider -eq "openai") {
    $openAiKey = $env:OPENAI_API_KEY
    if ($envContent -match "(?m)^OPENAI_API_KEY\s*=\s*(.+)$") {
        $openAiKey = $Matches[1].Trim()
    }
    if (-not $openAiKey -or $openAiKey -like "sk-xxx*") {
        Write-Host "Set OPENAI_API_KEY in .env before starting with LLM_PROVIDER=openai." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "LLM_PROVIDER must be gemini, google, or openai." -ForegroundColor Red
    exit 1
}

$wifiIp = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
        $_.IPAddress -notlike "127.*" -and
        $_.IPAddress -notlike "169.254.*" -and
        $_.InterfaceAlias -match "Wi-Fi|Ethernet"
    } |
    Select-Object -First 1 -ExpandProperty IPAddress)

Write-Host "FastAPI local URL: http://127.0.0.1:5000" -ForegroundColor Cyan
if ($wifiIp) {
    Write-Host "FastAPI phone URL: http://$wifiIp`:5000" -ForegroundColor Cyan
}
Write-Host "Docs URL: http://127.0.0.1:5000/docs" -ForegroundColor Cyan

python main.py

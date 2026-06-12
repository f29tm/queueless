# Verifies the Gemini API key in lib/config/api_keys.dart without launching the app.
#
# Run from the repo root:   powershell -File tool\check_gemini_key.ps1
#
# Checks both Gemini-dependent features:
#   1. Chatbot        - plain generateContent
#   2. NLP extraction - structured-JSON request with the addendum schema
#
# When the key's project is out of quota (HTTP 429), create a fresh key on a
# free-tier project at https://aistudio.google.com/apikey and paste it into
# lib/config/api_keys.dart, then re-run this script.

$ErrorActionPreference = 'Stop'
$keysFile = Join-Path $PSScriptRoot '..\lib\config\api_keys.dart'

if (-not (Test-Path $keysFile)) {
    Write-Host 'FAIL  lib/config/api_keys.dart not found (it is gitignored; create it with: class ApiKeys { static const String gemini = <key>; })' -ForegroundColor Red
    exit 1
}

# Matches both classic (AIza...) and new-format (AQ. ...) Gemini keys.
$match = Select-String -Path $keysFile -Pattern "gemini\s*=\s*'([^']+)'"
if (-not $match) {
    Write-Host 'FAIL  No Gemini key found in lib/config/api_keys.dart' -ForegroundColor Red
    exit 1
}
$key = $match.Matches[0].Groups[1].Value
$model = 'gemini-2.5-flash'
$base = "https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=$key"

function Invoke-Gemini($label, $body) {
    try {
        $r = Invoke-WebRequest -Uri $base -Method Post -ContentType 'application/json' -Body $body -UseBasicParsing -TimeoutSec 60
        Write-Host "PASS  $label" -ForegroundColor Green
        return $r.Content
    } catch {
        $code = $_.Exception.Response.StatusCode.value__
        $detail = ''
        try {
            $reader = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())
            $detail = ($reader.ReadToEnd() | ConvertFrom-Json).error.message
        } catch {}
        Write-Host "FAIL  $label - HTTP $code" -ForegroundColor Red
        if ($detail) { Write-Host "      $detail" -ForegroundColor Yellow }
        if ($code -eq 429) {
            Write-Host '      Quota exhausted: top up at https://ai.studio/projects or create a' -ForegroundColor Yellow
            Write-Host '      free-tier key at https://aistudio.google.com/apikey and update lib/config/api_keys.dart' -ForegroundColor Yellow
        }
        return $null
    }
}

Write-Host "Checking key ending ...$($key.Substring($key.Length - 6)) against $model"
Write-Host ''

# 1 - chatbot path
$chatBody = '{"contents":[{"role":"user","parts":[{"text":"Reply with the single word OK"}]}],"generationConfig":{"maxOutputTokens":50}}'
$null = Invoke-Gemini 'Chatbot (plain generateContent)' $chatBody

# 2 - NLP extraction path (exact schema used by SymptomExtractionService)
$extractBody = @'
{
  "system_instruction": {"parts": [{"text": "You convert a patient symptom description into structured intake fields for a triage FORM. Only fill fields the patient clearly stated; never output urgency or severity."}]},
  "contents": [{"role": "user", "parts": [{"text": "I have extreme chest pain, my pain is 8 out of 10, my son is driving me in"}]}],
  "generationConfig": {
    "temperature": 0,
    "responseMimeType": "application/json",
    "responseSchema": {
      "type": "OBJECT",
      "properties": {
        "chief_complaint": {"type": "STRING", "nullable": true},
        "symptoms": {"type": "ARRAY", "items": {"type": "STRING"}},
        "nrs_pain": {"type": "NUMBER", "nullable": true},
        "injury": {"type": "BOOLEAN", "nullable": true},
        "arrival_mode": {"type": "STRING", "enum": ["walk", "ambulance", "car", "transit", "referred"], "nullable": true},
        "mental_status": {"type": "STRING", "enum": ["alert", "verbal", "pain", "unresponsive"]}
      }
    }
  }
}
'@
$content = Invoke-Gemini 'NLP extraction (structured JSON)' $extractBody

if ($content) {
    $reply = (($content | ConvertFrom-Json).candidates[0].content.parts[0].text)
    Write-Host ''
    Write-Host 'Extraction sample:' -ForegroundColor Cyan
    Write-Host $reply
    Write-Host ''
    Write-Host 'All good - chatbot and voice/NLP extraction will work with this key.' -ForegroundColor Green
    exit 0
}
exit 1

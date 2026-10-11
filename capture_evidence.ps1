param(
  [string]$BaseUrl = 'http://localhost:5000',
  [string]$JqPath = 'C:\Users\DELL\Documents\Codex\2026-10-11\crea\work\jq.exe',
  [string]$GhPath = 'C:\Users\DELL\Documents\Codex\2026-10-11\crea\work\gh-portable\bin\gh.exe',
  [string]$Username = 'bookstudent2026',
  [Parameter(Mandatory = $true)]
  [string]$Password
)

$ErrorActionPreference = 'Stop'
$EvidenceDirectory = Join-Path $PSScriptRoot 'evidence'
$Curl = (Get-Command curl.exe).Source

if (-not (Test-Path -LiteralPath $JqPath)) {
  throw "jq was not found at $JqPath"
}

New-Item -ItemType Directory -Force -Path $EvidenceDirectory | Out-Null

function Invoke-Curl {
  param([string[]]$Arguments)

  $result = & $Curl @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "curl failed with exit code $LASTEXITCODE"
  }
  return ($result -join [Environment]::NewLine)
}

function Format-Json {
  param([string]$Json)

  $formatted = $Json | & $JqPath '.'
  if ($LASTEXITCODE -ne 0) {
    throw 'jq could not format a JSON response.'
  }
  return ($formatted -join [Environment]::NewLine)
}

function Save-Evidence {
  param(
    [string]$Name,
    [string]$Content
  )

  $path = Join-Path $EvidenceDirectory $Name
  [System.IO.File]::WriteAllText(
    $path,
    $Content.TrimEnd() + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false)
  )
}

$repositoryApi = 'https://api.github.com/repos/Ved171104dev/expressBookReviews'
$githubToken = & $GhPath auth token
if ($LASTEXITCODE -ne 0 -or -not $githubToken) {
  throw 'Unable to obtain the authenticated GitHub token.'
}
$repositoryJson = Invoke-Curl @(
  '-sS',
  '-H', "Authorization: Bearer $githubToken",
  $repositoryApi
)
$parentName = (($repositoryJson | & $JqPath '.parent.full_name') -join [Environment]::NewLine)
$forkSummary = (($repositoryJson | & $JqPath '{full_name, fork, parent: .parent.full_name}') -join [Environment]::NewLine)
Save-Evidence 'githubrepo' @"
`$ export GITHUB_TOKEN="`$(gh auth token)"
`$ curl -sS -H "Authorization: Bearer `$GITHUB_TOKEN" $repositoryApi | jq '.parent.full_name'
$parentName

`$ curl -sS -H "Authorization: Bearer `$GITHUB_TOKEN" $repositoryApi | jq '{full_name, fork, parent: .parent.full_name}'
$forkSummary
"@

$allBooks = Invoke-Curl @('-sS', "$BaseUrl/")
Save-Evidence 'getallbooks' @"
`$ curl -sS $BaseUrl/ | jq
$(Format-Json $allBooks)
"@

$isbnBook = Invoke-Curl @('-sS', "$BaseUrl/isbn/1")
Save-Evidence 'getbooksbyISBN' @"
`$ curl -sS $BaseUrl/isbn/1 | jq
$(Format-Json $isbnBook)
"@

$authorBooks = Invoke-Curl @('-sS', "$BaseUrl/author/Chinua%20Achebe")
Save-Evidence 'getbooksbyauthor' @"
`$ curl -sS "$BaseUrl/author/Chinua%20Achebe" | jq
$(Format-Json $authorBooks)
"@

$titleBooks = Invoke-Curl @('-sS', "$BaseUrl/title/Things%20Fall%20Apart")
Save-Evidence 'getbooksbytitle' @"
`$ curl -sS "$BaseUrl/title/Things%20Fall%20Apart" | jq
$(Format-Json $titleBooks)
"@

$initialReviews = Invoke-Curl @('-sS', "$BaseUrl/review/1")
Save-Evidence 'getbookreview' @"
`$ curl -sS $BaseUrl/review/1 | jq
$(Format-Json $initialReviews)
"@

$credentials = @{ username = $Username; password = $Password } | ConvertTo-Json -Compress
$badCredentials = @{ username = $Username; password = "$Password-invalid" } | ConvertTo-Json -Compress
$credentialCommand = '-d "{\"username\":\"${BOOK_USER}\",\"password\":\"${BOOK_PASSWORD}\"}"'
$badCredentialCommand = '-d "{\"username\":\"${BOOK_USER}\",\"password\":\"incorrect-password\"}"'

$registration = Invoke-Curl @(
  '-sS', '-X', 'POST', "$BaseUrl/register",
  '-H', 'Content-Type: application/json',
  '--data-raw', $credentials
)
$duplicateRegistration = Invoke-Curl @(
  '-sS', '-X', 'POST', "$BaseUrl/register",
  '-H', 'Content-Type: application/json',
  '--data-raw', $credentials
)
Save-Evidence 'register' @"
`$ export BOOK_USER='$Username'
`$ read -s -p "Book API password: " BOOK_PASSWORD; export BOOK_PASSWORD
`$ curl -sS -X POST $BaseUrl/register -H "Content-Type: application/json" $credentialCommand | jq
$(Format-Json $registration)

Duplicate-user demonstration:
`$ curl -sS -X POST $BaseUrl/register -H "Content-Type: application/json" $credentialCommand | jq
$(Format-Json $duplicateRegistration)
"@

$login = Invoke-Curl @(
  '-sS', '-X', 'POST', "$BaseUrl/customer/login",
  '-H', 'Content-Type: application/json',
  '--data-raw', $credentials
)
$loginObject = $login | ConvertFrom-Json
$token = $loginObject.accessToken
$redactedLogin = [ordered]@{
  message = $loginObject.message
  accessToken = '<redacted JWT token>'
} | ConvertTo-Json
$failedLogin = Invoke-Curl @(
  '-sS', '-X', 'POST', "$BaseUrl/customer/login",
  '-H', 'Content-Type: application/json',
  '--data-raw', $badCredentials
)
Save-Evidence 'login' @"
`$ curl -sS -X POST $BaseUrl/customer/login -H "Content-Type: application/json" $credentialCommand | jq
$(Format-Json $redactedLogin)
[JWT redacted after capturing the real response.]

Invalid-password demonstration:
`$ curl -sS -X POST $BaseUrl/customer/login -H "Content-Type: application/json" $badCredentialCommand | jq
$(Format-Json $failedLogin)
"@

$reviewJson = '{"review":"A fascinating and thought-provoking novel."}'
$reviewAdded = Invoke-Curl @(
  '-sS', '-X', 'PUT', "$BaseUrl/customer/auth/review/1",
  '-H', 'Content-Type: application/json',
  '-H', "Authorization: Bearer $token",
  '--data-raw', $reviewJson
)
Save-Evidence 'reviewadded' @"
`$ TOKEN=`$(curl -sS -X POST $BaseUrl/customer/login -H "Content-Type: application/json" $credentialCommand | jq -r '.accessToken')
`$ curl -sS -X PUT $BaseUrl/customer/auth/review/1 -H "Authorization: Bearer `$TOKEN" -H "Content-Type: application/json" -d '$reviewJson' | jq
$(Format-Json $reviewAdded)
"@

$reviewDeleted = Invoke-Curl @(
  '-sS', '-X', 'DELETE', "$BaseUrl/customer/auth/review/1",
  '-H', "Authorization: Bearer $token"
)
Save-Evidence 'deletereview' @"
`$ curl -sS -X DELETE $BaseUrl/customer/auth/review/1 -H "Authorization: Bearer `$TOKEN" | jq
$(Format-Json $reviewDeleted)
"@

Write-Output "Created evidence files in $EvidenceDirectory"

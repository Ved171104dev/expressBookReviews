#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:5000}"
EVIDENCE_DIR="${EVIDENCE_DIR:-evidence}"
USERNAME="bookstudent2026"
: "${BOOK_PASSWORD:?Set BOOK_PASSWORD to a local test password before running this script}"
CREDENTIALS="$(jq -nc --arg username "$USERNAME" --arg password "$BOOK_PASSWORD" '{username:$username,password:$password}')"
BAD_CREDENTIALS="$(jq -nc --arg username "$USERNAME" --arg password "$BOOK_PASSWORD-invalid" '{username:$username,password:$password}')"

mkdir -p "$EVIDENCE_DIR"

capture() {
  local file="$1"
  local command="$2"
  local output="$3"
  printf '$ %s\n%s\n' "$command" "$output" > "$EVIDENCE_DIR/$file"
}

REPO_API='https://api.github.com/repos/Ved171104dev/expressBookReviews'
GITHUB_TOKEN="${GITHUB_TOKEN:-$(gh auth token)}"
PARENT_OUTPUT="$(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" "$REPO_API" | jq '.parent.full_name')"
FORK_OUTPUT="$(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" "$REPO_API" | jq '{full_name, fork, parent: .parent.full_name}')"
printf '$ export GITHUB_TOKEN="$(gh auth token)"\n' > "$EVIDENCE_DIR/githubrepo"
printf '$ curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" %s | jq '\''.parent.full_name'\''\n%s\n\n' "$REPO_API" "$PARENT_OUTPUT" >> "$EVIDENCE_DIR/githubrepo"
printf '$ curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" %s | jq '\''{full_name, fork, parent: .parent.full_name}'\''\n%s\n' "$REPO_API" "$FORK_OUTPUT" >> "$EVIDENCE_DIR/githubrepo"

capture getallbooks "curl -sS $BASE_URL/ | jq" "$(curl -sS "$BASE_URL/" | jq)"
capture getbooksbyISBN "curl -sS $BASE_URL/isbn/1 | jq" "$(curl -sS "$BASE_URL/isbn/1" | jq)"
capture getbooksbyauthor "curl -sS \"$BASE_URL/author/Chinua%20Achebe\" | jq" "$(curl -sS "$BASE_URL/author/Chinua%20Achebe" | jq)"
capture getbooksbytitle "curl -sS \"$BASE_URL/title/Things%20Fall%20Apart\" | jq" "$(curl -sS "$BASE_URL/title/Things%20Fall%20Apart" | jq)"
capture getbookreview "curl -sS $BASE_URL/review/1 | jq" "$(curl -sS "$BASE_URL/review/1" | jq)"

REGISTER_OUTPUT="$(curl -sS -X POST "$BASE_URL/register" -H 'Content-Type: application/json' -d "$CREDENTIALS" | jq)"
DUPLICATE_OUTPUT="$(curl -sS -X POST "$BASE_URL/register" -H 'Content-Type: application/json' -d "$CREDENTIALS" | jq)"
printf '$ export BOOK_USER='\''%s'\''\n$ read -s -p "Book API password: " BOOK_PASSWORD; export BOOK_PASSWORD\n' "$USERNAME" > "$EVIDENCE_DIR/register"
printf '$ curl -sS -X POST %s/register -H "Content-Type: application/json" -d "{\\"username\\":\\"${BOOK_USER}\\",\\"password\\":\\"${BOOK_PASSWORD}\\"}" | jq\n%s\n\nDuplicate-user demonstration:\n' "$BASE_URL" "$REGISTER_OUTPUT" >> "$EVIDENCE_DIR/register"
printf '$ curl -sS -X POST %s/register -H "Content-Type: application/json" -d "{\\"username\\":\\"${BOOK_USER}\\",\\"password\\":\\"${BOOK_PASSWORD}\\"}" | jq\n%s\n' "$BASE_URL" "$DUPLICATE_OUTPUT" >> "$EVIDENCE_DIR/register"

LOGIN_JSON="$(curl -sS -X POST "$BASE_URL/customer/login" -H 'Content-Type: application/json' -d "$CREDENTIALS")"
TOKEN="$(jq -r '.accessToken' <<< "$LOGIN_JSON")"
REDACTED_LOGIN="$(jq '.accessToken = "<redacted JWT token>"' <<< "$LOGIN_JSON")"
FAILED_LOGIN="$(curl -sS -X POST "$BASE_URL/customer/login" -H 'Content-Type: application/json' -d "$BAD_CREDENTIALS" | jq)"
printf '$ curl -sS -X POST %s/customer/login -H "Content-Type: application/json" -d "{\\"username\\":\\"${BOOK_USER}\\",\\"password\\":\\"${BOOK_PASSWORD}\\"}" | jq\n%s\n[JWT redacted after capturing the real response.]\n\nInvalid-password demonstration:\n' "$BASE_URL" "$REDACTED_LOGIN" > "$EVIDENCE_DIR/login"
printf '$ curl -sS -X POST %s/customer/login -H "Content-Type: application/json" -d "{\\"username\\":\\"${BOOK_USER}\\",\\"password\\":\\"incorrect-password\\"}" | jq\n%s\n' "$BASE_URL" "$FAILED_LOGIN" >> "$EVIDENCE_DIR/login"

REVIEW='{"review":"A fascinating and thought-provoking novel."}'
ADDED="$(curl -sS -X PUT "$BASE_URL/customer/auth/review/1" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d "$REVIEW" | jq)"
printf '$ TOKEN=$(curl -sS -X POST %s/customer/login -H "Content-Type: application/json" -d "{\\"username\\":\\"${BOOK_USER}\\",\\"password\\":\\"${BOOK_PASSWORD}\\"}" | jq -r '\''.accessToken'\'')\n' "$BASE_URL" > "$EVIDENCE_DIR/reviewadded"
printf '$ curl -sS -X PUT %s/customer/auth/review/1 -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '\''%s'\'' | jq\n%s\n' "$BASE_URL" "$REVIEW" "$ADDED" >> "$EVIDENCE_DIR/reviewadded"

DELETED="$(curl -sS -X DELETE "$BASE_URL/customer/auth/review/1" -H "Authorization: Bearer $TOKEN" | jq)"
capture deletereview "curl -sS -X DELETE $BASE_URL/customer/auth/review/1 -H \"Authorization: Bearer \$TOKEN\" | jq" "$DELETED"

printf 'Created evidence files in %s\n' "$EVIDENCE_DIR"

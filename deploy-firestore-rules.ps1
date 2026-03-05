# Deploie les regles Firestore sur les bases test et prod.
# Necessaire car "firebase deploy --only firestore:rules" ne met pas a jour les bases nommees.
# Usage: .\deploy-firestore-rules.ps1

$ErrorActionPreference = "Stop"
Write-Host "Deploiement des regles Firestore (test)..." -ForegroundColor Cyan
firebase deploy --only firestore:test
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Deploiement des regles Firestore (prod)..." -ForegroundColor Cyan
firebase deploy --only firestore:prod
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Regles deployees sur test et prod." -ForegroundColor Green

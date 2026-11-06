# Uruchamia lokalnie serwer dedykowany, okno gry i opcjonalnie boty.
# Przyklad: powershell -ExecutionPolicy Bypass -File tools\run_local.ps1 -Bots 2 -Shooters 1
param(
	[int]$Bots = 1,
	[int]$Shooters = 0,
	[int]$Port = 0,
	[ValidateSet("deathmatch", "battle_royale")]
	[string]$Mode = "deathmatch",
	[switch]$DebugItems,
	[switch]$DebugWeapons
)

if ($Port -eq 0) { $Port = if ($Mode -eq "battle_royale") { 7778 } else { 7777 } }

$project = Split-Path -Parent $PSScriptRoot
$godot = $env:GODOT
if (-not $godot) {
	$godot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"
}
if (-not (Test-Path $godot)) {
	throw "Nie znaleziono Godota: $godot. Ustaw sciezke w zmiennej GODOT."
}

$running = @()
$running += Start-Process $godot -ArgumentList "--path `"$project`" --headless -- --server --port=$Port --mode=$Mode $(if ($DebugItems) { '--debug-items' }) $(if ($DebugWeapons) { '--debug-weapons' })" -WindowStyle Minimized -PassThru
Start-Sleep -Seconds 2

for ($i = 1; $i -le $Bots; $i++) {
	$running += Start-Process $godot -ArgumentList "--path `"$project`" --headless -- --connect=127.0.0.1 --port=$Port --name=Bot$i --bot=runner" -WindowStyle Minimized -PassThru
}
for ($i = 1; $i -le $Shooters; $i++) {
	$running += Start-Process $godot -ArgumentList "--path `"$project`" --headless -- --connect=127.0.0.1 --port=$Port --name=Strzelec$i --bot=shooter" -WindowStyle Minimized -PassThru
}

$game = Start-Process $godot -ArgumentList "--path `"$project`" -- --connect=127.0.0.1 --port=$Port --name=Ty" -PassThru
Wait-Process -Id $game.Id
$running | Where-Object { -not $_.HasExited } | Stop-Process

param([Parameter(Mandatory=$true)][string]$Symbols, [string]$Flutter='flutter')
$ErrorActionPreference='Stop'
python "$PSScriptRoot/build_obfuscated.py" android --symbols $Symbols --flutter $Flutter
exit $LASTEXITCODE

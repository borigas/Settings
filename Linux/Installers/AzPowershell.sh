#!/bin/bash
set -euo pipefail

if ! command -v pwsh >/dev/null 2>&1; then
    echo "PowerShell (pwsh) is not installed. Run Linux/Installers/pwsh.sh first."
    exit 1
fi

echo "Installing Azure PowerShell module (Az) for current user..."
pwsh -NoLogo -NoProfile -Command "Set-PSRepository PSGallery -InstallationPolicy Trusted; Install-Module Az -Scope CurrentUser -Repository PSGallery -Force -AllowClobber"

echo "Configuring Azure PowerShell auth for Linux (disable WAM broker)..."
pwsh -NoLogo -NoProfile -Command 'Update-AzConfig -EnableLoginByWam $false -Scope CurrentUser -AppliesTo Az'

echo "Verifying Az module install..."
pwsh -NoLogo -NoProfile -Command "Get-Module Az -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1 Name,Version"

echo "Azure PowerShell install complete."

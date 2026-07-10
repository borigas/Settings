#!/bin/bash
set -euo pipefail

if ! command -v pwsh >/dev/null 2>&1; then
    echo "PowerShell (pwsh) is not installed. Run Linux/Installers/pwsh.sh first."
    exit 1
fi

echo "Installing Azure PowerShell module (Az) for current user..."
pwsh -NoLogo -NoProfile -Command "Set-PSRepository PSGallery -InstallationPolicy Trusted; Install-Module Az -Scope CurrentUser -Repository PSGallery -Force -AllowClobber"

echo "Azure PowerShell install complete."

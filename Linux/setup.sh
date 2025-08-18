#!/bin/bash

settingsDir=/mnt/e/Settings
if command -v cmd.exe >/dev/null 2>&1; then
    echo "cmd.exe exists. Assuming we're running in WSL"
    windowsUserDir=$(wslpath $(cmd.exe /C "echo %USERPROFILE%" 2>/dev/null | tr -d '\r'))
else
    echo "cmd.exe does not exist. Assuming we're running in a non-WSL environment"
fi

scripts=(
    "$settingsDir/Linux/Installers/zsh.sh"

    "$settingsDir/Linux/Installers/pwsh.sh"

    "$settingsDir/Linux/Installers/kubectl.sh"
    "$settingsDir/Linux/Installers/kubent.sh"
    "$settingsDir/Linux/Installers/krew.sh"
    "$settingsDir/Linux/Installers/kubectx.sh"
    "$settingsDir/Linux/Installers/helm.sh"
)

# Map path for profile sharing
if [ ! -e ~/profile ]; then
    echo "Linking ~/profile"
    ln -s $settingsDir/Linux/Profile/ ~/profile
else
    echo "~/profile already exists"
fi

if [[ -v windowsUserDir ]]; then
    echo "Using Windows user directory: $windowsUserDir"

    # Map path for k8s config sharing
    kubePath="$windowsUserDir/.kube/"
    if [ ! -e ~/.kube ]; then
        echo "Linking $kubePath to ~/.kube"
        ln -s $kubePath ~/.kube
    else
        echo "~/.kube already exists"
    fi

    # Map path for Azure config sharing
    azurePath="$windowsUserDir/.azure/"
    if [ ! -e ~/.azure ]; then
        echo "Linking $azurePath to ~/.azure"
        ln -s $azurePath ~/.azure
    else
        echo "~/.azure already exists"
    fi
else
    echo "Windows user directory not set. Not linking context dirs between OSes."
fi

# Map path for Git config sharing
gitPath="$settingsDir/Git/.gitconfig"
if [ ! -e ~/.gitconfig ]; then
    echo "Linking $gitPath to ~/.gitconfig"
    ln -s $gitPath ~/.gitconfig
else
    echo "~/.gitconfig already exists"
fi

# Make sure profile.sh is included in .bashrc
syncedProfilePath="~/profile/profile.sh"
profilePath=~/.profile
if [ -z "$(grep "$syncedProfilePath" $profilePath)" ]; then
    echo "Appending $syncedProfilePath to $profilePath"

    echo -en "\n" >> $profilePath
    echo -en "\n" >> $profilePath
    echo "####   My Synced Profile   ####" >> $profilePath
    echo ". $syncedProfilePath" >> $profilePath
else
    echo "Profile already in $profilePath";
fi

confirm() {
  local msg="${1:-Proceed?}"
  while true; do
    read -rp "$msg [y/n]: " reply
    case "$reply" in
      [yY]) return 0 ;;
      [nN]) return 1 ;;
      *) echo "Please enter 'y' or 'n'." ;;
    esac
  done
}

for script in "${scripts[@]}"; do
  if confirm "Run '$script'?"; then
    echo "==> Running: $script"
    bash "$script"
  else
    echo "Skipping: $script"
  fi
done

echo "Done"
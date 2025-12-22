
function InstallKeyboard {

    ./CustomDvorak/setup.exe

    Write-Output "Installed Custom Keyboard"
}

function CreateRegistryKeyIfNotExists($registryPath)
{
    # From https://blogs.technet.microsoft.com/heyscriptingguy/2015/04/02/update-or-add-registry-key-value-with-powershell/
    if(!(Test-Path $registryPath))
    {
        $lastSlashIndex = $registryPath.LastIndexOf("\")
        $parentPath = $registryPath.Substring(0, $lastSlashIndex)
        CreateRegistryKeyIfNotExists $parentPath

        Write-Output "Creating $registryPath"
        New-Item -Path $registryPath
    }
}

function CreateOrUpdateRegistryKey($registryPath, $name, $value, $propertyType)
{
    CreateRegistryKeyIfNotExists $registryPath
    New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType $propertyType -Force
}

function InstallAutoHotKey($password) {

    $ahkDir = "$(Get-Location)\AutoHotKey"

    $ahkExePath = "$ahkDir\MyAutoHotKey.exe"

    $taskName = "AutoHotKey"

    CreateAutoStartAtLoginTask $password $ahkExePath $taskName

    # MicMute References
    # https://www.reddit.com/r/ErgoDoxEZ/comments/h0hn27
    # https://www.reddit.com/r/Windows10/comments/97bzbn
    # https://pastebin.com/raw/J15P9gVA
    $micMuteLocation = "$($ahkDir)\Programs\MicMute.exe"
    Write-Output "Setting up Mail key -> MicMute.exe override ($micMuteLocation)"
    # This key (AppKey) doesn't originally exist. To undo, delete it
    CreateOrUpdateRegistryKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AppKey\15" "ShellExecute" "$micMuteLocation"

    Write-Output "Installed AutoHotKey"
}

function InstallWinSplit($password) {

    $ahkExePath = "$(Get-Location)\WinSplitRevolution\WinSplit.exe"

    $taskName = "WinSplit Revolution"

    CreateAutoStartAtLoginTask $password $ahkExePath $taskName

    Write-Output "Installed Win Split Revolution"
}

function GetFullUserName {
    $user = "$([Environment]::UserDomainName)\$([Environment]::UserName)"
    return $user
}

function CreateIfNotExists($path){
    if(!(Test-Path -Path $path)){
        New-Item -ItemType directory -Path $path
    }
}

function CreateAutoStartAtLoginTask($password, $command, $taskNamd){

    $user = GetFullUserName

    $objUser = New-Object System.Security.Principal.NTAccount([Environment]::UserName)
    $strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])

    $xml = "<?xml version='1.0' encoding='UTF-16'?>
    <Task version='1.2' xmlns='http://schemas.microsoft.com/windows/2004/02/mit/task'>
      <RegistrationInfo>
        <Date>2013-01-10T14:50:59.8998405</Date>
        <Author>$user</Author>
      </RegistrationInfo>
      <Triggers>
        <LogonTrigger>
          <Enabled>true</Enabled>
          <UserId>$user</UserId>
        </LogonTrigger>
      </Triggers>
      <Principals>
        <Principal id='Author'>
          <UserId>$strSID</UserId>
          <LogonType>InteractiveToken</LogonType>
          <RunLevel>HighestAvailable</RunLevel>
        </Principal>
      </Principals>
      <Settings>
        <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
        <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
        <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>
        <AllowHardTerminate>true</AllowHardTerminate>
        <StartWhenAvailable>false</StartWhenAvailable>
        <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
        <IdleSettings>
          <StopOnIdleEnd>true</StopOnIdleEnd>
          <RestartOnIdle>false</RestartOnIdle>
        </IdleSettings>
        <AllowStartOnDemand>true</AllowStartOnDemand>
        <Enabled>true</Enabled>
        <Hidden>false</Hidden>
        <RunOnlyIfIdle>false</RunOnlyIfIdle>
        <WakeToRun>false</WakeToRun>
        <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
        <Priority>7</Priority>
      </Settings>
      <Actions Context='Author'>
        <Exec>
          <Command>$command</Command>
        </Exec>
      </Actions>
    </Task>"

    $xml > task.xml

    schtasks /Create /XML "task.xml" /IT /RU $user /RP $password /TN $taskName /F

    rm task.xml
}

function InstallGit(){
  choco install git -y
  & Git\Setup.ps1
}

& PowerShell\Setup.ps1

iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))

choco install googlechrome -y
choco install visualstudiocode -y
#choco install spotify -y
choco install ente-auth -y
choco install powertoys -y

InstallGit

if((Get-Item .).Name -ne "Settings"){
  cd ~
  git clone https://github.com/borigas/Settings

  cd Settings
}

InstallKeyboard

$passwordSecure = Read-Host "Enter password: " -AsSecureString

$password = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($passwordSecure))

InstallAutoHotKey($password)
InstallWinSplit($password)

function InstallWindowsTerminal(){
  choco install microsoft-windows-terminal -y
  & Terminal\Setup.ps1
}
InstallWindowsTerminal
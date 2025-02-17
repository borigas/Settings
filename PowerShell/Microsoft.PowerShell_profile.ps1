#### Functions Used to Load VS Command Prompt #####

# Change home to end with a "\". Allows cd ~ when ~ was D:. Otherwise, it acts as a drive change, not a dir change
(get-psprovider filesystem).Home = (get-psprovider filesystem).Home + "\"

# https://github.com/nightroman/PowerShelf/blob/master/Invoke-Environment.ps1
function Invoke-Environment
{
	param
	(
		[Parameter(Mandatory=1)][string]$Command,
		[switch]$Output,
		[switch]$Force
	)

	$stream = if ($Output) { ($temp = [IO.Path]::GetTempFileName()) } else { 'nul' }
	$operator = if ($Force) {'&'} else {'&&'}

	foreach($_ in cmd /c " $Command > `"$stream`" 2>&1 $operator SET") {
		if ($_ -match '^([^=]+)=(.*)') {
			[System.Environment]::SetEnvironmentVariable($matches[1], $matches[2])
		}
	}

	if ($Output) {
		Get-Content -LiteralPath $temp
		Remove-Item -LiteralPath $temp
	}
}

###### Function Used to Load VS Command Prompt #####
function VsVars32()
{
	$version = ""
	$vsWhere = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
	if(Test-Path $vsWhere){
		$vsLocation = & $vsWhere -latest -property installationPath
		# $vsDevCmd = "$vsLocation\Common7\Tools\VsDevCmd.bat"
		# Invoke-Environment $vsDevCmd

		$vsName = & $vsWhere -latest -property displayName
		$vsVersion = & $vsWhere -latest -property catalog_productDisplayVersion
		$version = "$vsName ($vsVersion)"

		$devShellDll = "$vsLocation\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
		Import-Module $devShellDll
		Enter-VsDevShell -VsInstallPath $vsLocation -StartInPath (Join-Path (Resolve-Path "~") "") | Out-Null
	}
	elseif(Test-Path env:VS140COMNTOOLS){
		$vsComntools = (Get-ChildItem env:VS140COMNTOOLS).Value
		if(Test-Path $vsComntools){
			$version = "14.0"
			$batchFile = [System.IO.Path]::Combine($vsComntools, "vsvars32.bat")
			Invoke-Environment $batchFile
			$version = "Visual Studio " + $version
		}
	}
	elseif(Test-Path env:VS120COMNTOOLS){
		$vsComntools = (Get-ChildItem env:VS120COMNTOOLS).Value
		if(Test-Path $vsComntools){
			$version = "12.0"
			$batchFile = [System.IO.Path]::Combine($vsComntools, "vsvars32.bat")
			Invoke-Environment $batchFile
			$version = "Visual Studio " + $version
		}
	}
	return $version
}

function AddAdbPathToPath(){
	# https://rajapet.com/2020/05/15/add-a-posh-adb-to-your-windows-terminal/
	if ($env:Path -NotMatch "Android\\android-sdk\\platform")
	{
		$adbPath = "${env:ProgramFiles(x86)}\Android\android-sdk\platform-tools"
		if(Test-Path $adbPath){
			$env:Path += ";$adbPath"
		}
	}
}

function CleanPath($path, $managedPath){
	$pathsToRemove = $path.Split(";") | Where-Object {$_.StartsWith($managedPath) -and !(Test-Path $_)}
	foreach($item in $pathsToRemove){
		$path = $path.Replace(";$item;", ";")
	}
	$pathItems = $path.Split(";", [System.StringSplitOptions]::RemoveEmptyEntries)
	$uniquePathItems = $pathItems | Select-Object -Unique
	$path = [System.String]::Join(";", $uniquePathItems)
	return $path
}

function AddToolsToPath(){
	$toolsPath = "C:\Tools\"
	if(Test-Path $toolsPath){
		$originalMachinePath = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
		$machinePath = $originalMachinePath
		$originalPsPath = $env:Path
		$psPath = $originalPsPath
		$toolDirs = Get-ChildItem $toolsPath
		foreach($tool in $toolDirs){
			if(!$psPath.Contains($tool.FullName)){
				$psPath += ";" + $tool.FullName
			}
			if(!$machinePath.Contains($tool.FullName)){
				$machinePath += ";" + $tool.FullName
			}
		}
		$machinePath = CleanPath $machinePath $toolsPath
		try{
			if($originalMachinePath -ne $machinePath){
				Write-Host "Modifying Machine Path Environment Variable"
				[Environment]::SetEnvironmentVariable("Path", $machinePath, [System.EnvironmentVariableTarget]::Machine)
				Write-Host "Modified Machine Path Environment Variable"
			}
		}catch{}
		$psPath = CleanPath $psPath $toolsPath
		if($originalPsPath -ne $psPath){
			$env:Path = $psPath
		}
	}
}

###### Function Used to Set Background to Light Blue If not Admin ######

function AmIAdmin()
{
	$wid=[System.Security.Principal.WindowsIdentity]::GetCurrent()
	$prp=new-object System.Security.Principal.WindowsPrincipal($wid)
	$adm=[System.Security.Principal.WindowsBuiltInRole]::Administrator
	$IsAdmin=$prp.IsInRole($adm)
    return $IsAdmin
}

###### Run Functions on Startup ######
$vsVersion = VsVars32

AddAdbPathToPath
AddToolsToPath

$isAdmin = AmIAdmin

###### Set Aliases ######
$editorPathOptions = @("code", "C:\Program Files\Notepad++\notepad++.exe", "C:\Program Files (x86)\Notepad++\notepad++.exe")
foreach ($possibleEditorPath in $editorPathOptions){
	if (Get-Command $possibleEditorPath -ErrorAction SilentlyContinue){
		set-alias notepad $possibleEditorPath
		break
	}
}

$hosts = $env:SystemRoot + "\system32\drivers\etc\hosts"
function edit-hostfile {
	notepad $hosts
}
set-alias hosts edit-hostfile
function Get-ProfileDirectory {
	$profileFile = Get-ChildItem $profile
	$profileFile.DirectoryName
}
set-alias profileDir Get-ProfileDirectory

set-alias g git

set-alias k kubectl
function gitstatus { git status }
set-alias gsl gitstatus
function gitstatusshort { git shorty }
set-alias gs gitstatusshort
function gitdiff { git diff }
set-alias gd gitdiff
function gitpull { git pull }
set-alias pu gitpull
function stash-pull{
	git stash
	git pull
	git stash pop
}
function publishBranch{
    $fullBranchName = git symbolic-ref HEAD
    $shortBranchName = $fullBranchName.Substring($fullBranchName.LastIndexOf("/")+1)
    git push --set-upstream origin $shortBranchName
}
set-alias gpub publishBranch
function gitBdoneWithWorkTreeSupport{
	$cleanBranchNames = git branch |
		ForEach-Object { $_ -replace '\**\+*\s*(.*)\s*','$1' }
	$branch = $cleanBranchNames |
		Select-String /master |
		ForEach-Object { $_ -replace '(.*)/master','$1' } |
		Where-Object { (Get-Location).Path.ToLower().Contains($_.ToLower()) } |
		ForEach-Object { "$_/master" } |
		Select-Object -First 1

	if(-Not $branch){
		if($cleanBranchNames -contains "master"){
			$branch = "master"
		}else{
			$branch = "main"
		}
	}
	git bdone $branch
}
set-alias bdone gitBdoneWithWorkTreeSupport

set-alias c clear

function mongo {
    . "C:\MongoDb\bin\mongo.exe" --shell --host HV-Mongo01
}

Import-Module posh-git
# Don't overwrite window title
#$GitPromptSettings.WindowTitle = $null
$GitPromptSettings.WindowTitle = { param($GitStatus, [bool]$IsAdmin) "$(if ($GitStatus) {"$($GitStatus.RepoName) [$($GitStatus.Branch)]"} else {Get-PromptPath}) ~ $(if ($vsVersion) {"$vsVersion ~ "})PowerShell $($PSVersionTable.PSVersion) $([IntPtr]::Size * 8)-bit $(if ($IsAdmin) {'Admin'})" }
Import-Module DockerCompletion

### PSReadLine customizations. https://github.com/PowerShell/PSReadLine/blob/master/PSReadLine/SamplePSReadLineProfile.ps1#L13-L21
# Turn on history
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# `ForwardChar` accepts the entire suggestion text when the cursor is at the end of the line.
# This custom binding makes `RightArrow` behave similarly - accepting the next word instead of the entire suggestion text.
Set-PSReadLineKeyHandler -Key Ctrl+RightArrow `
                         -BriefDescription ForwardCharAndAcceptNextSuggestionWord `
                         -LongDescription "Move cursor one word to the right in the current editing line and accept the next word in suggestion when it's at the end of current editing line" `
                         -ScriptBlock {
    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($cursor -lt $line.Length) {
        [Microsoft.PowerShell.PSConsoleReadLine]::ForwardWord($key, $arg)
    } else {
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptNextSuggestionWord($key, $arg)
    }
}

# Save commands
# Sometimes you enter a command but realize you forgot to do something else first.
# This binding will let you save that command in the history so you can recall it,
# but it doesn't actually execute.  It also clears the line with RevertLine so the
# undo stack is reset - though redo will still reconstruct the command line.
Set-PSReadLineKeyHandler -Key Alt+w `
                         -BriefDescription SaveInHistory `
                         -LongDescription "Save current line in history but do not execute" `
                         -ScriptBlock {
    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    [Microsoft.PowerShell.PSConsoleReadLine]::AddToHistory($line)
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
}


#$locationChange = Get-History | Select-Object -Last 1 | Where-Object {$_.CommandLine.StartsWith("Set-Location")}
#$isDefaultLocation = -Not $locationChange

# Normalize with Join-Path so we get consistent slashes/casing
$currentPath = Join-Path (Get-Location).Path ""
$homePath = Join-Path (Resolve-Path "~") ""
$isDefaultLocation = ($currentPath -eq "C:\Windows\System32") -or ($currentPath -eq $homePath)
$pathPriorities = @("C:\workspaces\ComputerVision\DontPanic.CV.Tracking", "D:\workspaces\ComputerVision\DontPanic.CV.Tracking", "C:\workspaces\OV1\DontPanic.CV.Tracking", "C:\workspaces", "D:\workspaces")
foreach($path in $pathPriorities)
{
	if(Test-Path $path)
	{
		# Change directories only if we're in the default dir
		if($isDefaultLocation)
		{
			cd $path
		}

		# Load Ocuvera modules when that dir is found
		if($path.EndsWith("DontPanic.CV.Tracking")){
			$moduleDir = $path + "\Scripts\OcuveraModules"
			if(Test-Path $moduleDir){
				$modulePaths = Get-ChildItem $moduleDir | Select -ExpandProperty FullName
				foreach($modulePath in $modulePaths){
					Import-Module $modulePath
				}
			}
		}
		break
	}
}

# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}

# Import z after changing our initial directory to avoid writing to ~\.cdhistory from multiple concurrent PS starts
Import-Module z
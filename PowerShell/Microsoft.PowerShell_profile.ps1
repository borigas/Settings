Clear-Host

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
		$vsDevCmd = "$vsLocation\Common7\Tools\VsDevCmd.bat"
		Invoke-Environment $vsDevCmd

		$vsName = & $vsWhere -latest -property displayName
		$vsVersion = & $vsWhere -latest -property catalog_productDisplayVersion
		$version = "$vsName ($vsVersion)"
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

function mongo {
    . "C:\MongoDb\bin\mongo.exe" --shell --host HV-Mongo01
}

Import-Module posh-git
# Don't overwrite window title
#$GitPromptSettings.WindowTitle = $null
$GitPromptSettings.WindowTitle = { param($GitStatus, [bool]$IsAdmin) "$(if ($GitStatus) {"$($GitStatus.RepoName) [$($GitStatus.Branch)]"} else {Get-PromptPath}) ~ $(if ($vsVersion) {"$vsVersion ~ "})PowerShell $($PSVersionTable.PSVersion) $([IntPtr]::Size * 8)-bit $(if ($IsAdmin) {'Admin'})" }
Import-Module DockerCompletion

Import-Module z

#$locationChange = Get-History | Select-Object -Last 1 | Where-Object {$_.CommandLine.StartsWith("Set-Location")}
#$isDefaultLocation = -Not $locationChange

# Normalize with Join-Path so we get consistent slashes/casing
$currentPath = Join-Path (Get-Location).Path ""
$homePath = Join-Path (Resolve-Path "~") ""
$isDefaultLocation = ($path -eq "C:\Windows\System32") -or ($currentPath -eq $homePath)
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
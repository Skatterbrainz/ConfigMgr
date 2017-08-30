<#
.NOTES
  Usage...
  
  [xml]$xmldata = Get-Content ".\Import-Apps.xml"
  .\Import-Apps.ps1 -DataSet $xmldata
#>

# based on = https://raw.githubusercontent.com/DexterPOSH/PS_ConfigMgr/master/SCCM2012_CreateScriptApps.ps1
$sitecode  = "P01"
$hostname  = "CM02"

Import-Module -Name "$(Split-Path $Env:SMS_ADMIN_UI_PATH)\ConfigurationManager.psd1"
Set-Location -Path "$sitecode`:"

function Import-CMSiteApplications {
    [CmdletBinding(SupportsShouldProcess=$True)]
    param (
        $DataSet
    )
    $PSDefaultParameterValues =@{"get-cimclass:namespace"="Root\SMS\site_$sitecode";"get-cimclass:computername"="$hostname";"get-cimInstance:computername"="$hostname";"get-ciminstance:namespace"="Root\SMS\site_$sitecode"}
    foreach ($appSet in $DataSet.configuration.cmsite.applications.application | Where-Object {$_.enabled -eq 'true'}) {
        # APPLICATION
        # name="7-Zip" 
        # enabled="true" 
        # publisher="7-Zip" 
        # version="16.04" 
        # categories="General" 
        # comment="File compression utility" 
        # keywords="file,zip,utility,archive,compression"

        $appName = $appSet.name 
        $appComm = $appSet.comment
        $appPub  = $appSet.publisher
        $appVer  = $appSet.version
        $appCats = $appSet.categories
        $appKeys = $appSet.keywords

        Write-Host "app name......... $appName"
        Write-Host "app publisher.... $appPub"
        Write-Host "app comment...... $appComm"
        Write-Host "app version...... $appVer"
        Write-Host "app categories... $appCats"
        Write-Host "app keywords..... $appKeys"

        try {
            $app = New-CMApplication -Name "$appName" -Description "appComm" -SoftwareVersion "1.0" -AutoInstall $true -Publisher $appPub -ErrorAction SilentlyContinue
            Write-Host "application created successfully"
        }
        catch {
            if ($_.Exception.Message -eq 'An object with the specified name already exists.') {
                Write-Host "Application already defined" -ForegroundColor Cyan
                $app = Get-CMApplication -Name $appName
            }
            else {
                Write-Error $_.Exception.Message
                $app = $null
            }
        }
        if ($app) {
            foreach ($depType in $appSet.deptypes.deptype) {
                # DEPLOYMENT TYPE:
                # name="x64 installer" 
                # source="\\contoso.com\software\Apps\Notepad++\7.5\npp.7.5.installer.x64.exe" 
                # options="/s" 
                # uninstall="C:\Program Files\Notepad++\uninstall.exe" 
                # detect="registry:HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Notepad++,DisplayVersion(ge)7.5" 
                # requires="" 
                # comment="64-bit installer" />

                $depName   = $depType.name
                $depSource = $depType.source
                $depOpts   = $depType.options
                $depData   = $depType.detect
                $uninst    = $depType.uninstall
                $depComm   = $depType.comment
                $reqts     = $depType.requires
                $depPath   = Split-Path -Path $depSource
                $depFile   = Split-Path -Path $depSource -Leaf
                $program   = "$depFile $depOpts"

                Write-Host "dep name........ $depName"
                Write-Host "dep comment..... $depComm"
                Write-Host "dep Source...... $depSource"
                Write-Host "dep options..... $depOpts"
                Write-Host "dep detect...... $depData"
                Write-Host "dep uninstall... $uninst"
                Write-Host "dep reqts....... $reqts"
                Write-Host "dep path........ $depPath"
                Write-Host "dep file........ $depFile"
                Write-Host "dep program..... $program"

                if ($depOpts -eq 'auto') {
                    Write-Host "installer type: msi" -ForegroundColor Cyan
                    try {
                        Add-CMDeploymentType -ApplicationName $appName -AutoIdentifyFromInstallationFile -ForceForUnknownPublisher $true -InstallationFileLocation $depSource -MsiInstaller -DeploymentTypeName $depName
                        Write-Host "deployment type created"
                    }
                    catch {
                        if ($_.Exception.Message -like '*same name already exists.') {
                            Write-Host "deployment type already exists" -ForegroundColor Cyan
                        }
                        else {
                            Write-Error $_
                        }
                    }
                }
                else {
                    if ($depData.StartsWith("registry")) {
                        # registry:HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Notepad++,DisplayVersion,-ge,7.5
                        $depDetect  = $depData.Split(":")[1]
                        $depRuleSet = $depDetect.Split(",")
                        $ruleKey    = $depRuleSet[0] # "HKLM:\...."
                        $ruleKey = $ruleKey.Substring(5)
                        $ruleVal    = $depRuleSet[1] # "DisplayVersion"
                        $ruleChk    = $depRuleSet[2] # "-ge"
                        $ruleData   = $depRuleSet[3] # "7.5"
                    }
                    $scriptDetection = @"
try {
    $Reg = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, "default")
    $key = $reg.OpenSubKey("$ruleKey")
    $val = $key.GetValue("$ruleVal")
    if ($val $ruleChk "$ruleData") {Write-Host 'Installed'}
}
catch {}
"@
                    Write-Host "rule: $scriptDetection"

                    $DeploymentTypeHash = @{
                        ManualSpecifyDeploymentType = $true
                        ApplicationName = "$appName"
                        DeploymentTypeName = "$DepName"
                        DetectDeploymentTypeByCustomScript = $true
                        ScriptInstaller = $true
                        ScriptType = 'PowerShell'
                        ScriptContent =$scriptDetection
                        AdministratorComment = "$depComm"
                        ContentLocation = "$depPath"
                        InstallationProgram = "$program"
                        UninstallProgram = "$uninst"
                        RequiresUserInteraction = $false
                        InstallationBehaviorType = 'InstallForSystem'
                        InstallationProgramVisibility = 'Hidden'
                    }

                    Write-Host "Adding Deployment Type" -ForegroundColor Green

                    Add-CMDeploymentType @DeploymentTypeHash -EnableBranchCache $True

                    if ($folder -eq "") {
                        Write-Host "Moving application object to folder: $folder" -ForegroundColor Green
                        $app = Get-CMApplication -Name $ApplicationName
                        $app | Move-CMObject -FolderPath "Application\$folder" | Out-Null
                    }
                } # if
            } # foreach - deployment type
            Write-Host "-----------------------------------------------" -ForegroundColor Cyan
        } # if
    } # foreach - application
    Write-Output $result
}

############################################################################################################################################
# This script allows to deploy a farm solution to a SharePoint 2010 / 2013 farm.
# Required Parameters:
#   ->$sSolutionName: Name of the farm solution to be deployed.
#   ->$sWebAppUrl: Web Application Url where we want to deploy the WSP (vs. doing a global deployment)
#   ->$sFeatureName: Name of the feature to be enabled.
#   ->$sSiteCollecionUrl: Site collection Url where the feature is enabled
############################################################################################################################################

If ((Get-PSSnapIn -Name Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue) -eq $null ) 
{ Add-PSSnapIn -Name Microsoft.SharePoint.PowerShell }

$host.Runspace.ThreadOptions = "ReuseThread"

#Initializing all the required parameters
$sCurrentDir=Split-Path -parent $MyInvocation.MyCommand.Path
$sSolutionName="Norbert.GestionAverias.UI.wsp"
$sFeatureName="Norbert.GestionAverias.UI_gaUIFeature"
$sWebAppUrl="http://norbert/"
$sSiteCollectionUrl="http://norbert/sites/Intranet/"
$sSolutionPath=$sCurrentDir + "\"+$sSolutionName 

#Function that allows to wait for the timer job until it finishes
function WaitForJobToFinish([string]$sSolutionName)
{ 
    $JobName = "*solution-deployment*$sSolutionName*"
    $job = Get-SPTimerJob | ?{ $_.Name -like $JobName }
    if ($job -eq $null) 
    {
        Write-Host 'Timer job not found'
    }
    else
    {
        $JobFullName = $job.Name
        Write-Host -NoNewLine "Waiting theTimer Job $JobFullName finishes"
        
        while ((Get-SPTimerJob $JobFullName) -ne $null) 
        {
            Write-Host -NoNewLine .
            Start-Sleep -Seconds 2
        }
        Write-Host  "Waiting time for the Timer Job just finished..."
    }
}

#This function checks if the solution to be deployed already exists in the farm
function CheckSolutionExist([string] $sSolutionName)
{
    $spFarm = Get-SPFarm
    $spSolutions = $spFarm.Solutions
    $bExists = $false
 
    foreach ($spSolution in $spSolutions)
    {
        if ($spSolution.Name -eq $sSolutionName)
        {
            $bExists = $true
            return $bExists
            break
        }
    }
    return $bExists
}

#In case the solution to be installed already exists in the farm, we uninstall it
function UninstallRemoveSolution([string] $sSolutionName, [string] $sWebAppUrl)
{
    $sSolution=Get-SPSolution $sSolutionName
    Write-Host 'Uninstalling the farm solution $sSolutionName'
    if ( $sSolution.ContainsWebApplicationResource ) {
        Uninstall-SPSolution -Identity $sSolutionName -Confirm:$false -Webapplication $sWebAppUrl        
    }
    else {
        Uninstall-SPSolution -Identity $sSolutionName -Confirm:$false
    }
    Write-Host 'Waiting for the Timer Job'
    WaitForJobToFinish 
    
    Write-Host 'Deleting the farm solution $solutionName'
    Remove-SPSolution -identity $sSolutionName -confirm:$false
}

#Function that install the solution in the farm
function AddInstallSolution([string] $sSolutionName, [string] $sSolutionPath, [string] $sWebAppUrl)
{
    Write-Host 'Adding the solution $sSolutionName'
    $sSolution=Add-SPSolution $sSolutionPath
    
    if ( $sSolution.ContainsWebApplicationResource ) {
        Install-SPSolution –identity $sSolutionName –GACDeployment -WebApplication $sWebAppUrl     
    }
    else {
        Install-SPSolution –identity $sSolutionName –GACDeployment -Force
    }
    Write-Host 'Waiting for the Timer Job' 
    WaitForJobToFinish 
}

#..............................................................................
#Solution installation process
#..............................................................................
$bSolutionFound=CheckSolutionExist -sSolutionName $sSolutionName

#Checking if the solution already exists in the farm
if($bSolutionFound)
{
    Write-Host "The solution $sSolutionName already exists in the farm. Uninstalling it..."
    UninstallRemoveSolution -sSolutionName $sSolutionName -sWebAppUrl $sWebAppUrl
}

#Adding the solution to the farm
AddInstallSolution -sSolutionName $sSolutionName -sSolutionPath $sSolutionPath -sWebAppUrl $sWebAppUrl

#Enabling / Disabling the feature
Write-Host 'Disabling the feature'
Disable-SPFeature –identity $sFeatureName -Url $sSiteCollectionUrl -Confirm:$false
Write-Host 'Enabling the feature'
Enable-SPFeature –identity $sFeatureName -Url $sSiteCollectionUrl

Remove-PSSnapin Microsoft.SharePoint.PowerShell
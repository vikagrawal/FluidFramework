<#
    Script to start the scale test runs:
        1. Logs in to the AKS portal using a service principal
        2. Powers on the Managed Cluster
        3. Scales up the nodes
        4. Triggers the scale test
        5. Deletes the namespace after a specified time, to handle the cold start issue
        6. Re-Triggers the scale test

    Make sure that all the appropriate environment variables are set.
#>

Param(
    [Parameter(Mandatory = $false, HelpMessage = 'Number of documents to run test on')]
    [ValidateRange(1, 2400)]
    [int]$NumOfDocs = 10,

    [Parameter(Mandatory = $false, HelpMessage = 'Profile to run test with')]
    [string]$Profile = 'scale',

    [Parameter(Mandatory = $false, HelpMessage = 'AKS Namespace')]
    [ValidateScript({ ( $NumOfDocs -le 10 ) -or ($_ -eq 'fluid-scale-test' ) })]
    [string]$Namespace = 'fluid-scale-test',

    [Parameter(Mandatory = $false, HelpMessage = 'Folder to create in Storage for test files')]
    [string]$TestDocFolder = [Math]::Floor([decimal](Get-Date(Get-Date).ToUniversalTime() -uformat '%s')),

    [Parameter(Mandatory = $false, HelpMessage = 'File with tenants and users information')]
    [string]$TestTenantConfig = '.\testTenantConfig_vmss.json',

    [Parameter(Mandatory = $false, HelpMessage = 'Number of nodes to which the node pool should be scaled')]
    [string]$NodeCount = '5',

    [Parameter(Mandatory = $false, HelpMessage = 'Name of the resource group')]
    [string]$ResourceGroup = 'Fluid.Load.Test',

    [Parameter(Mandatory = $false, HelpMessage = 'Name of the AKS Cluster')]
    [string]$AKSClusterName = 'LoadTestAks1',

    [Parameter(Mandatory = $false, HelpMessage = 'Name of the node pool to be scaled')]
    [string]$NodePoolName = 'testpods',

    # Restart the load test after a specified time to avoid the Cold Start issue
    [Parameter(Mandatory = $false, HelpMessage = 'Time (in min) after which the scale test is re-triggered')]
    [int]$RestartTime = 60,

    [Parameter(Mandatory = $false, HelpMessage = 'Load Test Scripts Directory')]
    [string]$LoadTestDir = "C:\loadtest"
)

# Make sure this points to the right directory in your local setup (wherever the load test scripts are present)
cd $LoadTestDir

Write-Host "Logging in to the AKS portal" -ForegroundColor Green
# Service principal based authentication
az login --service-principal -u $env:AKSServicePrincipalID -p $env:AKSServicePrincipalKey --tenant $env:AKSTenant

Write-Host "Loading variables and preparing for run" -ForegroundColor Green
. .\runloadtest.ps1

Write-Host "Powering On Managed Cluster" -ForegroundColor Green
az aks start -n $AKSClusterName -g $ResourceGroup

Write-Host "Scaling the Node Pool" -ForegroundColor Green
# Manually scale the Node Pool as appropriate
$_ScaleNodesJob = { param($nodecount, $resourcegroup, $aksclustername, $nodepoolname) `
                   az aks scale --resource-group $resourcegroup --name $aksclustername `
                   --node-count $nodecount --nodepool-name $nodepoolname 
                 }
$ScaleNodesJob = Start-Job $_ScaleNodesJob -ArgumentList $NodeCount, `
                                                         $ResourceGroup, `
                                                         $AKSClusterName, `
                                                         $NodePoolName
Wait-Job $ScaleNodesJob
Receive-Job $ScaleNodesJob
Write-Host "Scaling Node Pool Finished" -ForegroundColor Green

Write-Host "Triggering Load Test" -ForegroundColor Green
# Trigger the first run of the load test
RunLoadTest -Profile $Profile -NumOfDocs $NumOfDocs -TestTenantConfig $TestTenantConfig

# Waits for a specified amount of time after which the load test is re-triggered
Start-Sleep -Seconds (1*60*$RestartTime)

# End the first run, and re-trigger a second. This is done to tackle the cold-start issue we often encounter
Write-Host "Ending the Load Test" -ForegroundColor Green
$DeleteNamespaceJob = { param($namespace) `
                        kubectl delete ns $namespace
                      }
$DeleteJob = Start-Job $DeleteNamespaceJob -ArgumentList $Namespace
Wait-Job $DeleteJob
Receive-Job $DeleteJob

# Sets the StartTime environment variable - which will later be used by the queryLoadTestResults script
$StartTime = (Get-Date -Format "yyyy-MM-ddTHH:mm").ToString()
[System.Environment]::SetEnvironmentVariable('LoadTestStartTime', `
                                             $StartTime, `
                                             [System.EnvironmentVariableTarget]::User)

Write-Host "Re-Triggering Load Test" -ForegroundColor Green
# Modify $OutFile as appropriate to point to the location where you want to save the output of `RunLoadTest`
$OutFile = (Get-Location).ToString() +"\out\" + (Get-Date -Format "dddd MM_dd_yyyy HH_mm").ToString() + ".txt"
RunLoadTest -Profile $Profile -NumOfDocs $NumOfDocs -TestTenantConfig $TestTenantConfig `
            | Out-File -FilePath $OutFile
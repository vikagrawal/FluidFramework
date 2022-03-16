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

    [Parameter(Mandatory = $false, HelpMessage = 'Name of profile to run test with')]
    [string]$Profile = "<Load Test Profile>",

    [Parameter(Mandatory = $false, HelpMessage = 'File containing various test profiles/configurations')]
    [string]$TestConfig = "<TestConfig File Path>",

    [Parameter(Mandatory = $false, HelpMessage = 'AKS Namespace')]
    [ValidateScript({ ( $NumOfDocs -le 10 ) -or ($_ -eq 'fluid-scale-test' ) })]
    [string]$Namespace = "<AKS Load Test Namespace>",

    [Parameter(Mandatory = $false, HelpMessage = 'Folder to create in Storage for test files')]
    [string]$TestDocFolder = [Math]::Floor([decimal](Get-Date(Get-Date).ToUniversalTime() -uformat '%s')),

    [Parameter(Mandatory = $false, HelpMessage = 'File with tenants and users information')]
    [string]$TestTenantConfig = "<TestTenantConfig File Path>",

    [Parameter(Mandatory = $false, HelpMessage = 'Number of nodes to which the node pool should be scaled')]
    [AllowNull()]
    [string]$NodeCount = $null,

    [Parameter(Mandatory = $false, HelpMessage = 'Number of pods per node, to be used in the calculation of NodeCount if not user specified')]
    [int]$NumPodsPerNode = 13,

    [Parameter(Mandatory = $false, HelpMessage = 'Name of the resource group')]
    [string]$ResourceGroup = "<Resource Group Name>",

    [Parameter(Mandatory = $false, HelpMessage = 'Name of the AKS Cluster')]
    [string]$AKSClusterName = "<AKS Cluster Name>",

    [Parameter(Mandatory = $false, HelpMessage = 'Name of the node pool to be scaled')]
    [string]$NodePoolName = "<Node Pool Name>",

    # Restart the load test after a specified time to avoid the Cold Start issue
    [Parameter(Mandatory = $false, HelpMessage = 'Time (in min) after which the scale test is re-triggered')]
    [int]$RestartTime = 60,

    [Parameter(Mandatory = $false, HelpMessage = 'Load Test Scripts Directory')]
    [string]$LoadTestDir = "<Load Test Codebase Directory>",

    [Parameter(Mandatory = $false, HelpMessage = 'Boolean to indicate if a custom profile is to be created')]
    [bool]$CreateCustomProfile = $false,

    [Parameter(Mandatory = $false, HelpMessage = 'opRatePerMin')]
    [single]$OpRatePerMin = 40.5,
 
    [Parameter(Mandatory = $false, HelpMessage = 'signalsPerMin')]
    [AllowNull()]
    [Nullable[single]]$SignalsPerMin = $null,

    [Parameter(Mandatory = $false, HelpMessage = 'totalSignalsSendCount')]
    [AllowNull()]
    [Nullable[System.Int32]]$TotalSignalsSendCount= $null,

    [Parameter(Mandatory = $false, HelpMessage = 'progressIntervalMs')]
    [int]$ProgressIntervalMs = 20000,

    [Parameter(Mandatory = $false, HelpMessage = 'numClients')]
    [int]$NumClients = 10,

    [Parameter(Mandatory = $false, HelpMessage = 'totalSendCount')]
    [int]$TotalOpsSendCount = 70000,

    [Parameter(Mandatory = $false, HelpMessage = 'readWriteCycleMs')]
    [int]$ReadWriteCycleMs = 30000,     

    [Parameter(Mandatory = $false, HelpMessage = 'faultInjectionMinMs')]
    [AllowNull()]
    [Nullable[System.Int32]]$FaultInjectionMinMs = $null,
    
    [Parameter(Mandatory = $false, HelpMessage = 'faultInjectionMaxMs')]
    [AllowNull()]
    [Nullable[System.Int32]]$FaultInjectionMaxMs = $null,

    [Parameter(Mandatory = $false, HelpMessage = 'Test Config File Path')]
    [string]$TestConfigFilePath = './testConfig.json',

    [Parameter(Mandatory = $false, HelpMessage = 'Specify operations send type mechanism')]
    [AllowNull()]
    [string]$OpsSendType = 'staggeredReadWrite'
)

# Make sure this points to the right directory in your local setup (wherever the load test scripts are present)
cd $LoadTestDir

if ($CreateCustomProfile -eq $true)
{
    Write-Host "Configuring the test profile" -ForegroundColor Green
    ./inputToTestConfig.ps1 -NumOfDocs $NumOfDocs -TestProfile $Profile -opRatePerMin $OpRatePerMin -signalsPerMin $SignalsPerMin `
                            -totalSignalsSendCount $TotalSignalsSendCount -progressIntervalMs $ProgressIntervalMs `
                            -numClients $NumClients -totalSendCount $TotalOpsSendCount -readWriteCycleMs $ReadWriteCycleMs `
                            -faultInjectionMinMs $FaultInjectionMinMs -faultInjectionMaxMs $FaultInjectionMaxMs `
                            -opsSendType $OpsSendType -TestConfigFilePath $TestConfigFilePath
}

Write-Host "Logging in to the AKS portal" -ForegroundColor Green
# Service principal based authentication
az login --service-principal -u $env:AKSServicePrincipalID -p $env:AKSServicePrincipalKey --tenant $env:AKSTenant

Write-Host "Loading variables and preparing for run" -ForegroundColor Green
. .\runloadtest.ps1

Write-Host "Powering On Managed Cluster" -ForegroundColor Green
az aks start -n $AKSClusterName -g $ResourceGroup

Write-Host "Scaling the Node Pool" -ForegroundColor Green
# Manually scale the Node Pool as appropriate
if ([string]::IsNullOrEmpty($NodeCount))
{
    $NodeCount = [math]::ceiling($NumOfDocs/$NumPodsPerNode)
}
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
RunLoadTest -TestProfile $Profile -NumOfDocs $NumOfDocs -TestTenantConfig $TestTenantConfig

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
RunLoadTest -TestProfile $Profile -NumOfDocs $NumOfDocs -TestTenantConfig $TestTenantConfig `
            | Out-File -FilePath $OutFile
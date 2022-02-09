<#
    Script to stop the scale test runs:
        1. Deletes the namespace
        2. Scales down the nodes
        3. Powers off the Managed Cluster

    Make sure that all the appropriate environment variables are set.
#>

Param(
    [Parameter(Mandatory = $false, HelpMessage = 'AKS Namespace')]
    [string]$Namespace = 'fluid-scale-test',

    [Parameter(Mandatory = $false, HelpMessage = 'Number of nodes to which the node pool should be scaled')]
    [string]$NodeCount = '0',

    [Parameter(Mandatory = $false, HelpMessage = 'Name of the resource group')]
    [string]$ResourceGroup = 'Fluid.Load.Test',

    [Parameter(Mandatory = $false, HelpMessage = 'Name of the AKS Cluster')]
    [string]$AKSClusterName = 'LoadTestAks1',

    [Parameter(Mandatory = $false, HelpMessage = 'Name of the node pool to be scaled')]
    [string]$NodePoolName = 'testpods',

    [Parameter(Mandatory = $false, HelpMessage = 'Load Test Scripts Directory')]
    [string]$LoadTestDir = "C:\loadtest"
)

# Make sure this points to the right directory in your local setup (wherever the load test scripts are present)
cd $LoadTestDir

Write-Host "Deleting namespace  " -ForegroundColor Green
kubectl delete ns $Namespace

Write-Host "Scaling down the node pool  " -ForegroundColor Green
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
Write-Host "Finished scaling down the node pool" -ForegroundColor Green

Write-Host "Powering Off Managed Cluster" -ForegroundColor Green
az aks stop -n $AKSClusterName -g $ResourceGroup
Write-Host "Powered Off Managed Cluster" -ForegroundColor Green

# Sets the StopTime environment variable - which will later be used by the queryLoadTestResults script
$StopTime = (Get-Date -Format "yyyy-MM-ddTHH:mm").ToString()
[System.Environment]::SetEnvironmentVariable('LoadTestStopTime', `
                                              $StopTime, `
                                              [System.EnvironmentVariableTarget]::User)
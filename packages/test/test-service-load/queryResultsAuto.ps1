<#
    Script to fetch the results at the end of a load test run.
    Triggered as a scheduled task at the specified time.

    Make sure that the appropriate environment variables are set.
#>

Param(
    [Parameter(Mandatory = $false, HelpMessage = 'Load Test Scripts Directory')]
    [string]$LoadTestDir = "C:\loadtest"
)

# Make sure this points to the right directory in your local setup (wherever the load test scripts are present)
cd $LoadTestDir

# Register the QueryLoadTestResults cmdlet function
. .\queryLoadTestResults.ps1

# Fetch the required environment variables 
$AppID = [System.Environment]::GetEnvironmentVariable('AppInsightAppID')
$APIKey = [System.Environment]::GetEnvironmentVariable('AppInsightAPIKey')

Write-Host "Fetching the Latest Results" -ForegroundColor Green
QueryLoadTestResults -KustoQueryName "TestRunSummary" -AppID $AppID -APIKey $APIKey
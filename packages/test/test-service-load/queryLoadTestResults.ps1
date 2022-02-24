<#
    Make sure that the appropriate environment variables are set.
    Uses the python json.tool to pretty-print the results JSON object.
#>

function QueryLoadTestResults{
    <#
        .SYNOPSIS
            Fetches the results of the load test run.
        
        .DESCRIPTION
            Queries the results of the scale test by calling the REST API exposed by AppInsights.
            Generates the corresponding CURL command given the KustoQuery, and appropriate parameters.
            Saves the results as a pretty-printed JSON object, to an output file.

        .PARAMETER AppID
            Application ID for the AppInsights Client
        
        .PARAMETER APIKey
            APIKey to call the AppInsights REST API
        
        .PARAMETER Timespan
            Timespan to look at, in the AppInsight logs
        
        .PARAMETER KustoQueryName
            Name of the KustoQuery to be executed
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, HelpMessage = 'App ID corresponding to the AppInsight')]
        [string]$AppID = "",

		[Parameter(Mandatory = $false, HelpMessage = 'API Key with the relevant permission, for the AppInsight')]
        [string]$APIKey = "",

        [Parameter(Mandatory = $false, HelpMessage = 'Timespan for the query')]
        [string]$Timespan = "PT12H",
        
        [Parameter(Mandatory = $false, HelpMessage = 'Kusto Query to get the results of the Load Test')]
        [string]$KustoQueryName = "TestRunSummary",

        [Parameter(Mandatory = $false, HelpMessage = 'Path to JSON file containing query commands')]
        [string]$QueryCommandsPath = ".\QueryCommands.json"
    )

    # AppInsights URL 
    $SiteURL = "https://api.applicationinsights.io"

    # Get the required environment variables
    $LoadTestGuid = [System.Environment]::GetEnvironmentVariable('LoadTestGuid')  
    $LoadTestStartTime = [System.Environment]::GetEnvironmentVariable('LoadTestStartTime')
    $LoadTestStopTime = [System.Environment]::GetEnvironmentVariable('LoadTestStopTime')

    if ($AppID -eq "")
    {
        $AppID = [System.Environment]::GetEnvironmentVariable('AppInsightAppID')
    }

    if ($APIKey -eq "")
    {
        $APIKey = [System.Environment]::GetEnvironmentVariable('AppInsightAPIKey')
    }

    if($KustoQueryName -eq "TestRunSummary")
    {
       # KustoQuery to fetch the TestRunSummary results
       $ReadQuery = Get-Content $QueryCommandsPath | ConvertFrom-Json
       $KustoQuery = $ReadQuery.${KustoQueryName} -f $LoadTestGuid,$LoadTestStartTime,$LoadTestStopTime
    }

    # Encode Kusto Query into the URI space
    $URLQuery = [uri]::EscapeDataString($KustoQuery)		

    $SaveFileSuffix = "_{0}.txt" -f $KustoQueryName
    $SaveResults = (Get-Location).ToString() +"\out\" + `
                   (Get-Date -Format "dddd MM_dd_yyyy HH_mm").ToString() + $SaveFileSuffix

    # CURL command to fetch the results as a JSON object, and pretty print & pipe the JSON into an output file
    curl.exe "$SiteURL/v1/apps/$AppID/query?timespan=$Timespan&query=$URLQuery" -H "x-api-key: $APIKey" `
             | python -m json.tool | Out-File -FilePath $SaveResults
    
    [System.Environment]::SetEnvironmentVariable('LoadTestResultsFile', `
                                                 $SaveResults, `
                                                 [System.EnvironmentVariableTarget]::User)
                                             
    Write-Host "Results of the latest load test, TestGuid: $LoadTestGuid fetched and written to $SaveResults" `
                -ForegroundColor Green
}
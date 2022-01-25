<#
    Script to register and run startScaleTestAuto.ps1, stopScaleTestAuto.ps1 and queryResultsAuto.ps1 
    as Scheduled Tasks.

    Starts the Fluid Scale test at the StartTime specified, and stops the test at the specified StopTime.
    It then fetches the results of the scale test by running the queryResultsAuto.ps1 script at QueryTime.

    The times are in Coordinated Universal Time (UTC) unless specified otherwise.
#>

Param(
    [Parameter(Mandatory = $false, HelpMessage = 'Start time for the load test')]
    [string]$StartTime = "03:30 am",

    [Parameter(Mandatory = $false, HelpMessage = 'Location of the start script')]
    [string]$StartScriptPath = "C:\loadtest\startScaleTestAuto.ps1",

    [Parameter(Mandatory = $false, HelpMessage = 'Stop time for the load test')]
    [string]$StopTime = "01:30 pm",

    [Parameter(Mandatory = $false, HelpMessage = 'Location of the stop script')]
    [string]$StopScriptPath = "C:\loadtest\stopScaleTestAuto.ps1",

    [Parameter(Mandatory = $false, HelpMessage = 'Time at which load test results are to be fetched')]
    [string]$QueryTime = "02:00 pm",

    [Parameter(Mandatory = $false, HelpMessage = 'Location of the fetch results script')]
    [string]$QueryScriptPath = "C:\loadtest\queryResultsAuto.ps1"
)

function registerTask {
    <#
        .SYNOPSIS
            Registers the task with the given name, to be triggered at the specified time.

        .PARAMETER TaskName
            Name of the Scheduled Task
        
        .PARAMETER ScheduledTime
            Time at which the Scheduled Task is to be triggered
        
        .PARAMETER ScriptPath
            Path to the script that is to be executed as a scheduled task
    #>
    Param(
        [string]$TaskName,
        [Parameter()]
        [string]$ScheduledTime,
        [Parameter()]
        [string]$ScriptPath
    )

    # Initialize common variables
    $ExecProg = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" # Make sure this points to the appropriate location in your setup 
    $Principal = New-ScheduledTaskPrincipal -UserID "$($env:USERDOMAIN)\$($env:USERNAME)" `
    -LogonType ServiceAccount -RunLevel Highest
    $Settings = New-ScheduledTaskSettingsSet -Compatibility Win8
    
    # Execute Action at the given Trigger
    $Trigger = New-ScheduledTaskTrigger -Daily -At $ScheduledTime
    $Action = New-ScheduledTaskAction -Execute $ExecProg -Argument "-File $ScriptPath" 
    Register-ScheduledTask -TaskName $TaskName -Trigger $Trigger -Action $Action `
    -Principal $Principal -Settings $Settings
    $OutputMessage ="Successfully Registered the {0} Scheduled Task" -f $TaskName
    Write-Host $OutputMessage -ForegroundColor Green
}


# Register the Start-Load-Test task at the specified start time
registerTask -TaskName "Start-Load-Test" -ScheduledTime $StartTime -ScriptPath $StartScriptPath

# Register the Stop-Load-Test task at the specified stop time
registerTask -TaskName "Stop-Load-Test" -ScheduledTime $StopTime -ScriptPath $StopScriptPath

# Register the fetch results task at the specified time
registerTask -TaskName "Fetch-Load-Test-Results" -ScheduledTime $QueryTime -ScriptPath $QueryScriptPath


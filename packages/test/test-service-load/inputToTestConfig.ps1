Param(
    [Parameter(Mandatory = $false, HelpMessage = 'Number of documents to run test on.')]
    [ValidateRange(1, 2400)]
    [int]$NumOfDocs = 5,

    [Parameter(Mandatory = $false, HelpMessage = 'Profile to run test with.')]
    [string]$TestProfile = 'custom_profile',

    [Parameter(Mandatory = $false, HelpMessage = 'opRatePerMin')]
    [single]$opRatePerMin = 40.5,
 
    [Parameter(Mandatory = $false, HelpMessage = 'signalsPerMin')]
    [AllowNull()]
    [Nullable[single]]$signalsPerMin = $null,

    [Parameter(Mandatory = $false, HelpMessage = 'totalSignalsSendCount')]
    [AllowNull()]
    [Nullable[System.Int32]]$totalSignalsSendCount= $null,

    [Parameter(Mandatory = $false, HelpMessage = 'progressIntervalMs')]
    [int]$progressIntervalMs = 20000,

    [Parameter(Mandatory = $false, HelpMessage = 'numClients')]
    [int]$numClients = 10,

    [Parameter(Mandatory = $false, HelpMessage = 'totalSendCount')]
    [int]$totalOpsSendCount = 70000,

    [Parameter(Mandatory = $false, HelpMessage = 'readWriteCycleMs')]
    [int]$readWriteCycleMs = 30000,     

    [Parameter(Mandatory = $false, HelpMessage = 'faultInjectionMinMs')]
    [AllowNull()]
    [Nullable[System.Int32]]$faultInjectionMinMs = $null,
    
    [Parameter(Mandatory = $false, HelpMessage = 'faultInjectionMaxMs')]
    [AllowNull()]
    [Nullable[System.Int32]]$faultInjectionMaxMs = $null,

    [Parameter(Mandatory = $false, HelpMessage = 'Test Config File Path')]
    [string]$TestConfigFilePath = './testConfig.json',

    [Parameter(Mandatory = $false, HelpMessage = 'Specify operations send type mechanism')]
    [AllowNull()]
    [string]$opsSendType = $null
)        

$TestConfig = (get-Content -Path $TestConfigFilePath | ConvertFrom-Json)
$NonProfileParams = ('TestProfile', 'TestConfigFilePath', 'NumOfDocs')

# Get the command name and the parameter list
$CommandName = $PSCmdlet.MyInvocation.InvocationName
$ParameterList = (Get-Command -Name $CommandName).Parameters

# Grab each parameter value, using Get-Variable; Put it in $ProfileContent and add it to $TestConfig
$ProfileContent = New-Object -Type psobject
foreach ($Parameter in $ParameterList) {
    $InputParamNames = (Get-Variable -Name $Parameter.Values.Name -ErrorAction SilentlyContinue).Name
    foreach ($InputParam in $InputParamNames)
    {
        if ($NonProfileParams.contains($InputParam) -ne $True)
        {
            $InputParamValue = (Get-Variable -Name $InputParam -ErrorAction SilentlyContinue).Value
            if ($InputParamValue -ne $null)
            {
                $ProfileContent | Add-Member -MemberType NoteProperty `
                                -Name $InputParam -Value $InputParamValue -Force
            }
        }
    }
}
$TestConfig.profiles | Add-Member -MemberType NoteProperty `
                      -Name $TestProfile -Value $ProfileContent -Force
ConvertTo-Json -InputObject $TestConfig | Out-File -FilePath $TestConfigFilePath
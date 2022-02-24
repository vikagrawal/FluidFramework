<#
    Script to programmatically mail the results to 
    the specified users, at the end of a scale test run.

    Make sure that the appropriate environment variables are set.
#>

Param(  
    [Parameter(Mandatory = $false, HelpMessage = 'Mail Address of the Sender')]
    [string]$MailFrom = "<Sender Mail Address>",

    [Parameter(Mandatory = $false, HelpMessage = 'Mail Address of the Recipient')]
    [string]$MailTo = "<Recipient Mail Address>",

    [Parameter(Mandatory = $false, HelpMessage = 'Mail Address of Additional Recipient')]
    [string]$MailCC = "<Additional Mail Address>",

    [Parameter(Mandatory = $false, HelpMessage = 'Subject of the Mail')]
    [string]$MailSubject = "Scale Test Results",

    [Parameter(Mandatory = $false, HelpMessage = 'Full Path of the results file to be attached')]
    [string]$AttachmentPath = [System.Environment]::GetEnvironmentVariable('LoadTestResultsFile')
)

function Invoke-SetProperty {
    # Reflection to set the SendUsingAccount property
    Param(
        [__ComObject] $Object,
        [String] $Property,
        $Value
    )

    [Void] $Object.GetType().InvokeMember($Property,"SetProperty",$NULL,$Object,$Value)
}

function MailUsingOutlookPowershell {
    <#
        .SYNOPSIS
            Creates an Outlook COM Object, and sends a mail
            with the desired parameters.

            You should ensure that the Outlook client 
            is setup with the appropriate accounts
    #>
    $SendFromSmtpAddress = $MailFrom

    # Create COM object named Outlook
    $Outlook = New-Object -ComObject Outlook.Application
    $Account = $Outlook.session.accounts | ? { $_.smtpAddress -eq $SendFromSmtpAddress }

    # Create Outlook MailItem named Mail using CreateItem() method
    $Mail = $Outlook.CreateItem(0)

    # Add properties as desired
    $Mail.To = $MailTo
    $Mail.CC = $MailCC
    $Mail.Subject = $MailSubject
    $Mail.Body = $MailBody
    $Attachment = $AttachmentPath
    $Mail.Attachments.Add($Attachment)

    # Send message
    Invoke-SetProperty -Object $Mail -Property "SendUsingAccount" -Value $Account
    $Mail.Send()

    # Wait for sometime before quitting outlook
    Start-Sleep -Seconds (1*30)

    # Quit and Cleanup
    $Outlook.Quit() 
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($Outlook) | Out-Null
}

function MailUsingSendMailMessage {
    <#
        .SYNOPSIS
            Sends a mail using the `Send-MailMessage` cmdlet.
            Will be deprecated soon, so you should migrate to
            `MailUsingOutlookPowershell` above.

            You should ensure that the appropriate environment
            variables are set, and that the credentials are available.
    #>
    $PassLoc = [System.Environment]::GetEnvironmentVariable('MailFromPasswordPath')
    $Username = $MailFrom
    $Password = Get-Content $PassLoc | ConvertTo-SecureString
    $Cred = New-Object -typename System.Management.Automation.PSCredential `
            -argumentlist $Username, $Password

    $MailHash = @{
        To = $MailTo
        From = $MailFrom
        Subject = $MailSubject
        Body = $MailBody
        CC = $MailCC
        BodyAsHtml = $true
        SmtpServer = 'smtp.office365.com'
        UseSSL = $true
        Credential = $Cred
        Port = 587
        Attachments = $AttachmentPath
    }

    Send-MailMessage @MailHash
}

$TestGuid = [System.Environment]::GetEnvironmentVariable('LoadTestGuid')
$MailBody = "Results of the Load Test with GUID: {0}" -f $TestGuid

<# 
    TO-DO: Deprecate this shortly, and use the alternative `MailUsingOutlookPowershell` 
    for the programmatic mailer after setting up the appropriate account(s) on Outlook.
#>
Write-Host "Mailing the results of the load test" -ForegroundColor Green
MailUsingSendMailMessage 
#MailUsingOutlookPowershell
Write-Host "Successfully mailed the results of the load test" -ForegroundColor Green

<#
    Acknowledgements:
    [1] https://gist.github.com/ClaudioESSilva/dfaf1de2e5da88fca1e59f70edd7f4ae [ClaudioESSilva] [Mail with Outlook Powershell]
    [2] https://sid-500.com/2020/08/25/microsoft-365-send-e-mails-with-powershell/ [Patrick Gruenauer] [Mail with Send-MailMessage]
#>
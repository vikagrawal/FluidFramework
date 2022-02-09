<#
    Helper script to read in the password for the automatic mailer,
    and save the path to the password (stored as a secure string),
    as an appropriate environment variable.
#>

$PasswordLocation = (Get-Location).ToString() + "\Upass.txt"
# Enter the password, to be stored as a secure string
Write-Host "Enter the password for the automatic mailer" -ForegroundColor Cyan
read-host -assecurestring | convertfrom-securestring | out-file $PasswordLocation
# Store the location of the password in an environment variable
[System.Environment]::SetEnvironmentVariable('MailFromPasswordPath', `
                                             $PasswordLocation, `
                                             [System.EnvironmentVariableTarget]::User)
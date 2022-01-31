<#
    Script to merge the changes in main branch with the loadtest branch at the specified time, 
    to generate updated builds.

    Ensure that remote origin and remote upstream point to appropriate repositories.

    Merge conflicts need to be resolved manually.
#>

Param(
    [Parameter(Mandatory = $false, HelpMessage = 'Fluid Framework CodeBase Directory')]
    [string]$LoadTestDir = "C:\FluidFrameworkCodebase\FluidFramework"
)

# Make sure this points to the right directory in your local setup (wherever the load test scripts are present)
cd $LoadTestDir

Write-Host "Checkout local main branch" -ForegroundColor "Green"
git checkout main
Write-Host "Pull the changes from upstream main" -ForegroundColor "Green"
git pull upstream main
Write-Host "Push the changes to origin main" -ForegroundColor "Green"
git push origin main
Write-Host "Checkout local loadtest branch" -ForegroundColor "Green"
git checkout loadtest/main

# Merge conflicts would need to be resolved manually
Write-Host "Merge the changes made in the main branch, with the loadtest branch" -ForegroundColor "Green"
git merge main
Write-Host "Push changes from local loadtest branch to the branch in remote origin" -ForegroundColor "Green"
git push origin loadtest/main
Write-Host "Changes updated successfully" -ForegroundColor "Green"
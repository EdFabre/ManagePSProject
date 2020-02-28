$modulespath = ($env:psmodulepath -split ";")[0]
$manageprojectpath = "$modulespath\manageproject"

Write-Host "Creating module directory"
New-Item -Type Container -Force -path $manageprojectpath | out-null

Write-Host "Downloading and installing"
(new-object net.webclient).DownloadString("https://raw.githubusercontent.com/EdFabre/ManageProject/master/ManageProject.psm1") | Out-File "$manageprojectpath\ManageProject.psm1" 

Write-Host "Installed!"
Write-Host 'Use "Import-Module ManageProject" to import the module'
Write-Host 'Use "ManageProject -Init" to run the module'
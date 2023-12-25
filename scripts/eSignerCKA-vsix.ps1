# Define SSLcom account
$Username = "esigner_demo"
$Password = "esignerDemo#1"
$SecretCode = "RDXYgV9qju+6/7GnMf1vCbKexXVJmUVr+86Wq/8aIGg="
$TimestampUrl = "http://ts.ssl.com"

# Define eSignerCKA paths
$DesktopPath = "$HOME\Desktop"
$DotnetTools = "$DesktopPath\dotnet-tools"
$InputFile = "C:\Data\SSLcom.vsix"
$MasterKeyFile = "C:\eSignerCKA\master.key"
$InstallDir = "C:\eSignerCKA"
$InstallCKA = "True" #True for Install eSignerCKA
$UseLatestTool = "False" #False for v0.3.2

If ($InstallCKA -eq "True")
{
    # Download and Extract eSignerCKA
    Invoke-WebRequest -OutFile eSigner_CKA_Setup.zip "https://www.ssl.com/download/ssl-com-esigner-cka"
    Expand-Archive -Force eSigner_CKA_Setup.zip
    Remove-Item "eSigner_CKA_Setup.zip"
    If (Test-Path "eSigner_CKA_Installer.exe")
    {
        Remove-Item "eSigner_CKA_Installer.exe"
    }
    Move-Item -Destination "eSigner_CKA_Installer.exe" -Path "eSigner_CKA_*\*.exe"
    New-Item -ItemType Directory -Force -Path ${InstallDir}

    # Install eSignerCKA
    ./eSigner_CKA_Installer.exe /CURRENTUSER /VERYSILENT /SUPPRESSMSGBOXES /DIR="${InstallDir}" | Out-Null
    Remove-Item ./eSigner_CKA_Installer.exe
}

# Load Certificate
$mode = "sandbox" # For Production Certificate it must be "product"
& ${InstallDir}\eSignerCKATool.exe config -mode $mode -user "$Username" -pass "$Password" -totp "$SecretCode" -key "$MasterKeyFile" -r
& ${InstallDir}\eSignerCKATool.exe unload
& ${InstallDir}\eSignerCKATool.exe load

# Select Certificate from Windows Store
$CodeSigningCert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | WHERE { $_.subject -Match "Esigner" }
$Thumbprint = $( $CodeSigningCert.Thumbprint )
Write-Output $Thumbprint

# Install OpenVsixSignTool to Custom Location
# This command installs the old version of OpenVsixSignTool. Normal machines don't have a problem. However,
# in CI/CD tools such as github, gitlab, the old version of OpenVsixSignTool package
# 'Unhandled exception. System.Security.Cryptography.CryptographicException: The requested operation is not supported.'
# gives the error. Therefore, the OpenVsixSignTool tool (Latest version) in the zip file in the SSLcom repo can be used in case of errors.
If ($UseLatestTool -eq "False")
{
    # Install dotnet sdk
    Invoke-WebRequest 'https://dot.net/v1/dotnet-install.ps1' -OutFile 'dotnet-install.ps1';
    ./dotnet-install.ps1 -InstallDir '~/.dotnet' -Version '7.0.400'
    Remove-Item ./dotnet-install.ps1 -Force

    # Install OpenVsixSignTool 0.3.2
    dotnet tool install --global OpenVsixSignTool
    $RunCommand = "OpenVsixSignTool"
}
else
{
    # Install dotnet runtime
    Invoke-WebRequest 'https://dot.net/v1/dotnet-install.ps1' -OutFile 'dotnet-install.ps1';
    ./dotnet-install.ps1 -InstallDir '~/.dotnet' -Version '7.0.2' -Runtime 'dotnet'
    Remove-Item ./dotnet-install.ps1 -Force

    # Install Latest version of OpenVsixSignTool
    New-Item -ItemType Directory -Force -Path ${DotnetTools}
    Invoke-WebRequest -OutFile OpenVsixSignTool.zip "https://github.com/SSLcom/eSignerCKA/releases/download/v1.0.4/OpenVsixSignTool_1.0.0-x64.zip"
    Move-Item -Path OpenVsixSignTool.zip -Destination ${DotnetTools}\OpenVsixSignTool.zip
    Expand-Archive -LiteralPath ${DotnetTools}\OpenVsixSignTool.zip -DestinationPath ${DotnetTools} -Force
    Remove-Item ${DotnetTools}\OpenVsixSignTool.zip -Force
    $RunCommand = "${DotnetTools}/OpenVsixSignTool"
}

# For Windows 10 and Server 2019
$env:DOTNET_ROOT="%USERPROFILE%\.dotnet";

# Sign using OpenVsixSignTool command
# -Force option: Force the signature by overwriting any existing signatures.
& ${RunCommand} --roll-forward LatestMajor sign --sha1 $Thumbprint --timestamp ${TimestampUrl} -ta sha256 -fd sha256 ${InputFile} --force

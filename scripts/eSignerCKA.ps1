$Username="esigner_demo"
$Password="esignerDemo#1"
$SecretCode="RDXYgV9qju+6/7GnMf1vCbKexXVJmUVr+86Wq/8aIGg="
$TimestampUrl="http://ts.ssl.com"

# Define eSignerCKA paths
$InputFile = "C:\Data\Default.app"
$MasterKeyFile = "C:\eSignerCKA\master.key"
$INSTALL_DIR="C:\eSignerCKA"

# Download and Extract eSignerCKA
Invoke-WebRequest -OutFile eSigner_CKA_Setup.zip "https://www.ssl.com/download/ssl-com-esigner-cka"
Expand-Archive -Force eSigner_CKA_Setup.zip
Remove-Item "eSigner_CKA_Setup.zip"
If (Test-Path "eSigner_CKA_Installer.exe") {
    Remove-Item "eSigner_CKA_Installer.exe"
}
Move-Item -Destination "eSigner_CKA_Installer.exe" -Path "eSigner_CKA_*\*.exe"
New-Item -ItemType Directory -Force -Path ${INSTALL_DIR}

# Install eSignerCKA
./eSigner_CKA_Installer.exe /CURRENTUSER /VERYSILENT /SUPPRESSMSGBOXES /DIR="${INSTALL_DIR}" | Out-Null
Remove-Item ./eSigner_CKA_Installer.exe

# Load Certificate
$mode="sandbox" # For Production Certificate it must be "product"
& ${INSTALL_DIR}\eSignerCKATool.exe config -mode $mode -user "$Username" -pass "$Password" -totp "$SecretCode" -key "$MasterKeyFile" -r
& ${INSTALL_DIR}\eSignerCKATool.exe unload
& ${INSTALL_DIR}\eSignerCKATool.exe load

# Select Certificate from Windows Store
$CodeSigningCert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Select-Object -First 1
$Thumbprint=$($CodeSigningCert.Thumbprint)
Write-Output $Thumbprint

# Sign using SignTool command
& "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22000.0\x86\signtool.exe" sign /fd sha256 /tr ${TimestampUrl} /td sha256 /sha1 "${Thumbprint}" "${InputFile}"

pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: "5"))
        disableConcurrentBuilds()
    }

    // Create an environment variable
    environment {
        USERNAME          = credentials('es-username')       // SSL.com account username.
        PASSWORD          = credentials('es-password')       // SSL.com account password.
        TOTP_SECRET       = credentials('es-totp-secret')    // OAuth TOTP Secret (https://www.ssl.com/how-to/automate-esigner-ev-code-signing)
        ENVIRONMENT_NAME  = 'sandbox'                        // SSL.com Environment Name. For Demo Account It can be 'sandbox' otherwise it will be 'product'
    }

    stages {
        // 1) Create Artifact Directory for store signed and unsigned artifact files
        stage('Prepare for Signing') {
            steps {
                powershell 'New-Item -ItemType Directory -Force -Path ${WORKSPACE}\\eSignerCKA'
            }
        }

        // 2) Download and Install eSignerCKA
        stage('Download and Install eSignerCKA') {
            steps {
                powershell """
                    Invoke-WebRequest -OutFile eSigner_CKA_Setup.zip "https://www.ssl.com/download/ssl-com-esigner-cka"
                    Expand-Archive -Force eSigner_CKA_Setup.zip
                    Remove-Item eSigner_CKA_Setup.zip
                    Move-Item -Force -Destination "eSigner_CKA_Installer.exe" -Path "eSigner_CKA_*\\*.exe"
                    ./eSigner_CKA_Installer.exe /CURRENTUSER /VERYSILENT /SUPPRESSMSGBOXES /DIR="${WORKSPACE}\\eSignerCKA" | Out-Null
                """
            }
        }

       // 3) Setup eSignerCKA Dependency
       stage('Setup eSignerCKA Dependency') {
          steps {
              powershell """
                    Start-Process ".\\setup\\vc_redist.x86.exe" -argumentlist "/install /q" -wait
                    Start-Process ".\\setup\\vc_redist.x64.exe" -argumentlist "/install /q" -wait
                    Start-Process "${WORKSPACE}\\eSignerCKA\\RegisterKSP.exe" -wait
                    Start-Process "${WORKSPACE}\\eSignerCKA\\eSignerCSP.Config.exe" -wait
              """
          }
       }

       // 4) Setup eSignerCKA and Load Certificates
       stage('Setup eSignerCKA in Silent Mode') {
           steps {
               powershell """
                    ${WORKSPACE}\\eSignerCKA\\eSignerCKATool.exe config -mode $ENVIRONMENT_NAME -user "$USERNAME" -pass "$PASSWORD" -totp "$TOTP_SECRET" -key "${WORKSPACE}\\eSignerCKA\\master.key" -r
                    ${WORKSPACE}\\eSignerCKA\\eSignerCKATool.exe unload
                    ${WORKSPACE}\\eSignerCKA\\eSignerCKATool.exe load
               """
           }
       }

       // 5) Install OpenVsixSignTool to Custom Location
       stage('Install OpenVsixSignTool to Custom Location') {
            steps {
               powershell '''
                    New-Item -ItemType Directory -Force -Path ${WORKSPACE}\\dotnet-tools
                    Invoke-WebRequest -OutFile OpenVsixSignTool.zip https://github.com/SSLcom/eSignerCKA/releases/download/v1.0.4/OpenVsixSignTool_1.0.0-x86.zip
                    Move-Item -Path OpenVsixSignTool.zip -Destination ${WORKSPACE}\\dotnet-tools\\OpenVsixSignTool.zip -Force
                    Expand-Archive -LiteralPath ${WORKSPACE}\\dotnet-tools\\OpenVsixSignTool.zip -DestinationPath ${WORKSPACE}\\dotnet-tools -Force
               '''
            }
       }

       // 6) Download and Unzip Dynamics 365 Setup and Install Dynamics 365
      stage('Download and Unzip Dynamics 365 Setup and Install Dynamics 365') {
           steps {
              powershell """
                  Invoke-WebRequest -OutFile Dynamics.365.BC.12841.US.DVD.zip "https://download.microsoft.com/download/3/e/7/3e71083e-6cd6-4598-a6bb-5c602b74aec3/Release/Dynamics.365.BC.12841.US.DVD.zip"
                  Expand-Archive -Force Dynamics.365.BC.12841.US.DVD.zip
                  Start-Process ".\\Dynamics.365.BC.12841.US.DVD\\setup.exe" -argumentlist "/config .\\Dynamics.365.BC.12841.US.DVD\\Install-NavComponentConfig.xml /quiet" -wait
              """
           }
       }

       // 5) Select Certificate and Sign DLL File with SignTool
       stage('Sign DLL File with SignTool') {
           steps {
               powershell '''
                    $CodeSigningCert = Get-ChildItem Cert:\\CurrentUser\\My -CodeSigningCert | WHERE { $_.subject -Match "Esigner" }; echo $CodeSigningCert.Thumbprint > .Thumbprint
                    Set-Variable -Name Thumbprint -Value (Get-Content .Thumbprint); echo $Thumbprint
                    & "C:/Program Files (x86)/Windows Kits/10/bin/10.0.22000.0/x86/signtool.exe" sign /debug /fd sha256 /tr http://ts.ssl.com /td sha256 /sha1 $Thumbprint HelloWorld.dll
               '''
           }
           post {
               always {
                   archiveArtifacts artifacts: "HelloWorld.dll", onlyIfSuccessful: true
               }
           }
       }

       // 6) Select Certificate and Sign VSIX File with SignTool
       stage('Sign VSIX File with SignTool') {
           steps {
               powershell '''
                    $CodeSigningCert = Get-ChildItem Cert:\\CurrentUser\\My -CodeSigningCert | WHERE { $_.subject -Match "Esigner" }; echo $CodeSigningCert.Thumbprint > .Thumbprint
                    Set-Variable -Name Thumbprint -Value (Get-Content .Thumbprint); echo $Thumbprint
                    & "${WORKSPACE}/dotnet-tools/OpenVsixSignTool" --roll-forward LatestMajor sign --sha1 $Thumbprint --timestamp http://ts.ssl.com -ta sha256 -fd sha256 SSLcom.vsix
               '''
           }
           post {
               always {
                   archiveArtifacts artifacts: "SSLcom.vsix", onlyIfSuccessful: true
               }
           }
       }

       // 7) Select Certificate and Sign APP File with SignTool
       stage('Sign APP File with SignTool') {
           steps {
               powershell '''
                    $CodeSigningCert = Get-ChildItem Cert:\\CurrentUser\\My -CodeSigningCert | WHERE { $_.subject -Match "Esigner" }; echo $CodeSigningCert.Thumbprint > .Thumbprint
                    Set-Variable -Name Thumbprint -Value (Get-Content .Thumbprint); echo $Thumbprint
                    & "C:/Program Files (x86)/Windows Kits/10/bin/10.0.22000.0/x86/signtool.exe" sign /debug /fd sha256 /tr http://ts.ssl.com /td sha256 /sha1 $Thumbprint HelloWorld.dll
               '''
           }
           post {
               always {
                   archiveArtifacts artifacts: "HelloWorld.app", onlyIfSuccessful: true
               }
           }
       }
    }
}

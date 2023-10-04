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

       // 3) Setup eSignerCKA and Load Certificates
       stage('Setup eSignerCKA in Silent Mode') {
           steps {
               powershell """
                    ${WORKSPACE}\\eSignerCKA\\eSignerCKATool.exe config -mode $ENVIRONMENT_NAME -user "$USERNAME" -pass "$PASSWORD" -totp "$TOTP_SECRET" -key "${WORKSPACE}\\eSignerCKA\\master.key" -r
                    ${WORKSPACE}\\eSignerCKA\\eSignerCKATool.exe unload
                    ${WORKSPACE}\\eSignerCKA\\eSignerCKATool.exe load
               """
           }
       }

       // 4) Select Certificate and Sign Sample File with SignTool
       stage('Sign Sample File with SignTool') {
           steps {
               powershell '''
                    $CodeSigningCert = Get-ChildItem Cert:\\CurrentUser\\My -CodeSigningCert | Select-Object -First 1; echo $CodeSigningCert.Thumbprint > .Thumbprint
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
    }
}

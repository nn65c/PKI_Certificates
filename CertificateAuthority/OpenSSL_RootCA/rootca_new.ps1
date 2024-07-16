# Frode Hansen, 12.07.2024
throw "*** Stop running all commands in script ***"

# Create directories and files if not existing.
New-Item -ItemType Directory -Path "private", "database", "database\newcerts" -ErrorAction SilentlyContinue
if (-not(Test-Path "database\serial.txt")) { openssl rand -hex 16 | Out-File "database\serial.txt" -Encoding ascii } 
if (-not(Test-Path "database\index.txt")) { New-Item -ItemType File -Path "database\index.txt" }

# Private key encrypted with password. Keep file in a safe place and do not
# forget password. It may be changed, but not recovered.
openssl genrsa -out private/rootca.key -aes256 4096

# Self-sign Root CA.
openssl req -new -x509 -config rootca_new.conf -days 3650 -key private\rootca.key -out rootca.crt 

# View certificate.
openssl x509 -in rootca.crt -noout -text

# Import certificate. Current User
Import-Certificate -FilePath rootca.crt -CertStoreLocation Cert:\CurrentUser\Root\

# Or, import certificate. Local Machine
Import-Certificate -FilePath rootca.crt -CertStoreLocation Cert:\LocalMachine\Root\

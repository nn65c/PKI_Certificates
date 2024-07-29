# Frode Hansen, 12.07.2024
throw "*** Stop running all commands in script ***"

# Create directories and files if not existing.
New-Item -ItemType Directory -Path "private", "database", "database\newcerts" -ErrorAction SilentlyContinue
if (-not(Test-Path "database\serial.txt")) { openssl rand -hex 16 | Out-File "database\serial.txt" -Encoding ascii } 
if (-not(Test-Path "database\index.txt")) { New-Item -ItemType File -Path "database\index.txt" }

# Private key encrypted with password. Keep file in a safe place and do not
# forget password. It may be changed, but not recovered.
openssl genrsa -out private/subca.key -aes256 2048

# New Certificate Signing Request (CSR)
openssl req -new -key private/subca.key -out subca.csr -config subca_new.conf

# View CSR.
openssl req -in subca.csr -noout -text

# Send CSR to CA for signing. CA returns file 'subca.crt'.
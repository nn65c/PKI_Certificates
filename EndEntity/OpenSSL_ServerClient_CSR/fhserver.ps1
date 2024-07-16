# Frode Hansen, 12.07.2024
throw "*** Stop running all commands in script ***"

# Private key not encrypted with password. Keep file in a safe place.
openssl genrsa -out server.key 3072

# New Certificate Signing Request (CSR)
openssl req -new -key server.key -out server.csr -config fhserver.conf

# Send CSR to CA for signing. CA returns file 'server.crt'.

# Get password for PFX file.
$pass = Get-Credential -Message "PFX export password" -UserName "PFX export"

# Convert to PFX for import cert with private key in certificate store
openssl pkcs12 -export -out server.pfx -inkey server.key -in server.crt -password pass:$($pass.GetNetworkCredential().Password)

# Import certificate. Current User
Import-PfxCertificate -FilePath server.pfx -CertStoreLocation Cert:\CurrentUser\My -Password $pass.Password

# Or, import certificate. Local Machine
Import-PfxCertificate -FilePath server.pfx -CertStoreLocation Cert:\LocalMachine\My -Password $pass.Password

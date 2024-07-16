# Frode Hansen, 12.07.2024
throw "*** Stop running all commands in script ***"

# Private key encrypted with password. Keep file in a safe place and do not
# forget password. It may be changed, but not recovered.
openssl genrsa -out fhcodesign.key -aes256 4096

# New Certificate Signing Request (CSR)
openssl req -new -key fhcodesign.key -out fhcodesign.csr -config fhcodesign.conf

# Send CSR to CA for signing. CA returns file 'fhcodesign.crt'.

# Get password for PFX file.
$pass = Get-Credential -Message "PFX export password" -UserName "PFX export"

# Convert to PFX for import cert with private key in certificate store
openssl pkcs12 -export -out fhcodesign.pfx -inkey fhcodesign.key -in fhcodesign.crt -password pass:$($pass.GetNetworkCredential().Password)

# Import certificate
$cert = Import-PfxCertificate -FilePath fhcodesign.pfx -CertStoreLocation Cert:\CurrentUser\My -Password $pass.Password

# Or retreive from certificate store
#$cert = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Subject -like "CN=_FH Code Signing*" }

# Sign script (ie. New-CsrEndEntity.ps1). Should state Status = Valid if 
# Root CA is installed in Trusted Root Certification Authorities"
$timestampServer = "http://timestamp.digicert.com"
Set-AuthenticodeSignature -FilePath New-CsrEndEntity.ps1 -Certificate $cert -TimestampServer $timestampServer -HashAlgorithm sha256 -IncludeChain all


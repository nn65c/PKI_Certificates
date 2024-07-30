# Frode Hansen, 30.07.2024
throw "*** Stop running all commands in script ***"

# New Certificate Signing Request (CSR) with all settings from config file
# 'fhreqserver.inf'
certreq -new fhreqserver.inf server.csr

# Successful certreq command will place request in 'Certificate Enrollment 
# Requests' in 'Certificte Store'. This will include the private key.

# Send CSR to CA for signing. CA returns file 'server.crt'. Import this
# certificate file to 'Personal' in the same 'Certificate Store' 
# (LocalMachine/CurrentUser) as the CSR is placed. This will merge the signed
# public certificate 'server.crt' with the CSR and private key.  

# Import certificate. Current User
Import-Certificate -FilePath server.crt -CertStoreLocation Cert:\CurrentUser\My

# Or, import certificate. Local Machine
Import-Certificate -FilePath server.crt -CertStoreLocation Cert:\LocalMachine\My

# Frode Hansen, 12.07.2024
throw "*** Stop running all commands in script ***"

# Sign Certificate Signing Request (CSR)
openssl ca -config subca_sign.conf -days 365 -notext -in server.csr -out server.crt 

# View certificate
openssl x509 -in server.crt -noout -text
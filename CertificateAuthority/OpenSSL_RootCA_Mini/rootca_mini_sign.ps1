# Frode Hansen, 12.07.2024
throw "*** Stop running all commands in script ***"

# Sign Certificate Signing Request (CSR)
openssl x509 -req -CA rootca_mini.crt -CAkey rootca_mini.key -copy_extensions copy -days 365 -in server.csr -out server.crt

# View certificate
openssl x509 -in server.crt -noout -text

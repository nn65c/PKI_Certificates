# Frode Hansen, 12.07.2024
throw "*** Stop running all commands in script ***"

# Private key encrypted with password. Keep file in a safe place and do not
# forget password. It may be changed, but not recovered.
openssl genrsa -out rootca_mini.key -aes256 2048

# Create self-signed Root CA.
openssl req -new -x509 -key rootca_mini.key -subj "/CN=_FH Minimal Root CA/O=nn65c" -days 3650 -out rootca_mini.crt

# View certificate.
openssl x509 -in rootca_mini.crt -noout -text

# Import certificate. Current User
Import-Certificate -FilePath rootca_mini.crt -CertStoreLocation Cert:\CurrentUser\Root\

# Or, import certificate. Local Machine
Import-Certificate -FilePath rootca_mini.crt -CertStoreLocation Cert:\LocalMachine\Root\

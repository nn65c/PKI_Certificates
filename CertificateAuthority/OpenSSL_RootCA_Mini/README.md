# Root Certificate Authority (CA) - OpenSSL Minimal

Dette er et minimalt oppsett med Root CA som kan brukes i testmiljø.

## [Opprette Root CA](rootca_mini_new.ps1)
Lager **private key** og **public certificate** for Root CA som kan brukes til å signere **Certificate Signing Request** fra annen enhet. Dette kan være CA (Subordinate/Intermediate) eller End-entity (Server, Client, Code Signing...).

**Public certificate** som opprettes må installeres i "Trusted Root Certification Authorities" i "Certificate store" på alle maskiner som skal benytte dette Root CA.

For "Current User":

    Import-Certificate -FilePath rootca_mini.crt -CertStoreLocation Cert:\CurrentUser\Root\

Eller for "Local Machine". Kjør som administrator:

    Import-Certificate -FilePath rootca_mini.crt -CertStoreLocation Cert:\LocalMachine\Root\

## [Signere Certificate Signing Request (CSR)](rootca_mini_sign.ps1)
Root CA mottar en CSR (`server.csr`) fra annen enhet, og kan signere denne med sin **private key**. Signert fil (`server.crt`) returneres til avsender av CSR og vil være **public certificate** der. Enhet har allerede laget **private key** lokalt, og filen kan importeres i "Personal" i enhetes sin "Certificate store".

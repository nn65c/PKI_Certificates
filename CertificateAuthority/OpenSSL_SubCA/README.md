# Intermediate/Subordinate Certificate Authority (CA) - OpenSSL

Eksempel på oppsett for Sub CA der OpenSSL har oversikt over alle sertifikater som er utstedt. 

## [Opprette Sub CA](subca_new.ps1)
Lager **private key** som lagres lokalt og beskyttes. Deretter lages **Certificate Signing Request** som sendes til Root CA for signering. Root CA returnerer **public certificate** for Sub CA, og dette, sammen med **private key**, kan brukes til å signere **Certificate Signing Request** fra End-entity (Server, Client, Code Signing...).

**Public certificate** for Sub CA distribueres normalt ikke til "Certificate store" på andre maskiner, men kjedes sammen med sertifikat fra End-entity og presenteres derfra. Det er bare **public certificate** for Root CA som må være være på plass i "Trusted Root Certification Authorities" i "Certificate store" på alle maskiner som skal benytte sertifikater signert av denne Sub CA. På denne måten er det mulig å verifisere hele kjeden fra End-entity via Sub CA opp til Root CA.

## [Signere Certificate Signing Request (CSR) fra End-entity](subca_sign.ps1)
Sub CA mottar en CSR (`server.csr`) fra annen enhet, og kan signere denne med sin **private key**. Signert fil (`server.crt`) returneres til avsender av CSR og vil være **public certificate** der. Enhet har allerede laget **private key** lokalt, og filen kan importeres i "Personal" i enhetes sin "Certificate store".
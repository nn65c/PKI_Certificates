# End-entity (Server) - Powershell

En CSR kan lages med Powershell. Dette vil gi tilsvarende resultat som ved bruk av [Windows GUI](../WindowsGUI_ServerClient_CSR/README.md).

Beskrivelse viser til funksjon `New-CsrEndEntity`i filen [New-CsrEndEntity.ps1](New-CsrEndEntity.ps1). Denne funksjonen kan gjøres tilgjengelig ved å 'dot-source' filen. Hvis det skal lages CSR for LocalMachine, må Powershell sesjon kjøres som administrator.

Powershell som administrator:

    . .\New-CsrEndEntity.ps1

## Certificate Signing Request (CSR) - Automatisk

Funkjsonen `New-CsrEndEntity` kan finne en del informasjon fra maskinen den kjøres på. Dette gjør at man normalt kan kjøre den uten parametre:

    New-CsrEndEntity -Verbose

`-Verbose` er ikke påkrevd, men det viser informasjon om hva som benyttes i CSR som produseres.

Funksjonen vil lage CSR i en egen mappe i **Certificate store**. Dette er **Certificate Enrollment Requests**. Hvis den ikke vises. kan man oppdatere ved å velge **Refresh** på **Certificates - Local Computer**.

![alt text](<../WindowsGUI_ServerClient_CSR/image/13 CSR Certificate Enrollment Requests.png>)

I tillegg vil den lagre en fil med CSR i samme mappe som funksjonen kjøres fra:

![alt text](<../WindowsGUI_ServerClient_CSR/image/15 CSR Exported file.png>)

## Certificate Signing Request (CSR) - Manuelt

Funkjsonen `New-CsrEndEntity` har en del parametere som kan spesifiseres. Dette kan brukes hvis CSR skal lages for annen maskin enn der funkjsonen kjøres.

Powershell. Ikke behov for å kjøre som administrator:

    New-CsrEndEntity -Subject "w22server1.dom23.local" -DnsName "w22server1.dom23.local", "w22server1" -FriendlyName "Server, w22server1 PS" -KeyLength 3072 -IPAddress "192.168.17.238" -OutFile "server.csr" -Context CurrentUser

Alternativt kan dette kjøres:

    $params = @{
        Subject              = "w22server1.dom23.local"
        DnsName              = @("w22server1.dom.local", "w22server1")
        IPAddress            = @("192.168.17.238")
        FriendlyName         = "Server, w22server.dom23.local PS"
        KeyLength            = 3072
        EndEntityType        = "Server"
        Context              = "LocalMachine"
        PrivateKeyExportable = $true
        Force                = $true
        OutFile              = "server.csr"
    }

    New-CsrEndEntity @params

## Import sertifikat etter signering

CSR-fil (`server.csr`) sendes til CA som kan signere denne. CA sender `server.crt` i retur. Denne importeres i Current User eller Local Machine avhengig av hvor CSR ble opprettet.

Current User:

    Import-Certificate -FilePath server.crt -CertStoreLocation Cert:\CurrentUser\My\

Eller Local Machine. Kjør som administrator:
 
    Import-Certificate -FilePath server.crt -CertStoreLocation Cert:\LocalMachine\My\

Dette vil koble **private key** i forespørsel som ligger i **Certificate Enrollment Requests** og komplett sertifikat ligger i **Personal** i **Certificate store**. 

![alt text](<../WindowsGUI_ServerClient_CSR/image/19 CRT moved to Personal.png>)

Hvis Root CA som har signert sertifikatet allerede ligger i **Trusted Root Certification Authorities** vil sertifikatet vise at det inkluderer **private key**.

![alt text](<../WindowsGUI_ServerClient_CSR/image/23 CRT Valid with private key.png>)
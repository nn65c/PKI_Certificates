# End-entity (Server) - Windows GUI

CSR kan lages for lokal maskin via **Manage computer certificates**. Hvis denne guide følges, vil **private key** aldri forlate maskinen, og sertifikat kan installeres komplett etter at en Certificate Authority (CA) har signert CSR.

![alt text](<image/00 Manage computer certificates.png>)

Det er mulig å lage CSR som ikke er beregnet for lokal maskin også. Da må det ferdige sertifikatet med **private key** eksporteres, flyttes til riktig maskin og importeres der. Da kan prosessen med å lage CSR gjøres som CurrentUser (Manage user certificates), dvs. det er ikke behov å kjøre som administrator. Import på annen maskin skal som regel inn LocalMachine, og det krever å kjøre som administrator.

Prosedyren via GUI er omfattende. Det er mulig å [automatisere med Powershell](../Powershell_ServerClient_CSR/README.md).

## Certificate Signing Request (CSR)
Høyre-klikk på **Personal** og velg **All Tasks->Advanced Operations->Create Custom Request...**

![alt text](<image/01 CSR Start.png>)

Velg **Custom Request->Proceed without enrollment policy**

![alt text](<image/02 CSR Without policy.png>)

La valg stå til standard for **Custom request**. Dvs. **(No template) CNG key** og **PKCS #10** format.

![alt text](<image/03 CSR Format PKCS10.png>)

Velg den lille dropdown pilen oppe til høyre i **Certificate Information**. Da skal valg for **Properties** gjøres tilgjengelig.

![alt text](<image/04 CSR Properties.png>)

Legg inn **Friendly name** under **Certificate Properties->General**. Dette er ikke en egenskap som ligger i selve sertifikatet, men informasjon som kan endres etter at signert sertifikat er på plass. 

![alt text](<image/05 CSR General.png>)

Velg Type **Common Name** under **Subject name** og legg til lokalt maskinnavn. Dette er normalt fullt maskinnavn for maskin i domene, eller NetBIOS navn for workgroup. Velg **Add>** for å flytte over på listen til høyre.

Velg Type **DNS** under **Alternative name**, og legg til alle navn som skal benyttes for denne maskin. Dette vil være **Subject Alternative Name (SAN)** som angir hvilke servernavn som skal benyttes for denne maskin. Hvis sertifikat skal benyttes for webserver, vil det være dette som weblesere sjekker for å godkjenne sertifikatet.

Velg Type **IP address (v4)** for å legge til IP-adresser hvis det er behov for det. Weblesere vil godkjenne dette også. 

I eksempel vil følgende adresser godkjennes av webleser:
- https://w22server1.dom23.local
- https://w22server1
- https://192.168.17.238

![alt text](<image/06 CSR Subject.png>)

Legg til **Digital signature**, **Key agreement** og **Key encipherment** under **Extensions->Key usage**. Sett også **Make these key usages critical**.

![alt text](<image/07 CSR Extensions, Key usage.png>)

Legg til **Server Authentication** under **Extensions->Extended Key Usage (application policies)**.

![alt text](<image/08 CSR Extensions, Extended key usage.png>)

Velg **Enable this extension** under **Basic constraints**. **Allow subject to issue certificate** skal være av, og **Make subject constraints extension critical bør være på**.

![alt text](<image/09 CSR Extensions, Basic constraints.png>)

La **Cryptographic service** provider stå til **RSA, Microsoft Software Key Storage Provider** under **Private Key->Cryptographic Service Provider**.

![alt text](<image/10 CSR Private key, Cryptographic Service Provider.png>)

Sett **Key size** til f.eks. 2048 under **Key options**. 

Hvis CSR lages for **Local Machine** på maskinen sertifikatet faktisk skal brukes på, bør det ikke være behov for å eksportere private key. La derfor alle avkryssinger være av.

Hvis sertifikat lages under **Current User** og ikke **Local Machine**, og planen er å flytte sertifikat etterpå, må valget **Make private key exportable** aktiveres. Det gjelder også hvis CSR lages for en annen maskin.

Sett **Hash Algorithm** til **sha256** under **Select Hsh Algorithm**.

![alt text](<image/11 CSR Private key, Key options Hash.png>)

Lagre fil i **Base 64** format.

![alt text](<image/12 CSR Save offline request.png>)

Når denne prosedyre er gjennomført, vil CSR ligge i en egen mappe i **Certificate store**. Dette er **Certificate Enrollment Requests**. Hvis den ikke vises. kan man oppdatere ved å velge **Refresh** på **Certificates - Local Computer**.

Dette er midlertidig plassering inntil en Certificate Authority (CA) har signert CSR og sendt tilbake et sertifikat.

![alt text](<image/13 CSR Certificate Enrollment Requests.png>)

Den private nøkkelen ligger lokalt på maskinen. Dette vises med **You have a private key that corresponds to this certificate**.

![alt text](<image/14 CSR in Certificate Enrollment Requests.png>)

Filen som ble lagret er i et standard format som kan sendes til CA for signering. Dvs. signeringen gjøres ikke på samme maskin som CSR blir generert. Filen kan trygt sendes f.eks. som epost. **Private key** eksponeres ikke.

## Importer signert sertifikat

Etter at CSR er sendt til CA og denne har returnert et signert sertifikat, kan dette installeres på maksinen som laget CSR. Da vil sertifikatet knyttes sammen med **private key** som allerede ligger i **Certificate store**.

Importer sertifikatet ved å dobbeltklikke på filen mottatt fra CA. **Issued by** er nå endret til Root CA som har signert sertifikatet. Varighetes er også satt av CA.

Legg merke til at det fremdeles angis at sertifikatet ikke kan verifiseres. Dette er fordi Root CA sertifikatet ikke er installert på lokal maskin.

![alt text](<image/16 CRT Import after sign by CA.png>)

Plasser sertifikat i **Local Machine**.

![alt text](<image/17 CRT Import after sign by CA, Local Machine.png>)

Velg manuell plassering til **Personal**.

![alt text](<image/18 CRT Import after sign by CA, Personal.png>)

Sertifikatet er nå knyttet sammen med **private key**, og flyttet fra **Certificate Enrollment Requests** til **Personal**.

![alt text](<image/19 CRT moved to Personal.png>)

## Importer Root CA sertifikat

Root CA sertifikat må installeres på lokal maskin. Dette må gjøres på alle maskiner som skal benytte sertifikatet som nå er installert på maskinen.

Importer Root CA sertifikatet ved å dobbeltklikke på filen som inneholder dette.

![alt text](<image/20 RootCA import.png>)

Plasser sertifikat i **Local Machine**.

![alt text](<image/21 RootCA import, Local Machine.png>)

Velg manuell plassering til **Trusted Root Certification Authorities**.

![alt text](<image/22 RootCA import, Trusted Root Certification Authorities.png>)

## Verifiser signert sertifikat

Når root CA sertifikat er på plass, kan man sjekke at det genererte sertifikatet er godkjent på lokal maskin. Det vises da at egenskapen **Ensures the identity of a remote computer** er på plass.

![alt text](<image/23 CRT Valid with private key.png>)

Under **Details->Subject Alternative Name** vises servernavn og IP-adresser som er gyldige for denne maskin.

![alt text](<image/24 CRT Subject Alternative Name.png>)

**Enhaced Key Usage** viser også egenskapen **Server Authentication**.

![alt text](<image/25 CRT Enhanced Key Usage, Server.png>)
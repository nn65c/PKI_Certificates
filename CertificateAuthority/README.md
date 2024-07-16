# Certificate Authority (CA)

En Certificate Authority (CA) er en betrodd enhet som utsteder digitale sertifikater, som bekrefter identiteten til nettsider, brukere eller organisasjoner. Disse sertifikatene inneholder en offentlig nøkkel og en bekreftelse fra CA, som sikrer at kommunikasjon over internett er kryptert og autentisert.

## Varianter av Certificate Authorities

### Offentlig CA

Utsteder sertifikater til enhver som ønsker å sikre sin nettside eller tjeneste som skal nås fra internett. Disse CA-ene er vanligvis forhåndsinstallert i nettlesere og operativsystemer, slik at sertifikatene automatisk stoles på.

Sertifikater fra offentlige CA-er må normal kjøpes. Prisene varierer avhengig av typen sertifikat (for eksempel enkeltdomene, wildcard, utvidet validering) og leverandøren.

**Eksempler**: DigiCert, Let's Encrypt.

## OpenSSL
   
Et verktøy og bibliotek for kryptografi som kan brukes til å lage selvsignerte sertifikater og administrere en lokal CA. Hvis du bruker OpenSSL til å opprette en egen CA, må root-sertifikatet distribueres til alle enheter som skal stole på denne CA-en. Dette kan være en omfattende oppgave hvis mange enheter er involvert.

For Windows kan OpenSSL v3 lastes ned fra [Shining Light Productions](https://slproweb.com/products/Win32OpenSSL.html) (Light versjonen er ok). Husk å legge `C:\Program Files\OpenSSL-Win64\bin` mappen i PATH. NB! Program fra denne nettsiden er ikke signert. Program for Windows er generert fra kildekode av en privatperson som ikke har tilgang til signering av kode. Bruk på eget ansvar.

Linux distribusjoner har som regel OpenSSL v3 tilgjengelig via sin "package manager".

Sjekk versjon. Må være v3.x:

     openssl version

### Active Directory Certificate Services (AD CS)

En Microsoft-løsning for å opprette og administrere CA-er innenfor en organisasjon. AD CS brukes ofte til å utstede og administrere interne sertifikater for ulike tjenester, brukere og enheter i et bedriftsnettverk.

## Nøkkelbegreper:
- **Privat nøkkel**: En hemmelig nøkkel som brukes til å signere data, og som må holdes konfidensiell. Den tilsvarende offentlige nøkkelen distribueres via sertifikatet.
- **Certificate Signing Request (CSR)**: En fil som inneholder informasjon om den enheten som ønsker et sertifikat, inkludert den offentlige nøkkelen. CSR-en sendes til en CA for signering.

## Prosessen:
1. **Generere privat nøkkel**: Brukeren genererer en privat nøkkel på sin server.
2. **Opprette CSR**: En CSR opprettes med den offentlige nøkkelen og identitetsinformasjon. Offentlig CA vil ha egne rutiner for hvordan CSR opprettes.
3. **Send til CA**: CSR-en sendes til en CA (offentlig eller intern) for verifisering.
4. **Innhenting av informasjon**: Før utstedelse må CA-en verifisere informasjonen i CSR-en. Dette kan inkludere:
   - **Domenevalidasjon**: Bekrefte at søker har kontroll over domenet.
   - **Organisasjonsvalidasjon**: Bekrefte at søker er en legitim organisasjon (gjelder for sertifikater med organisasjonsvalidering).
5. **Utstedelse av sertifikat**: CA verifiserer informasjonen og utsteder et digitalt sertifikat som signeres med CA-ens private nøkkel.
6. **Installere sertifikatet**: Det signerte sertifikatet installeres på brukerens server, slik at det kan brukes til sikre kommunikasjon.

Når en server skal nås fra internett, er det vanlig å bruke sertifikater fra en offentlig CA fordi disse er automatisk stolt på av de fleste nettlesere og operativsystemer. Sertifikater fra offentlige CA-er må normalt kjøpes, og før de utstedes, må CA-en innhente og verifisere nødvendig informasjon for å sikre at sertifikatet bare utstedes til rettmessige eiere.
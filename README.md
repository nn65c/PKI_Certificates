# PKI - Sertifikater
Dette er en enkel beskrivelse av manuelt oppsett av en struktur med sertifikater som kan brukes i testmiljø. 

Beskrivelsen omfatter ikke automatisk distribusjon, fornying og tilbakekalling av sertifikater. 

Sertifikatene er en del av Public Key Infrastructure (PKI).

## Public Key Infrastructure (PKI)
PKI er et rammeverk som muliggjør konfidensialitet, integritet og autentisering ved kommunikasjon over et nettverk. PKI har prosesser for utstedelse, håndtering og tilbakekalling av digitale sertifikater som benyttes til dette. Sertifikatene bruker et par krypteringsnøkler som er matematisk sammenkoblet slik at data kan krypteres med den ene og dekrypteres med den andre. Den ene nøkkelen er privat (**private key**) og lagres sikkert hos eier av sertifikatet. Den andre (**public key**) gjøres offentlig kjent sammen med annen informasjon i selve sertifikatet (**public certificate**). Kryptering/dekryptering med disse nøklene foregår begge veier.

Denne typen kryptering kalles asymmetrisk på grunn av de forskjellige nøklene som benyttes (**private/public**). Fordelen med denne typen kryptering er at det ikke er behov for å utveksle en felles krypteringsnøkkel mellom begge parter ved oppretting av forbindelse. Asymmetrisk kryptering er imidlertid lite effektiv. Derfor blir asymmetrisk kryptering brukt for å utveksle en felles krypteringsnøkkel på en sikker måte mellom begge parter. Deretter kan videre kommunikasjon benytte symmetrisk kryptering, som er langt mer effektiv. Denne typen utveksling ligger i Transport Layer Security (TLS) og beskrives ikke her.

### Konfidensialitet
Konfidensialitet sikrer at informasjon kun er tilgjengelig for autoriserte parter. I PKI brukes kryptering for å beskytte data mot uautorisert tilgang.

### Integritet
Integritet sikrer at informasjon ikke har blitt endret eller manipulert under overføring. Digitale signaturer (hash) brukes til å bekrefte at dataene som mottas er nøyaktig de samme som dataene som ble sendt, uten modifikasjoner.

### Autentisering
Autentisering bekrefter identiteten til en bruker eller enhet. I PKI blir digitale sertifikater utstedt av en Certificate Authority (CA) brukt til å verifisere identiteten til parter i en kommunikasjon, og sikre at de er de som de utgir seg for å være. 

Den digitale signaturen som sørger for integritet, krypteres med **private key** og kan dekrypteres med **public key**. På denne måten kan bruker av et sertifikat være sikker på at enhet i andre enden har tilgang til **private key**. Dette gjelder både når bruker sjekker at CA har utsted sertifikat, og ved direkte forbindelse mellom enhet og bruker etterpå.

# Typer sertifikater
Sertifikatene har forskjellige bruksområder. I dette dokumentet beskrives to parter - Certificate Authority (CA) og End-entity. Tanken er at dette faktisk er to helt adskilte miljø, der filer som overføres mellom dem ikke inneholder "hemmelig" informasjon (**private key**).

## Certificate Authority (CA)
CA er en part som "går god for" informasjon i et sertifikat ved å signere dette. Brukere av det signerte sertifikatet kan velge å "stole på" alle sertifikater signert av denne CA. Det gjøres ved å installere en offentlige delen av CA sertifikatet i "Trusted Root Certificates Authorities" hos bruker.

### Intermediate/Subordinate CA
Det kan lages en struktur med underliggende CA sertifikater (Sub CA) for å delegere funksjonen med å signere sertifikater. Dette vil gi en trestruktur der sertifikater er koblet sammen i en kjede med overliggende sertifikat som har signert underliggende. 

### [Root CA](CertificateAuthority/OpenSSL_RootCA/README.md)
Denne kjeden ender opp i et sertifikat som har signert seg selv (self-signed), som kalles Root CA. 

For godkjenning av End-entity sertifikat, må man ha tilgang til hele kjeden opp til Root CA. Normalt er det bare Root CA som distribueres rundt. End-entity vil kjede sammen sitt eget og alle Sub CA sertifikater opp til Root CA. Bruker har sin lokale kopi av Root CA sertifikat, og kjeden blir derfor komplett.

Det finnes offisielle CA der den offentlige delen av CA sertifikatet allerede er installert i "Trusted Root Certificates Authorities" i operativsystem "Certificate store". Sertifikat signert av offentlig CA er en tjeneste som normalt må kjøpes.

Her beskrives oppsett av en enkel Root CA. Distribusjon av dette sertifikatet til "Trusted Root Certificates Authorities" i  "Certificate store" kan gjøres manuelt eller med Group Policy i et domene.

## [End-entity](EndEntity/README.md)
End-entity sertifikat kan f.eks. være server eller klient. Det kan også være sertifikat som brukes til signering av kode (f.eks. Powershell skript). Dette er egenskaper/informasjon som ligger i sertifikatet og er verifisert og godkjent (signert) av CA. Der ligger også informasjon om navn på End-entity slik at brukere av sertifikatet kan være sikker på at End-entity er de utgir seg for å være. 
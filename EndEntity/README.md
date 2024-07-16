# End-entity

En enhet som har behov for et signert sertifikat fra CA, må lage en forespørsel om dette. Dette kalles en Certificate Signing Request (CSR).

## Certificate Signing Request (CSR)

Enhet vil først generere en **private key**. Denne oppbevares beskyttet på lokal maskin, og skal ikke gjøres tilgjengelig for andre.

Deretter lages en CSR som er et dokument/fil som inneholder den tilhørende **public key**, samt annen informasjon og egenskaper som er ønsket i sertifikatet. Denne filen inneholder også en signatur (hash) av hele dokumentet. Denne signaturen er kryptert med **private key**.

CSR sendes til CA som dekrypterer signatur med **public key** inkludert i filen, og sjekker at signatur stemmer med resten av dokumentet. På denne måten vet CA at eier av **private key** har laget dokumentet.

CA er ansvarlig for å verifisere at informasjon i CSR er korrekt. Når dette er i orden, fjernes den opprinnelige krypterte signaturen i mottatt CSR, og CA legger inn ekstra informasjon. Dette gjelder bl.a. hvem som er CA (Issued by), serienummer og utløpsdato som skal gjelde for sertifikat. CA genererer ny signatur (hash) for dokumentet og krypterer denne med sin **private key**. Dette blir da et dokument som har:
- Enhet sin **public key** fra CSR.
- Informasjon om egenskaper for sertifikat. F.eks. server, klient eller signering av kode fra CSR. 
- Informasjon om enhet. F.eks. servernavn fra CSR.
- Informasjon som CA har lagt til opprinnelig CSR. Bl.a. utløpsdato og hvem som er CA (Issued by).
- Signatur (hash) på dokument som er kryptert med CA sin **private key**. Denne kan dekrypteres med CA sin **public key** for verifisering av innhold i dokumentet. Denne **public key** er tilgjengelig i CA sitt sertifikat som skal ligge i "Trusted Root Certificateion Authorities" i "Certificate store" hos bruker.

Filen returneres til enhet som sendte CSR og kombinert med **private key** gir dette et komplett sertifikat for enhet.
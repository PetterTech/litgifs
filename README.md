# GIF-veggen

Statisk side som viser to tilfeldige kontor-GIF-er, en dad joke og en nedtelling.
Alt skjer i nettleseren, så den trenger ingen server, runbook, Logic App eller Azure.

## Filer
- `index.html`: selve siden
- `app.js`: logikken, med innstillinger øverst i `CONFIG`
- `gifs.csv`: LIT-lista (standard)
- `dax.csv`: Datametrix-lista, åpnes med `?liste=dax`
- `hent-gifs.ps1`: flytter GIF-ene fra storage.kemta.net inn i `img/`
- `test.js`: tester, kjøres med `node test.js`

## Legge til en GIF
Legg til en linje nederst i CSV-en: `Tekst;https://adresse/til/gif.gif` (eller `img/fil.gif`).
Nye GIF-er havner nederst og vises oftere, fordi den første GIF-en alltid plukkes
fra den nyeste halvdelen av lista. Lagre som UTF-8.

## Teste lokalt
Siden må serveres over http (ikke åpnes som fil), f.eks.:
    npx serve .        eller        python3 -m http.server
Åpne så http://localhost:3000 (serve) eller http://localhost:8000 (python).

## Publisere på GitHub Pages
1. Lag et nytt repo og last opp filene.
2. Settings → Pages → Source: «Deploy from a branch», branch `main`, mappe `/ (root)`.
3. Siden havner på `https://<bruker>.github.io/<repo>/`.

NB: På gratisplanen er Pages-sider alltid offentlige. CSV-ene inneholder ekte navn,
så anonymiser dem eller la være å dele adressen. Siden har `noindex`, så søkemotorer
skal ikke vise den, men det er ikke tilgangsstyring.

## http-GIF-er og https-sider
GitHub Pages kjører på https. Nettlesere prøver da å hente http-bilder over https.
Hvis storage.kemta.net ikke støtter https, vises GIF-ene som «finnes ikke lenger».
Løsning: kjør `./hent-gifs.ps1` én gang, så ligger GIF-ene i repoet og kemta.net kan slettes.

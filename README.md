# Dekenweer 🐴

Registreer je paarden en zie ze grazen in een geanimeerde wei. Het weer in de
wei volgt de echte voorspelling (zon, wolken, regen, sneeuw, mist, onweer,
wind, ochtend/middag/nacht). Kies bovenin een **datum** (7 dagen) en een
**fase van de dag** (ochtend 06–12, middag 12–18, avond & nacht 18–06) en je
krijgt per paard dekenadvies, plus "Dag in het kort" met alle drie de fases.

- **Mijn stal → Dekens**: leg je eigen dekens vast (regendeken, buitendeken,
  staldeken, onderdeken, fleece, vliegendeken) met vulling, waterdicht,
  halsstuk, kleur en voor welk paard. Het advies kiest dan de deken uit jouw
  dekenkast die het best past, zo nodig met een onderdeken eronder, en het
  paard in de wei draagt die deken.
- **Seizoenen & stalschema** (Mijn stal → 📅): zomer en winter met eigen
  begindatum, en per fase of de paarden binnen of buiten staan (standaard:
  zomer altijd buiten, winter 's avonds binnen). Binnen rekent het advies met
  de stal, en per paard kies je de **deken op stal**: automatisch, geen deken
  of een vaste deken uit je dekenkast. Staan de paarden binnen, dan zie je ze
  in de **stal**, elk in een eigen box met het hoofd over de deur.
- **Aftekeningen**: kies per paard een kol, smalle of brede bles en per been
  een witte sok of kous; in de wei zie je de goede kant van het paard.
- **Nero**, de mascotte (een vos met brede bles en roze snoet), staat in het
  app-icoon, geeft tips bij het advies en graast in de wei zolang je nog geen
  eigen paarden hebt toegevoegd.
- **Mijn stal → ⚙ Adviesinstellingen**: stel zelf de temperatuurgrenzen per
  scheertype in en hoeveel wind, regen en stal meetellen. Met een
  voorbeeldschuif zie je direct wat het effect is.

## Als web-app op je iPhone/iPad (zonder Mac)

GitHub bouwt de app gratis voor je en zet hem online. Je hebt alleen een
browser nodig (op een computer, voor het uploaden).

1. Maak een gratis account op <https://github.com>.
2. Klik rechtsboven op **+ → New repository**. Naam: `dekenweer`, kies
   **Public**, vink niets anders aan en klik **Create repository**.
3. Klik op de lege pagina op **uploading an existing file**. Pak de zip uit,
   open de map `dekenweer`, selecteer **alles** (ook de map `.github`) en sleep
   het in het uploadvenster. Klik onderaan op **Commit changes**.
4. Ga naar **Settings → Pages** en kies bij *Source* voor **GitHub Actions**.
5. Ga naar het tabblad **Actions**, klik links op *Web-app bouwen en
   publiceren* en dan rechts op **Run workflow**. Na 3 à 5 minuten verschijnt
   een groen vinkje.
6. Je app staat nu op `https://JOUW-GEBRUIKERSNAAM.github.io/dekenweer/`
7. Open dat adres in **Safari** op je iPhone/iPad, tik op de deelknop
   (vierkantje met pijltje) en kies **Zet op beginscherm**.

Zie je na het uploaden geen map `.github` in je repository? Kies dan
**Add file → Create new file**, typ als naam `.github/workflows/deploy.yml`
en plak de inhoud van dat bestand uit de zip.

Wijzig je later iets, upload dan alleen de gewijzigde bestanden: GitHub
bouwt en publiceert de app automatisch opnieuw. Je paarden worden per
toestel bewaard (iPhone en iPad hebben elk hun eigen lijst).

## Als echte app via Xcode (met een Mac)

1. Installeer Flutter en Xcode: <https://docs.flutter.dev/get-started/install/macos/mobile-ios>
2. Pak deze map uit en open een Terminal in de map `dekenweer`.
3. Laat Flutter de iOS- en Android-projectbestanden aanmaken (je code in `lib/` blijft staan):
   ```bash
   flutter create . --platforms=ios,android --org nl.jouwnaam --project-name dekenweer
   flutter pub get
   ```
   `flutter create` maakt ook een voorbeeldtest `test/widget_test.dart` aan;
   die mag je verwijderen.
4. Start een simulator en draai de app:
   ```bash
   open -a Simulator
   flutter run
   ```
5. Op je eigen iPhone/iPad: sluit hem aan, open `ios/Runner.xcworkspace` in
   Xcode, kies bij *Signing & Capabilities* je Apple ID als *Team*, en draai
   daarna `flutter run`. (Met een gratis Apple ID blijft de app 7 dagen werken;
   met een betaald developer-account kun je via TestFlight installeren.)

Tests van de dekenlogica: `flutter test`

## Hoe werkt het advies?

`lib/logic/blanket_advisor.dart`

1. **Uitgangstemperatuur**: 's nachts de laagste temperatuur, overdag het
   gemiddelde van laagste en gemiddelde temperatuur.
2. **Weer**: wind ≥ 20 km/u −2 °C, ≥ 35 km/u −4 °C; nat weer −3 °C
   (gehalveerd met schuilstal; genegeerd als het paard 's nachts op stal staat,
   dan juist +5 °C).
3. **Paard**: pony/koudbloed +3, volbloed −2, senior (20+) −2, mager −2,
   koukleum −3, "heeft het snel warm" +3.
4. De uitkomst zoeken we op in een tabel per scheertype:

| Effectieve temp. | Niet geschoren | Deels geschoren | Volledig geschoren |
|---|---|---|---|
| Geen deken | ≥ 8 °C | ≥ 15 °C | ≥ 18 °C |
| Regendeken (0 g) | 3–8 °C (alleen bij nat weer) | 10–15 °C | 14–18 °C |
| Licht (50–100 g) | −3–3 °C | 5–10 °C | 9–14 °C |
| Middel (150–200 g) | −10 – −3 °C | 0–5 °C | 3–9 °C |
| Zwaar (250–300 g) | −18 – −10 °C | −7–0 °C | −3–3 °C |
| Extra zwaar (350 g+) | < −18 °C | < −7 °C | < −3 °C |

Dit zijn de standaardwaarden. Je past ze in de app aan via **Mijn stal →
Adviesinstellingen** (knop rechtsboven); daar kun je ook terug naar
"Standaard". Eén paard warmer of kouder inschatten? Zet dat paard op "heeft
het snel koud/warm".

### Welke deken uit je dekenkast?

`lib/logic/blanket_picker.dart` kiest per paard de deken (of combinatie met een
onderdeken) waarvan de vulling het dichtst bij het advies ligt. Buiten
komen alleen waterdichte dekens in aanmerking; 's nachts op stal heeft een
staldeken de voorkeur. Eén deken gaat voor twee lagen, en als een halsstuk
geadviseerd wordt gaat een deken mét halsstuk voor.

## Opbouw

```
lib/
  main.dart                  app + thema
  ui.dart                    AppScope (state) en kleuren
  models/horse.dart          paard + opties (vacht, type, scheren, stal…)
  models/weather.dart        weermodellen, WMO-codes, dag/nacht-periodes
  models/blanket.dart        je eigen dekens (soort, vulling, halsstuk…)
  models/advice_settings.dart instelbare grenzen en correcties
  models/season.dart         zomer/winter en het stalschema
  models/day_phase.dart      ochtend / middag / avond & nacht
  logic/blanket_advisor.dart dekenadvies
  logic/blanket_picker.dart  kiest de best passende deken uit je dekenkast
  services/weather_service.dart  Open-Meteo (gratis, geen API-sleutel)
  services/storage.dart      opslag op het toestel (shared_preferences)
  state/app_state.dart       app-status, tijdbalk (Nu/Vannacht/Morgen…)
  widgets/farm_scene.dart    geanimeerde boerderij + weer + kudde
  widgets/horse_painter.dart het getekende paard (vacht, aftekeningen, deken, grazen)
  widgets/stable_scene.dart  de stal van binnen (boxen, ramen met het weer)
  widgets/horse_front.dart   paard van voren (voor de stal)
  widgets/nero.dart          mascotte Nero (vooraanzicht, knippert) en 'Tip van Nero'
  widgets/advice_widgets.dart adviezenkaarten en detailpaneel
  screens/                   hoofdscherm, mijn stal (paarden + dekens),
                             paard/deken bewerken, adviesinstellingen, locatie
web/                         web-app: icoon, laadscherm, beginscherm-instellingen
.github/workflows/deploy.yml bouwt en publiceert de web-app via GitHub Pages
```

Weerdata: [Open-Meteo.com](https://open-meteo.com) (CC BY 4.0).

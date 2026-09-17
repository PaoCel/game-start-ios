# ABG iOS + Firebase setup (da zero)

Data: 27 Feb 2026

## 0) Stato codice gia preparato
Nel progetto sono stati copiati i file Swift per:
- login (Google + Apple)
- routing ruoli player/admin
- player screen MVP
- admin screen MVP
- servizi Firebase callable
- servizi NFC nativo iOS (CoreNFC)

Percorsi principali:
- `ABG/Features`
- `ABG/Services`
- `ABG/Core`
- `ABG/Models`
- `ABG/RootView.swift`
- `ABG/AppContainer.swift`
- `ABG/ABGApp.swift`

## 1) Firebase Console: campi da inserire per app iOS
Vai su Firebase Console -> progetto `comple-ruspa-2026` -> Add app -> iOS.

Campi:
1. Apple bundle ID:
   - usa quello del progetto Xcode attuale: `paolo.ABG`
   - se lo cambi in Xcode, devi usare esattamente il nuovo valore qui.
2. App nickname:
   - `ABG iOS` (puoi cambiarlo, non e vincolante)
3. App Store ID:
   - lascia vuoto per ora.

Poi clicca `Register app` e scarica `GoogleService-Info.plist`.

## 2) Inserire GoogleService-Info.plist in Xcode (manuale)
1. Apri `ABG.xcodeproj`.
2. Trascina `GoogleService-Info.plist` dentro il gruppo `ABG`.
3. Nel popup seleziona:
   - `Copy items if needed`
   - target `ABG` selezionato.

## 3) Aggiungere package iOS (manuale)
In Xcode: File -> Add Package Dependencies...

Aggiungi:
1. `https://github.com/firebase/firebase-ios-sdk`
   - products minimi: `FirebaseCore`, `FirebaseAuth`, `FirebaseFirestore`, `FirebaseFunctions`
2. `https://github.com/google/GoogleSignIn-iOS`
   - product: `GoogleSignIn`

## 4) Aggiungere i file Swift al target (manuale in Xcode)
I file sono gia sul disco ma vanno inclusi nel progetto Xcode.

Metodo consigliato:
1. In Xcode, click destro sul gruppo `ABG` -> `Add Files to "ABG"...`
2. Seleziona queste cartelle/file da `ABG/ABG`:
   - `Core`
   - `Models`
   - `Services`
   - `Features`
   - `AppContainer.swift`
   - `RootView.swift`
3. Popup:
   - `Create groups`
   - `Add to targets`: ABG
   - `Copy items if needed`: OFF (sono gia dentro la cartella progetto)

## 5) URL scheme Google Sign-In (manuale)
1. Apri `GoogleService-Info.plist`.
2. Copia valore `REVERSED_CLIENT_ID`.
3. In Xcode target `ABG` -> Info -> URL Types:
   - aggiungi nuovo URL Type
   - `URL Schemes` = valore `REVERSED_CLIENT_ID`

## 6) Capability NFC (manuale)
Target `ABG` -> Signing & Capabilities -> `+ Capability`:
- aggiungi `Near Field Communication Tag Reading`

## 7) Capability Apple Sign In (manuale, consigliato)
Target `ABG` -> Signing & Capabilities -> `+ Capability`:
- aggiungi `Sign In with Apple`


## 8) Primo run test
1. Collega iPhone con cavo.
2. Seleziona device fisico come destination.
3. Run.
4. Se compare errore signing, imposta Team in target Signing.

## 9) Cosa resta da fare lato codice (lo faccio io)
- verificare Sign in with Apple end-to-end su device reale
- rifiniture realtime Firestore lato admin/player
- push notifications APNs/FCM
- parity completa con web app

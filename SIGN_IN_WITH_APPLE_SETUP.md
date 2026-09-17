# Sign in with Apple: Setup Operativo ABG

Stato attuale del progetto:
- codice iOS gia presente
- pulsante login Apple gia presente
- capability Apple Sign In gia dichiarata
- entitlements gia presenti

Riferimenti codice:
- UI login: `ABG/ABG/Features/Auth/LoginView.swift`
- trigger auth: `ABG/ABG/Features/Auth/AuthViewModel.swift`
- Firebase auth: `ABG/ABG/Services/FirebaseAuthService.swift`
- flow Apple native: `ABG/ABG/Services/AppleSignInCoordinator.swift`
- entitlements: `ABG/ABG/ABG.entitlements`

Valori del progetto:
- Apple Team ID: `787YK9YUB3`
- Bundle ID app iOS: `paolo.ABG`
- Firebase Project ID: `comple-ruspa-2026`
- Firebase return URL da usare in Apple Developer: `https://comple-ruspa-2026.firebaseapp.com/__/auth/handler`

## 1. Cosa manca davvero

Non manca il codice applicativo principale.

Mancano invece le configurazioni esterne:
- Apple Developer: App ID, Services ID, Key
- Firebase Console: provider Apple abilitato e configurato
- test reale su iPhone con account Apple vero

## 2. Checklist secca

### Apple Developer

1. Vai su `Certificates, Identifiers & Profiles`.
2. Apri `Identifiers`.
3. Apri l'App ID con bundle `paolo.ABG`.
4. Verifica che `Sign in with Apple` sia abilitato.

### Services ID

1. In `Identifiers`, crea un nuovo `Services ID`.
2. Usa un identificatore coerente, ad esempio: `paolo.ABG.signin`.
3. Apri quel Services ID.
4. Abilita `Sign in with Apple`.
5. Premi `Configure`.
6. Seleziona come app primaria `paolo.ABG`.
7. Inserisci il Return URL:
   `https://comple-ruspa-2026.firebaseapp.com/__/auth/handler`
8. Salva.

Nota:
- Se Apple chiede anche un dominio/sito, usa il dominio Firebase collegato al return URL.

### Key Apple

1. Vai in `Keys`.
2. Crea una nuova key.
3. Abilita `Sign in with Apple`.
4. Associala all'app `paolo.ABG`.
5. Salva e scarica il file `.p8`.

Devi conservare questi 3 valori:
- `Key ID` = TPK7N8U6DW
- `Team ID` = `787YK9YUB3`
- file `.p8`

## 3. Firebase Console

1. Apri progetto `comple-ruspa-2026`.
2. Vai in `Authentication`.
3. Vai in `Sign-in method`.
4. Abilita provider `Apple`.
5. Inserisci:
   - `Service ID`: quello creato sopra, per esempio `paolo.ABG.signin`
   - `Apple Team ID`: `787YK9YUB3`
   - `Key ID`: quello della key Apple
   - `Private key`: contenuto del file `.p8`
6. Salva.

## 4. Xcode

Verifiche da fare:
- target `ABG` -> `Signing & Capabilities`
- capability `Sign In with Apple` presente
- file entitlements attivo: `ABG/ABG.entitlements`
- Team di signing corretto

Nel progetto attuale questi punti risultano gia cablati, ma va comunque aperto Xcode e controllato che non ci siano override del profilo di firma.

## 5. Test minimo obbligatorio su device reale

Da fare su un iPhone vero, non solo simulatore:

1. disinstalla la build vecchia
2. avvia la nuova build
3. premi `Continua con Apple`
4. completa il popup Apple
5. verifica che entri in app senza errore Firebase
6. fai logout
7. ripeti login Apple una seconda volta
8. verifica che il profilo venga ricreato/caricato correttamente
9. verifica join partita, lobby e live dopo login Apple

## 6. Errori tipici

Se il login Apple fallisce, i casi piu probabili sono:
- `Apple provider` non abilitato in Firebase
- `Services ID` mancante o sbagliato
- `Return URL` Apple non uguale a quello Firebase
- key `.p8`/`Key ID` non caricati correttamente in Firebase
- app ID Apple senza capability `Sign in with Apple`
- test fatto con account Apple non idoneo o senza iCloud/2FA

## 7. Come muoverti adesso

Ordine corretto:

1. Apple Developer: abilita App ID
2. Apple Developer: crea Services ID
3. Apple Developer: crea Key
4. Firebase Console: configura provider Apple
5. Xcode: check capability/signing
6. test reale su iPhone

## 8. Fonti ufficiali

- Firebase iOS Apple auth:
  `https://firebase.google.com/docs/auth/ios/apple`
- Apple Services ID:
  `https://developer.apple.com/help/account/identifiers/register-a-services-id/`
- Apple Sign in with Apple for the web:
  `https://developer.apple.com/help/account/capabilities/configure-sign-in-with-apple-for-the-web`

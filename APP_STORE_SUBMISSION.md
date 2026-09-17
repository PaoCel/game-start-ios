# App Store Submission Playbook

## Current app facts

- App name: `Game Start!`
- Brand: `Borderland Games`
- Bundle ID: `paolo.ABG`
- App Store ID: `6760287886`
- Version: `1.0`
- Build uploaded to App Store Connect: `12`
- iPhone only: `TARGETED_DEVICE_FAMILY = 1`
- Support URL: `https://borderlandgames.it/support`
- Privacy URL: `https://borderlandgames.it/privacy`
- Marketing URL: `https://borderlandgames.it/`
- Export compliance in app bundle: `ITSAppUsesNonExemptEncryption = false`

## Metadata to insert

### App Information

- Name: `Game Start!`
- Subtitle: `Partite live su invito`
- Primary category: `Games`
- Secondary category: `Entertainment`
- Copyright: `2026 Borderland Games`

### Age rating recommendation

- Recommended target: `9+`
- Reasoning: live competitive gameplay, eliminazioni e scontri simulati, ma nessun contenuto grafico, sessuale, d'azzardo o linguaggio esplicito.
- Before submitting, re-check the questionnaire in App Store Connect against the actual content descriptors Apple shows.

### Version information

- Promotional text:
  `Gioca o gestisci partite dal vivo con codici invito, ruoli player/operator e scansioni NFC integrate.`
- Description:

  `Game Start! e l'app Borderland Games per partite live su invito.`

  `Entra come player, completa il profilo, ricevi un codice di accesso e vivi la partita dal tuo iPhone con stato live, timer, punteggio personale e aggiornamenti in tempo reale.`

  `Per organizzatori e operatori, Game Start! include control room, gestione team, codici invito, basi, oggetti e configurazione rapida della sessione.`

  `L'app e progettata per esperienze dal vivo supervisionate, con flussi dedicati per accesso ospite, condivisione link, notifiche push e scansioni NFC quando previste dal formato di gioco.`

- Keywords:
  `party game,gioco live,nfc,team,evento,inviti,player,operatore,match`
- Support URL: `https://borderlandgames.it/support`
- Marketing URL: `https://borderlandgames.it/`
- Privacy Policy URL: `https://borderlandgames.it/privacy`

## Privacy details to prepare in App Store Connect

- Tracking: `No`
- Likely linked data used for app functionality:
  - Contact Info: `Email Address`
  - User Content: `Photos or Videos` for avatar upload
  - User Content: `Other User Content` for nickname/avatar profile content
  - Identifiers: `User ID`
  - Identifiers: `Device ID` or push token equivalent for notifications
- No ad SDK or App Tracking Transparency flow detected in the current app target.
- Before final submission, mirror exactly the data types used by your Firebase/Auth/Push implementation in the App Privacy questionnaire.

## App Review information

### Contact

- First name: `Paolo`
- Last name: `Celestini`
- Email: `support@borderlandgames.it`
- Phone: use the phone number you actively monitor during review

### Sign-in / access

- External paid account required: `No`
- Reviewer test path: `Continua come ospite`

### Review notes template

Use this text and replace the placeholders before submitting:

`Game Start! supports Sign in with Apple, Google, and guest access.`

`For App Review you can enter without credentials by tapping "Continua come ospite".`

`To test the main flow, use the dedicated review player code: REVIEW_PLAYER_CODE`

`If you also need operator access, use: REVIEW_OPERATOR_CODE`

`This app powers supervised live sessions. NFC gameplay requires physical tags used during live events. If NFC hardware props are not available during review, you can still validate login, profile setup, invite handling, home hub, and control room access with the review codes above.`

`Support during review: support@borderlandgames.it`

Important:

- Create a real review game/code on production before submission.
- Keep that review game active until the app passes review.
- If you cannot keep a live test session active, attach a short demo video in the review notes or App Review attachment area.

## Screenshot plan

### Recommended set

Use these 5 screenshots in this order:

1. Home operativa
2. Gameplay live
3. Control room
4. Profilo player
5. Accesso

Optional 6th screenshot:

6. Esito partita

### Simulator workflow

1. Open Xcode.
2. Select scheme `ABG Screenshots`.
3. Run on `iPhone 17 Pro Max` simulator.
4. From the screenshot menu inside the app, open one scene at a time.
5. Wait one second for animations to settle.
6. Capture with `Device > Trigger Screenshot` or `Cmd+S`.

### Direct scene launch

You can also launch a specific scene with:

- Environment variable: `APP_STORE_SCREENSHOT_SCENE`
- Supported values: `login`, `home`, `profile`, `gameplay`, `result`, `control-room`

### Notes

- Since the app is iPhone-only, you do not need iPad screenshots.
- Start with the 6.9-inch iPhone screenshot set and let App Store Connect scale where allowed.
- Use portrait screenshots only, consistent with the app orientation.

## Release flow in App Store Connect

1. Open the existing app record in App Store Connect.
2. Go to the new version page tied to build `12`.
3. Fill App Information and Version Information fields.
4. Complete App Privacy.
5. Complete Age Rating.
6. Upload screenshots for the iPhone display class.
7. Attach build `12`.
8. Fill App Review Information and paste the review notes template with real review codes.
9. Choose `Manual release` for the first launch.
10. Click `Add for Review`, resolve any warnings, then `Submit for Review`.

## Final pre-submit checklist

- `borderlandgames.it` URLs are the only public URLs shown in metadata.
- Support URL and Privacy URL open correctly.
- Review player code and operator code are active on production.
- Guest login works on the review build.
- Build `12` is fully processed in App Store Connect.
- Screenshots match the production branding `Game Start!` / `Borderland Games`.
- No screenshot includes debug overlays, simulator chrome, or placeholder data that looks broken.

## Official Apple references

- Screenshot upload flow: <https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots>
- Screenshot specs: <https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications>
- Version metadata reference: <https://developer.apple.com/help/app-store-connect/reference/platform-version-information>
- App privacy details: <https://developer.apple.com/help/app-store-connect/manage-app-information/provide-app-privacy-details>
- Age rating: <https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating>
- Export compliance: <https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance>
- Submit for review: <https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/submit-an-app-for-review>

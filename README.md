# CalorieAdvisor

App iOS personnelle de suivi calorique (inspirée de Lose It / MyFitnessPal) : visualiser jour après
jour le déficit ou le surplus calorique pour atteindre ses objectifs de santé ou de poids.
Cahier des charges initial : `application_comptage_calorie.md`.

L'app est installée **sans compte Apple Developer payant** (Apple ID gratuit, « Personal Team ») et
re-signée automatiquement par un script sur le Mac, la signature gratuite n'étant valable que 7 jours.

## Fonctionnalités

### Saisie

| Mode | Fonctionnement |
|---|---|
| Recherche avec auto-complétion | Mes aliments → récents → base intégrée (167 aliments et boissons FR) → Open Food Facts (en ligne, gratuit, sans clé) |
| Code-barre | VisionKit (`DataScannerViewController`) + Open Food Facts → choix de la portion |
| Photo | Vision (`ClassifyImageRequest`, sur l'appareil) reconnaît les aliments → Apple Intelligence estime portions et valeurs → écran de vérification |
| Décrire | Texte libre (« entrecôte frites et 2 verres de rouge ») → Apple Intelligence → écran de vérification |
| Manuel | Nom, quantité, valeurs ; pour les boissons, champ « degré d'alcool » (alcool pur × 7 kcal/g) |
| Ajout rapide de boissons | Eau 25 cl, café, thé en un tap depuis la section Boissons |

- Apple Intelligence passe par le framework **Foundation Models** : modèle exécuté sur l'iPhone, sans
  clé d'API ni envoi de données. Les estimations restent approximatives : les modes Photo et Décrire
  passent toujours par un écran de vérification, et chaque entrée reste modifiable dans le journal
  (quantité, repas, ou valeurs saisies à la main).
- Aliments et plats fréquents : « Ajouter à mes aliments » lors d'un ajout, ou « Enregistrer comme plat »
  depuis l'en-tête d'un repas (le repas entier devient une portion réutilisable). Gestion dans
  Réglages > Mes aliments et plats.

### Journal (vue du jour)

- Synthèse : apport, dépense (active + repos), anneau « restantes », bandeau déficit/surplus (vert si
  l'objectif du jour est respecté), répartition protéines / glucides / lipides / alcool.
- Sections Petit-déjeuner, Déjeuner, Collation, Dîner et **Boissons**, repliables (l'état est mémorisé).
- Toutes les boissons (entrées en ml, hors soupes) vont dans la section Boissons, quel que soit le mode
  de saisie. Carte **Hydratation** : total bu / objectif, détail eau, café/thé, autres, alcool.
  **L'alcool n'est pas compté dans l'hydratation.**

### Tendances (7 jours, 30 jours, 3 mois, 1 an)

Balance quotidienne par rapport à l'objectif, apport comparé à la dépense, balance cumulée convertie
en kg, hydratation par jour, poids (Apple Santé) avec le poids cible, répartition moyenne des apports.
La journée en cours est exclue, de même que les jours sans saisie.

### Conseils

Synthèse, points positifs et conseils générés sur l'iPhone à partir des 7 derniers jours : calories,
macros, alcool, hydratation, objectif et poids cible. Les données exactes transmises au modèle sont
visibles sous « Données transmises au modèle ».

### Calculs et objectifs

- **Balance** = apport − (dépense active + métabolisme de repos), lus dans Apple Santé. Pour le jour
  en cours, la dépense au repos mesurée est extrapolée sur 24 h. Sans données Santé (montre non
  portée), la dépense au repos est estimée par la formule de Mifflin-St Jeor à partir du profil
  (sexe, année de naissance, taille, poids).
- **Objectif calorique** (Réglages > Objectif), au choix :
  - un déficit fixe, de 0 à 1 000 kcal/jour ;
  - un **poids cible** et un rythme (0,25 à 1 kg/semaine). L'app en déduit le déficit (ou le surplus
    pour une prise de poids), recalculé d'après le dernier poids enregistré dans Santé, et la date
    d'arrivée estimée. Le déficit est plafonné à 1 000 kcal/jour. Un avertissement s'affiche si le
    rythme dépasse 1 % du poids par semaine ou si le poids cible correspond à un IMC inférieur à 18,5.
  - Budget du jour = dépense − déficit visé.
- **Objectif d'hydratation** (Réglages > Hydratation) : automatique selon le poids et le sexe (environ
  28 ml/kg de boissons, avec au moins 2 L pour un homme et 1,6 L pour une femme, repères EFSA), ou
  valeur personnalisée.

## Prérequis

- Mac avec **Xcode 26 ou plus récent** (SDK iOS 26+ requis pour Foundation Models), connecté avec votre
  Apple ID : Xcode > Settings > Accounts.
- XcodeGen : `brew install xcodegen`. Le projet Xcode n'est pas versionné, il est généré depuis `project.yml`.
- iPhone compatible Apple Intelligence (iPhone 15 Pro ou plus récent), Apple Intelligence activé.

## Première installation

### 1. Signature

```bash
cp Config/Signing.local.xcconfig.example Config/Signing.local.xcconfig
```

Éditer `Config/Signing.local.xcconfig` :

```
DEVELOPMENT_TEAM = A1B2C3D4E5
BUNDLE_ID = com.votrenom.calorieadvisor
```

- `DEVELOPMENT_TEAM` est l'**identifiant de 10 caractères** de la Personal Team, **pas son nom** ni
  l'adresse e-mail. Pour le trouver :
  ```bash
  defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier 2>/dev/null || defaults read com.apple.dt.Xcode IDEProvisioningTeams
  ```
  Prendre le `teamID` du bloc contenant `isFreeProvisioningTeam = 1`. Autre méthode : choisir la
  Personal Team dans Xcode (cible > Signing & Capabilities > Team), puis
  `grep DEVELOPMENT_TEAM CalorieAdvisor.xcodeproj/project.pbxproj`.
- `BUNDLE_ID` doit être unique au monde.

### 2. Génération du projet et premier lancement

```bash
xcodegen generate
open CalorieAdvisor.xcodeproj
```

1. Sur l'iPhone branché en USB : Réglages > Confidentialité et sécurité > **Mode développeur** activé.
2. Dans Xcode : schéma **CalorieAdvisor**, destination **votre iPhone** (pas « My Mac »), puis ⌘R.
3. Sur l'iPhone : Réglages > Général > VPN et gestion de l'appareil > faire confiance au développeur.
4. Dans Xcode > Window > Devices and Simulators, cocher **Connect via network** pour permettre
   l'installation en Wi-Fi.
5. Au premier lancement de l'app, autoriser l'accès à Santé, puis renseigner le profil dans Réglages.

> Ouvrir `CalorieAdvisor.xcodeproj`, jamais un fichier `.swift` seul : Xcode créerait sinon un projet
> temporaire compilé pour macOS, avec des erreurs « cannot find … in scope ».

## Rafraîchissement automatique

Avec un Apple ID gratuit, le profil de signature expire **7 jours** après sa création. Passé ce délai,
l'app ne s'ouvre plus. Le script `scripts/refresh.sh` re-signe et réinstalle l'app avant l'expiration.

### Mise en place

```bash
cp scripts/refresh.config.example scripts/refresh.config
xcrun devicectl list devices      # copier l'« Identifier » de l'iPhone
```

Éditer `scripts/refresh.config` :

```bash
DEVICE_ID="<Identifier de l'iPhone>"   # remplacer la valeur d'exemple 00000000-…
RENEW_THRESHOLD_HOURS=72               # renouveler quand il reste moins de 72 h
```

Puis :

```bash
scripts/refresh.sh --force        # premier essai manuel : doit finir par « OK, app valide jusqu'au … »
scripts/install-launchd.sh        # tâche automatique tous les jours à 9 h 30 et 21 h
```

### Fonctionnement de `refresh.sh`

1. Lit la date d'expiration de la dernière installation réussie. S'il reste plus de 72 h, il ne fait
   rien (sauf avec `--force`).
2. Régénère le projet avec XcodeGen si `project.yml` a changé (toujours avec `--force`).
3. Supprime le profil de provisionnement en cache pour ce bundle id, afin d'obtenir un nouveau profil
   valable 7 jours pleins.
4. Compile en Release et signe (`xcodebuild -allowProvisioningUpdates`).
5. Installe l'app **par-dessus** la version présente (`xcrun devicectl device install app`) : le
   journal, les aliments enregistrés et les réglages sont conservés.
6. Mémorise la nouvelle date d'expiration et envoie une notification macOS.

Avec deux vérifications par jour et un seuil de 72 h, le renouvellement a lieu vers le 4ᵉ jour, ce qui
laisse environ 6 tentatives si l'iPhone n'est pas joignable. En cas d'échec, une notification
macOS l'indique. Elle devient une alerte quand il reste moins de 24 h.

La date d'expiration est aussi visible dans l'app : Réglages > Application (en rouge à moins de 2 jours).

### Conditions

- Mac allumé, session ouverte. S'il était en veille à l'heure prévue, launchd lance la tâche au réveil.
- iPhone sur le même Wi-Fi que le Mac (ou branché en USB), idéalement déverrouillé.
- Xcode toujours connecté à l'Apple ID (Xcode > Settings > Accounts).
- **Ne jamais supprimer l'app de l'iPhone**, même expirée : réinstaller par-dessus conserve les données,
  la supprimer les efface définitivement. Si l'app a expiré, lancer simplement `scripts/refresh.sh --force`.

### Commandes utiles

| Action | Commande |
|---|---|
| Installer après une modification du code | `scripts/refresh.sh --force` |
| Lancer la tâche planifiée immédiatement | `launchctl kickstart -p gui/$(id -u)/local.calorieadvisor.refresh` |
| Consulter le journal | `tail -50 ~/Library/Logs/CalorieAdvisor/refresh.log` |
| Détail de la compilation / de l'installation | `~/Library/Logs/CalorieAdvisor/xcodebuild.log`, `install.log` |
| Désinstaller la tâche | `scripts/install-launchd.sh --uninstall` |

### Limites du compte gratuit

- 7 jours de validité par signature.
- 3 apps installées de cette façon au maximum par appareil.
- 10 identifiants d'app (bundle id) nouveaux par semaine. Garder le même `BUNDLE_ID`.
- Capacités indisponibles : iCloud, notifications push, App Groups. Toutes les données restent donc
  sur l'iPhone (SwiftData), sans synchronisation ni sauvegarde iCloud propre à l'app.

## Développement

- **Après l'ajout ou la suppression d'un fichier Swift**, régénérer le projet : `xcodegen generate`.
  `refresh.sh --force` le fait automatiquement. Sans régénération, Xcode ignore les nouveaux fichiers
  (« cannot find 'X' in scope »).
- Swift 5 (mode de langage), cible iOS 26.0 minimum.

## Dépannage

| Symptôme | Cause / solution |
|---|---|
| « cannot find 'X' in scope », cible `arm64-apple-macos` | Un fichier `.swift` a été ouvert seul dans Xcode : ouvrir `CalorieAdvisor.xcodeproj` |
| « cannot find 'X' in scope » après une mise à jour du code | Nouveau fichier non référencé : `xcodegen generate` |
| « No Account for Team "…" » | `DEVELOPMENT_TEAM` contient le nom de l'équipe au lieu de son identifiant de 10 caractères |
| « No profiles for '…' were found » | Conséquence de l'erreur précédente, ou Apple ID déconnecté de Xcode |
| « The specified device was not found » | `DEVICE_ID` erroné (ou valeur d'exemple) dans `scripts/refresh.config` |
| « iPhone injoignable » | iPhone pas sur le même Wi-Fi, « Connect via network » non coché, ou iPhone éteint |
| L'app ne s'ouvre plus | Signature expirée : `scripts/refresh.sh --force` (sans supprimer l'app) |
| Apple Intelligence « Indisponible » | Appareil non compatible, Apple Intelligence désactivé, ou modèle en cours de téléchargement |

## Structure

```
project.yml                   définition XcodeGen (source du projet Xcode)
Config/                       signature ; Signing.local.xcconfig non versionné
CalorieAdvisor/
  App/                        point d'entrée, onglets
  Models/                     FoodEntry, SavedFood (SwiftData), Nutrients, repas, profil,
                              hydratation, objectif de poids
  Services/                   Santé (EnergyStore), Apple Intelligence, Vision, Open Food Facts,
                              base intégrée, journalisation, statistiques
  Views/                      Journal, Ajout, Tendances, Conseils, Réglages
  Resources/foods_fr.json     base d'aliments (valeurs approximatives de type CIQUAL, pour 100 g/ml)
scripts/
  refresh.sh                  re-signature et réinstallation
  install-launchd.sh          installation de la tâche planifiée
  refresh.config.example      modèle de configuration (DEVICE_ID)
```

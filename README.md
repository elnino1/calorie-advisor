# CalorieAdvisor

App iOS personnelle de suivi calorique (inspirée de Lose It / MyFitnessPal) : visualiser jour après
jour le déficit ou le surplus calorique pour atteindre ses objectifs de santé ou de poids.
Cahier des charges initial : `application_comptage_calorie.md`.

L'app est installée **sans compte Apple Developer payant** (Apple ID gratuit, « Personal Team ») et
re-signée automatiquement par `../ios-updater` sur le Mac, la signature gratuite n'étant valable que 7 jours.

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
  l'objectif du jour est respecté), répartition protéines / glucides / lipides / alcool, fibres par
  rapport au repère de 30 g/jour.
- **Note de composition** (0 à 5, au demi-point) de la journée, boissons comprises, avec les deux pistes
  d'amélioration prioritaires. Six critères notés de 0 à 1 d'après les repères ANSES / OMS :
  protéines (15 à 30 % des calories), fibres (30 g), sucres (≤ 15 % des calories), lipides (20 à 40 %),
  alcool (0 g) et hydratation (objectif du jour). Calcul sur l'appareil, sans IA, à partir de 300 kcal saisies.
- Sections Petit-déjeuner, Déjeuner, Collation, Dîner et **Boissons**, repliables (l'état est mémorisé).
- Toutes les boissons (entrées en ml, hors soupes) vont dans la section Boissons, quel que soit le mode
  de saisie. Carte **Hydratation** : total bu / objectif, détail eau, café/thé, autres, alcool.
  **L'alcool n'est pas compté dans l'hydratation.**

### Tendances (7 jours, 30 jours, 3 mois, 1 an)

Balance quotidienne par rapport à l'objectif, apport comparé à la dépense, balance cumulée convertie
en kg, hydratation par jour, poids (Apple Santé) avec le poids cible, répartition moyenne des apports.
La journée en cours est exclue, de même que les jours sans saisie.

**Bilans par semaine et par mois** (12 dernières semaines ou 12 derniers mois) : déficit ou surplus moyen
par jour, total et équivalent en kg, jours où l'objectif est atteint, note de composition moyenne et
évolution par rapport à la période précédente (en vert si l'on se rapproche de l'objectif).

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

## Installation et rafraîchissement

La compilation, la signature (Apple ID gratuit, valable 7 jours) et l'installation sur l'iPhone sont
gérées par **`../ios-updater`**, commun à toutes les apps personnelles : voir son `README.md`.
Le bundle id et l'équipe sont déclarés dans `../ios-updater/ios-updater.conf`, qui génère
`Config/Signing.local.xcconfig`.

```bash
../ios-updater/ios-updater.sh --force calorie-advisor   # après une modification du code
```

Pour travailler dans Xcode : lancer une fois ios-updater (ou `xcodegen generate` si
`Config/Signing.local.xcconfig` existe déjà), puis `open CalorieAdvisor.xcodeproj`.

> Ouvrir `CalorieAdvisor.xcodeproj`, jamais un fichier `.swift` seul : Xcode créerait sinon un projet
> temporaire compilé pour macOS, avec des erreurs « cannot find … in scope ».

Au premier lancement de l'app, autoriser l'accès à Santé, puis renseigner le profil dans Réglages.
La date d'expiration de la signature est visible dans l'app : Réglages > Application (en rouge à
moins de 2 jours). **Ne jamais supprimer l'app de l'iPhone**, même expirée : la réinstaller conserve
les données.

Limites du compte gratuit : 7 jours par signature, 3 apps par appareil, 10 nouveaux bundle ids par
semaine ; pas d'iCloud, de notifications push ni d'App Groups. Les données restent donc sur l'iPhone
(SwiftData), sans synchronisation.

## Développement

- **Après l'ajout ou la suppression d'un fichier Swift**, régénérer le projet : `xcodegen generate`.
  `ios-updater.sh` le fait automatiquement. Sans régénération, Xcode ignore les nouveaux fichiers
  (« cannot find 'X' in scope »).
- Swift 5 (mode de langage), cible iOS 26.0 minimum.

## Intégration continue

Workflows GitHub Actions standard (skill `github-ci`, dans `.github/workflows/`) :

| Workflow | Déclenchement | Rôle |
|---|---|---|
| `test.yml` (`Test`) | chaque push, toutes branches | génère le projet (XcodeGen), compile l'app sur un simulateur iPhone sans signature ; SwiftLint |
| `auto_pr.yml` | push sur une autre branche que `main` | ouvre (ou met à jour) une PR vers `main`, description tirée des commits |
| `release.yml` | `Test` réussi après un push sur `main` | tag semver (`feat:` → mineure, `BREAKING CHANGE` → majeure, sinon patch) + GitHub Release |

Réglage GitHub requis pour `auto_pr.yml` : Settings → Actions → General → Workflow permissions →
**Allow GitHub Actions to create and approve pull requests**. Messages de commit au format
Conventional Commits (`feat:`, `fix:`, `ci:`…), dont dépend la version.

SwiftLint (`.swiftlint.yml`, règles du skill apple-skills `ci-cd-setup`) : les violations existantes
sont gelées dans `.swiftlint-baseline.json`, seules les nouvelles font échouer la CI. En local :
`swiftlint lint --strict --baseline .swiftlint-baseline.json` (avec
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` si `xcode-select` pointe sur les Command
Line Tools). Après correction de violations anciennes : `swiftlint lint --write-baseline .swiftlint-baseline.json`.

Pas de déploiement TestFlight/App Store (compte Apple Developer payant requis) : l'installation sur
l'iPhone reste assurée par `../ios-updater`.

## Dépannage

| Symptôme | Cause / solution |
|---|---|
| « cannot find 'X' in scope », cible `arm64-apple-macos` | Un fichier `.swift` a été ouvert seul dans Xcode : ouvrir `CalorieAdvisor.xcodeproj` |
| « cannot find 'X' in scope » après une mise à jour du code | Nouveau fichier non référencé : `xcodegen generate` |
| « No Account for Team "…" » | `TEAM_ID` (ios-updater.conf) contient le nom de l'équipe au lieu de son identifiant de 10 caractères |
| « No profiles for '…' were found » | Conséquence de l'erreur précédente, ou Apple ID déconnecté de Xcode |
| « The specified device was not found » | `DEVICE` erroné dans `../ios-updater/ios-updater.conf` |
| « iPhone injoignable » | iPhone pas sur le même Wi-Fi, « Connect via network » non coché, ou iPhone éteint |
| L'app ne s'ouvre plus | Signature expirée : `../ios-updater/ios-updater.sh --force calorie-advisor` (sans supprimer l'app) |
| Apple Intelligence « Indisponible » | Appareil non compatible, Apple Intelligence désactivé, ou modèle en cours de téléchargement |

## Structure

```
project.yml                   définition XcodeGen (source du projet Xcode)
Config/                       signature ; Signing.local.xcconfig généré par ios-updater
.github/workflows/            CI : Test, Auto PR, Release
.swiftlint.yml                règles SwiftLint ; .swiftlint-baseline.json : violations existantes
CalorieAdvisor/
  App/                        point d'entrée, onglets
  Models/                     FoodEntry, SavedFood (SwiftData), Nutrients, repas, profil,
                              hydratation, objectif de poids
  Services/                   Santé (EnergyStore), Apple Intelligence, Vision, Open Food Facts,
                              base intégrée, journalisation, statistiques
  Views/                      Journal, Ajout, Tendances, Conseils, Réglages
  Resources/foods_fr.json     base d'aliments (valeurs approximatives de type CIQUAL, pour 100 g/ml)
```

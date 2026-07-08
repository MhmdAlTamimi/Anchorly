# Anchorly

A calm, private place for the small work of a life — what you mean to do, what
you want to remember, who you're trying to become. **Offline and yours.**

Anchorly is a single Android app bundling four independent tools under one
consistent design:

- **Todo** — a to-do list that tidies itself up each new day.
- **Notes** — rich-text notes with proper Arabic (RTL) + English (LTR) support.
- **Journal** — a habit tracker with a monthly calendar per habit.
- **Check-in** — quick timestamped records of how you feel (emotion chips), with
  an optional note and an optional urge log; grouped by day.

Everything is stored **locally** on the phone (SQLite). No accounts, no cloud,
no network. Built with Flutter and delivered as a downloadable APK built
automatically by GitHub Actions.

---

## Table of contents

1. [How the app is built (architecture)](#how-the-app-is-built-architecture)
2. [Running it yourself (developer setup)](#running-it-yourself-developer-setup)
3. [Getting the APK from GitHub](#getting-the-apk-from-github)
4. [Installing / updating on your phone](#installing--updating-on-your-phone)
5. [Set up seamless updates (signing) — step by step](#set-up-seamless-updates-signing--step-by-step)
6. [Why a new APK doesn't wipe your data](#why-a-new-apk-doesnt-wipe-your-data)
7. [versionCode vs versionName](#versioncode-vs-versionname)
8. [Extending the app (adding a 4th tab)](#extending-the-app-adding-a-4th-tab)

---

## How the app is built (architecture)

The code is organized **feature-first** — everything for a tab lives in its own
folder, so you can work on one tab without hunting across the whole codebase.

```
lib/
  main.dart                 # entry point
  app.dart                  # MaterialApp: theme + localization
  home_shell.dart           # bottom navigation + the 3 tabs
  core/
    theme/
      theme.dart            # THE palette (navy/teal/gold) — the only place colors live
      tokens.dart           # spacing / radius / elevation scale
    database/
      database.dart         # all drift tables + DAOs (the data model)
      db.dart               # the single shared database instance
  shared/
    text_direction.dart     # Arabic RTL / English LTR detection
    confirm_dialog.dart     # reusable "are you sure?" dialog
  features/
    todo/    todo_page.dart
    notes/   notes_page.dart, note_editor_page.dart
    journal/ journal_page.dart, habit_calendar_page.dart
    checkin/ checkin_page.dart, checkin_editor.dart
ci/
  app_build.gradle          # signing-aware Android build config (see below)
.github/workflows/build.yml # the APK build pipeline
```

**Tech choices (and why):**

| Layer      | Choice                         | Why |
|------------|--------------------------------|-----|
| Framework  | Flutter (Material 3)           | One codebase → real APK; great RTL/LTR; smooth animations. |
| Local DB   | `drift` (SQLite)               | Type-safe queries **and** schema migrations, so adding a field later doesn't wipe existing data. |
| Rich text  | `flutter_quill`                | Bold/italic/sizes/checklist, stored as a structured "delta" (JSON). |
| Calendar   | `table_calendar`               | Mature monthly calendar for the Journal. |
| CI/CD      | GitHub Actions                 | Builds a downloadable APK on every push to `main`. |

**A note on generated code:** `drift` generates database code (`database.g.dart`)
from the table definitions. That generated file is **not** committed — CI runs
`dart run build_runner build` to produce it during each build. Same idea for the
Android `android/` folder: it's generated fresh in CI by `flutter create`, and
our custom signing config (`ci/app_build.gradle`) is copied over the top. This
keeps the repo small and avoids committing binary/generated files.

---

## Running it yourself (developer setup)

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(3.27.x recommended, matching CI) and an Android device or emulator.

```bash
# 1. Get packages
flutter pub get

# 2. Generate the drift database code (the *.g.dart files)
dart run build_runner build --delete-conflicting-outputs

# 3. If you don't already have an android/ folder, generate it:
flutter create --platforms=android --org com.anchorly .
cp ci/app_build.gradle android/app/build.gradle   # optional: use our build config

# 4. Run on a connected device / emulator
flutter run
```

> Tip: while developing, `dart run build_runner watch` regenerates the database
> code automatically whenever you edit `database.dart`.

---

## Getting the APK from GitHub

Every push to `main` builds an APK automatically. To download it:

1. Go to the repo's **Actions** tab on GitHub.
2. Click the most recent **Build APK** run (green check = success).
3. Scroll to the **Artifacts** section at the bottom.
4. Download **`anchorly-apk`** — it's a `.zip`; unzip it to get
   `anchorly-v1.0.0-buildN.apk`.

You can also trigger a build manually: **Actions → Build APK → Run workflow**.

---

## Installing / updating on your phone

1. Copy the `.apk` file to your Android phone (email it to yourself, use a USB
   cable, Google Drive, etc.).
2. Tap the file. Android will ask to allow installing from this source:
   **Settings → Apps → Special access → Install unknown apps** → enable it for
   the app you're installing from (e.g. Files or Chrome).
3. Tap **Install**.

To **update** later, just install a newer APK the same way — as long as the
signing key, `applicationId`, and increasing `versionCode` are consistent (see
below), it installs over the old one and **keeps all your data**.

---

## Set up seamless updates (signing) — step by step

By default, CI builds a **debug-signed** APK. That installs fine for testing,
but debug keys aren't stable enough to guarantee smooth updates. For real
install-over-update behavior, give the project **one stable release key** and
store it in GitHub Secrets. Do this **once**.

### Step 1 — Generate a keystore (on your computer)

You need the Java JDK installed (it provides `keytool`). Run:

```bash
keytool -genkey -v \
  -keystore anchorly-release.jks \
  -alias anchorly \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storetype JKS
```

It will ask for:
- a **keystore password** (remember it — this is `KEYSTORE_PASSWORD`),
- your name/organization (any values are fine),
- a **key password** (you can reuse the keystore password — this is `KEY_PASSWORD`).

The alias you passed (`anchorly`) is `KEY_ALIAS`.

> ⚠️ **Back up `anchorly-release.jks` and its passwords somewhere safe.** If you
> ever lose this key, you can no longer ship updates that install over the
> existing app — you'd have to uninstall (losing data) and reinstall. Do **not**
> commit the `.jks` file to git (it's already in `.gitignore`).

### Step 2 — Turn the keystore into text (base64)

GitHub Secrets store text, not binary files, so encode the keystore:

```bash
# macOS / Linux:
base64 -i anchorly-release.jks | tr -d '\n' > anchorly-release.b64
# The file anchorly-release.b64 now holds the value for KEYSTORE_BASE64.
```

(On Linux you can also use `base64 -w0 anchorly-release.jks > anchorly-release.b64`.)

### Step 3 — Add four GitHub Secrets

In the repo: **Settings → Secrets and variables → Actions → New repository
secret**. Add these four:

| Secret name         | Value |
|---------------------|-------|
| `KEYSTORE_BASE64`   | the entire contents of `anchorly-release.b64` |
| `KEYSTORE_PASSWORD` | the keystore password from Step 1 |
| `KEY_PASSWORD`      | the key password from Step 1 |
| `KEY_ALIAS`         | `anchorly` (or whatever alias you used) |

### Step 4 — Rebuild

Push any commit to `main` (or run the workflow manually). The build now signs
the APK with your stable release key. **Important:** the *first* time you switch
from debug-signed to release-signed, Android will refuse to update over the old
debug build — uninstall the old app once, then install the release-signed APK.
From then on, every future update installs over the top and keeps your data.

If the secrets are absent, the workflow simply logs "No KEYSTORE_BASE64 secret
found" and builds a debug-signed APK — CI never fails just because signing isn't
set up yet.

---

## Why a new APK doesn't wipe your data

The APK is **only your code**. Your todos, notes, and journal live in a SQLite
file in the app's private storage on the phone — a completely separate thing
from the APK. Installing a new version keeps that file **only if all three of
these hold**:

| Rule | Why it matters |
|------|----------------|
| **`applicationId` never changes** (`com.anchorly.app`) | Android identifies apps by this string. Change it and Android thinks it's a *different* app — it installs side-by-side and the old data is orphaned. |
| **`versionCode` always increases** | Android only allows install-over-update when the new `versionCode` is higher. CI sets it from the GitHub run number, which always goes up. |
| **The signing key stays the same** | If the key changes between builds, Android refuses the update and forces a data-wiping reinstall. This is the #1 gotcha — hence the stable keystore in Secrets above. |

Get those three right and updates are seamless. (There's a fourth quiet helper:
`drift` schema **migrations** — when you add a column later, they reshape the
existing database instead of recreating it. See `database.dart`.)

---

## versionCode vs versionName

Two different "versions" that people constantly confuse:

- **`versionName`** — the human-readable label, like `1.0.0`. Shown to you in
  the app's info screen. It's just a string; Android doesn't use it to decide
  anything. Anchorly's is set in `pubspec.yaml` (`version: 1.0.0+1`).
- **`versionCode`** — an internal **integer** Android actually uses to decide
  "is this an update?" It must strictly increase. CI sets it automatically from
  the GitHub **run number** (`--build-number`), so every build is higher than
  the last without you thinking about it.

In `pubspec.yaml`'s `version: 1.0.0+1`, the `1.0.0` is the versionName and the
`+1` is the (default) versionCode — but CI overrides that `+1` with the run
number at build time.

---

## Extending the app (adding a 4th tab)

Because the app is feature-first, adding a tab is self-contained:

1. Create `lib/features/<name>/<name>_page.dart`.
2. If it needs storage, add a table + DAO in `core/database/database.dart`,
   **bump `schemaVersion`**, and add an `onUpgrade` migration step (never edit
   old migrations — that's what protects existing data).
3. Add the page and a `NavigationDestination` to the two lists in
   `home_shell.dart`.

No other tab needs to change. Re-run `dart run build_runner build` after
touching the database, and push — CI builds the new APK.

---

Built to be read and extended. Every module's main file opens with a comment
describing its data model and behavior, and non-obvious decisions are explained
inline in the code.

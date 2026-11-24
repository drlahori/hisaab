# Hisaab — money manager, no ads

Version 1.1: automatic backups (daily, weekly, 15 or 30 days), choice of app icon, transactions (daily / calendar / monthly), income, expense and transfers,
accounts with balances, stats with category chart, monthly budgets, search,
custom categories and currency, backup and restore, CSV export for Excel.

Backups: **More → Back up now** opens the share sheet. Pick Google Drive, Gmail,
iCloud, Files or anything else on the phone. **Restore from backup** picks that file back.

## Get the app

Every push to `main` builds a new APK on GitHub. Download **hisaab.apk** from the
[Releases](../../releases) page on your Android phone and install it.

Builds are signed with a permanent key stored in the `HISAAB_KEYSTORE` repository secret,
so each new APK installs over the previous one and keeps your data.

## Building on a Mac (optional)



Needs Homebrew and Xcode (from the App Store, opened once).

```
cd ~/Downloads/hisaab
bash setup.sh
```

## Run it

Android phone, plugged in with USB debugging on:
```
flutter run
```

iPhone simulator:
```
open -a Simulator
flutter run
```

## Run on your iPhone

1. Plug the iPhone in and tap **Trust** on the phone.
2. Run `open ios/Runner.xcworkspace`. In Xcode click **Runner** (left) → **Signing & Capabilities**
   → **Team** → **Add an Account…** and sign in with your Apple ID, then pick it as the Team.
   If it complains about the Bundle Identifier, change it to something unique, e.g.
   `com.gillani.hisaab.app`.
3. On the iPhone: **Settings → Privacy & Security → Developer Mode → On** (it restarts).
4. Back in Terminal: `flutter run` and choose the iPhone.
5. First launch only: **Settings → General → VPN & Device Management** → your Apple ID → **Trust**.

With a free Apple ID the app stops opening after 7 days; run `flutter run` again to refresh it.
A paid Apple Developer account ($99/year) removes that limit and allows App Store release.

## Your data

Stored on the phone in the app's own folder. Uninstalling the app deletes it, so back up first.

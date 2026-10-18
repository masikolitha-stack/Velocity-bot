# Velocity Gold Bot Android companion — Version 1

## What this APK project is
This is an Android companion-dashboard starter project for Velocity Gold Bot. It can be built into an installable debug APK. It is **not** an MT5 trading terminal, and it does not yet connect to MT5, retrieve account data, or send/close orders.

The trading EA is a separate MQL5 file (`Velocity_Gold_Bot_V1.mq5`) and must run in MT5 on a Windows PC or compatible VPS.

## Build APK using GitHub Actions (phone-friendly workflow)
1. Create a new GitHub repository and upload the contents of this folder (not the ZIP itself).
2. Make sure `.github/workflows/build-apk.yml` is included.
3. Open the repository's **Actions** tab.
4. Select **Build Android APK**, then tap **Run workflow** (or push to `main` to trigger a build).
5. Open the completed workflow run, find **Artifacts**, and download `Velocity-Gold-Bot-debug-apk`.
6. Extract the artifact ZIP on your Android phone and tap `app-debug.apk` to install. Android may ask you to allow installs from that source.
7. Only install APKs you built from code you trust.

## Trading EA setup
Use the separate `Velocity_Gold_Bot_V1.mq5` file in MT5's `MQL5/Experts` directory, compile in MetaEditor, and demo-test first. Keep `DemoOnly=true`. No strategy guarantees profits.

## Important
The companion APK is not yet linked to the EA. Live monitoring and trade controls would require a separately secured communication service/API on the VPS; do not put MT5 passwords or broker credentials in the APK or public repository.

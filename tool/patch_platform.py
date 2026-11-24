"""Run after `flutter create`: app name, icons, icon switching, backup folder access.

Usage: python3 tool/patch_platform.py
"""
import glob
import json
import os
import re
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS = ["teal", "navy", "coral", "gold"]
ALIAS = {n: "Icon" + n.capitalize() for n in ICONS}


def android():
    res_src = os.path.join(ROOT, "platform/android/res")
    res_dst = os.path.join(ROOT, "android/app/src/main/res")
    if not os.path.isdir(res_dst):
        print("android/ not found, skipping")
        return
    shutil.copytree(res_src, res_dst, dirs_exist_ok=True)

    path = os.path.join(ROOT, "android/app/src/main/AndroidManifest.xml")
    s = open(path, encoding="utf-8").read()
    if "activity-alias" in s:
        print("manifest already patched")
    else:
        s = re.sub(r'android:label="[^"]*"', 'android:label="Hisaab"', s, count=1)
        s = s.replace('android:icon="@mipmap/ic_launcher"',
                      'android:icon="@mipmap/ic_hisaab_teal"', 1)
        s = s.replace("<application", '<application\n        android:requestLegacyExternalStorage="true"', 1)
        s, n = re.subn(
            r'\s*<intent-filter>\s*<action android:name="android.intent.action.MAIN"\s*/>\s*'
            r'<category android:name="android.intent.category.LAUNCHER"\s*/>\s*</intent-filter>',
            "", s, count=1)
        if n != 1:
            raise SystemExit("Could not find the launcher intent-filter in AndroidManifest.xml")
        aliases = ""
        for i, name in enumerate(ICONS):
            aliases += f'''
        <activity-alias
            android:name=".{ALIAS[name]}"
            android:targetActivity=".MainActivity"
            android:enabled="{"true" if i == 0 else "false"}"
            android:exported="true"
            android:label="Hisaab"
            android:icon="@mipmap/ic_hisaab_{name}"
            android:roundIcon="@mipmap/ic_hisaab_{name}">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity-alias>'''
        s = s.replace("</application>", aliases + "\n    </application>", 1)
        open(path, "w", encoding="utf-8").write(s)

    mains = glob.glob(os.path.join(ROOT, "android/app/src/main/kotlin/**/MainActivity.kt"), recursive=True)
    if len(mains) != 1:
        raise SystemExit(f"Expected one MainActivity.kt, found {mains}")
    pkg = re.search(r"^package\s+([\w.]+)", open(mains[0]).read(), re.M).group(1)
    tpl = open(os.path.join(ROOT, "platform/android/MainActivity.kt.txt")).read()
    open(mains[0], "w").write(tpl.replace("__PACKAGE__", pkg))
    print("android patched")


def ios():
    plist = os.path.join(ROOT, "ios/Runner/Info.plist")
    if not os.path.isfile(plist):
        return
    s = open(plist, encoding="utf-8").read()
    s = re.sub(r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)", r"\1Hisaab\2", s)
    for key in ("UIFileSharingEnabled", "LSSupportsOpeningDocumentsInPlace"):
        if key not in s:
            s = s.replace("<dict>", f"<dict>\n\t<key>{key}</key>\n\t<true/>", 1)
    open(plist, "w", encoding="utf-8").write(s)

    iconset = os.path.join(ROOT, "ios/Runner/Assets.xcassets/AppIcon.appiconset")
    if os.path.isdir(iconset):
        for f in os.listdir(iconset):
            os.remove(os.path.join(iconset, f))
        shutil.copy(os.path.join(ROOT, "platform/ios/AppIcon-1024.png"),
                    os.path.join(iconset, "AppIcon-1024.png"))
        json.dump({"images": [{"filename": "AppIcon-1024.png", "idiom": "universal",
                               "platform": "ios", "size": "1024x1024"}],
                   "info": {"author": "xcode", "version": 1}},
                  open(os.path.join(iconset, "Contents.json"), "w"), indent=2)
    print("ios patched")


android()
ios()

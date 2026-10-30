"""Build metadata and validate an Android release before making it discoverable."""
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

APP_ID = "app.microfantasy.microfantasy"
REPOSITORY = "Asdii/V90-Fantasy-Designer"
OUT = Path("build/release")


def version_metadata(run_number, sha, timestamp):
    # Seconds since 2020 stay within Android's positive 31-bit versionCode limit.
    # Unlike commit counts, this also increases after rebase or a workflow rename.
    code = int(timestamp) - 1577836800
    if not 2 < code <= 2100000000 or not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise ValueError("Invalid build timestamp or commit")
    if not str(run_number).isdigit() or int(run_number) < 1:
        raise ValueError("Invalid workflow run number")
    return {"name": f"1.0.{int(run_number)}", "code": code,
            "tag": f"microfantasy-b{code}", "commit": sha}


def manifest(metadata, digest, certificate):
    if not re.fullmatch(r"[a-fA-F0-9]{64}", certificate):
        raise ValueError("Invalid signing certificate")
    return {"schemaVersion": 1, "versionName": metadata["name"],
            "versionCode": metadata["code"], "applicationId": APP_ID,
            "apkUrl": f"https://github.com/{REPOSITORY}/releases/download/{metadata['tag']}/microfantasy.apk",
            "sha256": digest, "certificateSha256": certificate.lower(),
            "notes": f"Actualización de V90 / MicroFantasy · {metadata['commit'][:7]}"}


def prepare():
    if os.environ["GITHUB_REPOSITORY"] != REPOSITORY:
        raise ValueError("Update repository must match the repository configured in the app")
    metadata = version_metadata(os.environ["GITHUB_RUN_NUMBER"], os.environ["GITHUB_SHA"], time.time())
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "metadata.json").write_text(json.dumps(metadata), encoding="utf-8")
    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
        for key in ("name", "code", "tag"):
            output.write(f"{key}={metadata[key]}\n")


def verified_certificate(output, expected):
    """Parse verified apksigner output across Android build-tools versions.

    Call only after apksigner exits successfully. Source stamps and historical
    lineage certificates are not the APK's signing identity.
    """
    expected = expected.strip().lower()
    if not re.fullmatch(r"[a-f0-9]{64}", expected):
        raise ValueError("Invalid expected signing certificate")
    certificates = re.findall(
        r"^(?:V\d+(?:\.\d+)* )?Signer(?: #\d+)?(?::)?"
        r"(?: \(minSdkVersion=[^\r\n]*\))? certificate SHA-256 digest: ([a-fA-F0-9]{64})\s*$",
        output, re.MULTILINE)
    counts = re.findall(r"^Number of signers: (\d+)\s*$", output, re.MULTILINE)
    if any(int(count) != 1 for count in counts):
        raise ValueError("Expected exactly one verified APK signer")
    identities = {certificate.lower() for certificate in certificates}
    if not identities:
        raise ValueError("No APK signing certificate recognized in apksigner output")
    if identities != {expected}:
        raise ValueError("APK signing certificate differs from the configured update identity")
    return expected


def package():
    metadata = json.loads((OUT / "metadata.json").read_text(encoding="utf-8"))
    sdk = Path(os.environ.get("ANDROID_HOME") or os.environ["ANDROID_SDK_ROOT"])
    folders = [p for p in (sdk / "build-tools").iterdir() if re.fullmatch(r"\d+\.\d+\.\d+", p.name)]
    tools = max(folders, key=lambda p: tuple(map(int, p.name.split("."))))
    apk = Path("build/app/outputs/flutter-apk/app-release.apk")
    signer = tools / ("apksigner.bat" if os.name == "nt" else "apksigner")
    aapt = tools / ("aapt.exe" if os.name == "nt" else "aapt")
    print(f"Verifying APK with Android build-tools {tools.name}", flush=True)
    signed = subprocess.check_output([str(signer), "verify", "--verbose", "--print-certs", str(apk)], text=True)
    # Certificate fingerprints are public; preserve diagnostic output in CI.
    print(signed, flush=True)
    certificate = verified_certificate(signed, os.environ.get("EXPECTED_CERTIFICATE_SHA256", ""))
    badging = subprocess.check_output([str(aapt), "dump", "badging", str(apk)], text=True)
    package_info = re.search(r"package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'", badging)
    if not package_info or package_info.groups() != (APP_ID, str(metadata["code"]), metadata["name"]):
        raise ValueError("APK package/version does not match release metadata")
    if "application-debuggable" in badging:
        raise ValueError("Cannot publish a debuggable APK")
    digest = hashlib.sha256(apk.read_bytes()).hexdigest()
    data = manifest(metadata, digest, certificate)
    shutil.copyfile(apk, OUT / "microfantasy.apk")
    (OUT / "microfantasy-update.json").write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    today = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    (OUT / "notes.md").write_text(
        f"MicroFantasy {metadata['name']} · {today}\n\n"
        f"Commit: {metadata['commit']}\n\n"
        "Descarga microfantasy.apk y confirma Actualizar en Android. "
        "No desinstales la versión anterior: se conservan los datos.\n\n"
        f"SHA-256 del APK: `{digest}`\n", encoding="utf-8")
    print(f"Verified release {metadata['tag']}; APK and manifest ready.")


if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in ("prepare", "package"):
        raise SystemExit("Usage: android_release.py prepare|package")
    {"prepare": prepare, "package": package}[sys.argv[1]]()

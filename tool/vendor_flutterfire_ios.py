"""Vendors FlutterFire plugins whose iOS Package.swift breaks on Windows.

Their manifests derive their own directory with `URL(string: #file)`, which
parses `C:` as a URL scheme on Windows, so xcross cannot resolve them.
This copies each plugin from the pub cache into third_party/, replaces that
expression with a separator-agnostic string split, and puts a copy of the
package pubspec.yaml next to the manifest's folder. Dart code is untouched.
"""
import os
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE = Path(os.environ["LOCALAPPDATA"]) / "Pub" / "Cache" / "hosted" / "pub.dev"

PACKAGES = {
    "firebase_core": "3.15.2",
    "cloud_firestore": "5.6.12",
    "firebase_auth": "5.7.0",
    "firebase_crashlytics": "4.3.10",
    "firebase_analytics": "11.6.0",
}

PATTERN = re.compile(
    r"let (\w+) = String\(URL\(string: #file\)!\.deletingLastPathComponent\(\)\.absoluteString\s*\.dropLast\(\)\)"
)

PUBSPEC = re.compile(r'("\.\.",\s*)"\.\.",\s*"pubspec\.yaml"')

REPLACEMENT = (
    "let \\1: String = {\n"
    "  let file = \"\\(#filePath)\"\n"
    "  guard let cut = file.lastIndex(where: { $0 == \"/\" || $0 == \"\\\\\\\\\" }) else { return \".\" }\n"
    "  return String(file[..<cut])\n"
    "}()"
)


def main() -> None:
    for name, version in PACKAGES.items():
        src = CACHE / f"{name}-{version}"
        dst = ROOT / "third_party" / name
        if dst.exists():
            shutil.rmtree(dst)
        shutil.copytree(src, dst, ignore=shutil.ignore_patterns("example", "test"))
        for manifest in dst.glob("*/*/Package.swift"):
            text = manifest.read_text(encoding="utf-8")
            patched, count = PATTERN.subn(REPLACEMENT, text)
            # xcross stages only the platform folder, so the package root's
            # pubspec.yaml must be readable from inside it.
            patched = PUBSPEC.sub(r'\1"pubspec.yaml"', patched)
            shutil.copy2(dst / "pubspec.yaml", manifest.parent.parent / "pubspec.yaml")
            if patched != text:
                manifest.write_text(patched, encoding="utf-8")
            print(f"{name}: {manifest.relative_to(dst)} patched={count}")


if __name__ == "__main__":
    main()

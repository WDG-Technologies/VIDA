#!/usr/bin/env python3
"""Rebuild assets/data/iglesias_mexico.json from tool/overpass_raw.json."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW = Path(__file__).resolve().parent / "overpass_raw.json"
OUT = ROOT / "assets" / "data" / "iglesias_mexico.json"


def main() -> None:
    raw = json.loads(RAW.read_text(encoding="utf-8"))
    seen: set[str] = set()
    out: list[dict] = []
    for e in raw.get("elements", []):
        lat = e.get("lat")
        lon = e.get("lon")
        if lat is None and "center" in e:
            lat = e["center"].get("lat")
            lon = e["center"].get("lon")
        if lat is None or lon is None:
            continue
        tags = e.get("tags") or {}
        name = (tags.get("name") or "").strip()
        if len(name) < 3:
            continue
        denom = (tags.get("denomination") or "").lower()
        name_l = name.lower()
        if "catholic" in denom or "catolic" in denom:
            continue
        if "catolic" in name_l or "católic" in name_l:
            continue
        city = (
            tags.get("addr:city")
            or tags.get("addr:municipality")
            or tags.get("addr:state")
            or "México"
        )
        parts: list[str] = []
        if tags.get("denomination"):
            parts.append(f"Denominación: {tags['denomination']}")
        street = tags.get("addr:street")
        if street:
            hn = tags.get("addr:housenumber")
            parts.append(f"{street} {hn}".strip() if hn else street)
        desc = (
            " · ".join(parts)
            if parts
            else "Iglesia cristiana protestante / evangélica (OpenStreetMap)"
        )
        key = f"{name}|{round(float(lat), 4)}|{round(float(lon), 4)}".lower()
        if key in seen:
            continue
        seen.add(key)
        out.append(
            {
                "osm_id": f"{e.get('type')}/{e.get('id')}",
                "nombre": name,
                "ciudad": str(city).strip(),
                "descripcion": desc,
                "latitud": round(float(lat), 6),
                "longitud": round(float(lon), 6),
            }
        )
    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {len(out)} churches -> {OUT}")


if __name__ == "__main__":
    main()

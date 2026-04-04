#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
from pathlib import Path
from typing import Any

from warmane_balance_benchmark import load_runtime_tables, get_class_spec_candidates


REPO_ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = REPO_ROOT / "tools" / "data" / "wowhead_wotlk_pve_guides.json"
OUTPUT_DIR = REPO_ROOT / "output"

SUPPORT_NOTES: dict[str, dict[str, Any]] = {
    "DRUID_BALANCE": {
        "support_status": "exact_match",
        "support_path": "direct_profile",
        "notes": "Audit keeps Balance as a direct profile. Wowhead gear lists justify cloth tolerance on druid caster/healer profiles instead of hard-rejecting cloth."
    },
    "DRUID_RESTORATION": {
        "support_status": "exact_match",
        "support_path": "direct_profile",
        "notes": "Audit keeps Restoration as a direct profile. Repeated cloth healer usage is treated as a compatibility exception, not a profile split."
    },
    "PRIEST_HOLY": {
        "support_status": "new_profile_added",
        "support_path": "direct_profile",
        "notes": "Holy Priest is a Wowhead-supported PvE archetype and now has an explicit runtime and benchmark profile instead of falling through to non-holy profiles."
    },
    "DRUID_FERAL_DPS": {
        "support_status": "split_profile_added",
        "support_path": "druid_feral_tree_split",
        "notes": "Cat DPS now resolves from the shared feral talent tree into a dedicated DPS profile with DPS-oriented cap behavior."
    },
    "DRUID_FERAL_TANK": {
        "support_status": "split_profile_added",
        "support_path": "druid_feral_tree_split",
        "notes": "Bear tank now resolves from the shared feral talent tree into a dedicated tank profile. Tank feral inference does not require classic shield/defense signature items."
    },
}


def build_audit_rows() -> tuple[list[dict[str, Any]], dict[str, Any]]:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    runtime_tables = load_runtime_tables(REPO_ROOT)
    tables = runtime_tables["Tables"]
    phases = manifest["phases"]
    rows: list[dict[str, Any]] = []
    summary = {
        "phase_scope": phases,
        "guide_count": len(manifest["guides"]),
        "profile_status_counts": {},
        "support_path_counts": {},
    }
    for guide in manifest["guides"]:
        class_token = guide["class"]
        archetype = guide["build_archetype"]
        spec_profiles = tables["SpecProfiles"]
        class_candidates = get_class_spec_candidates(class_token, runtime_tables)
        profile_present = archetype in spec_profiles
        note = SUPPORT_NOTES.get(archetype, {})
        support_status = note.get("support_status")
        if not support_status:
            support_status = "exact_match" if profile_present else "missing_profile"
        support_path = note.get("support_path", "direct_profile" if archetype in class_candidates else "manual_review")
        notes = note.get("notes", "Direct Wowhead archetype match; keep under manual weight/cap review.")
        mismatch_categories: list[str] = []
        if not profile_present:
            mismatch_categories.append("missing_profile")
        if support_path == "druid_feral_tree_split":
            mismatch_categories.append("spec_resolution_mismatch")
        if archetype in {"DRUID_BALANCE", "DRUID_RESTORATION"}:
            mismatch_categories.append("compatibility_mismatch")

        summary["profile_status_counts"][support_status] = summary["profile_status_counts"].get(support_status, 0) + 1
        summary["support_path_counts"][support_path] = summary["support_path_counts"].get(support_path, 0) + 1

        for phase in phases:
            rows.append(
                {
                    "class": class_token,
                    "build_archetype": archetype,
                    "phase": phase,
                    "role": guide["role"],
                    "url": guide["url"],
                    "runtime_profile_key": archetype if profile_present else "",
                    "support_status": support_status,
                    "support_path": support_path,
                    "mismatch_categories": "; ".join(mismatch_categories),
                    "notes": notes,
                }
            )
    return rows, summary


def main() -> None:
    rows, summary = build_audit_rows()
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    csv_path = OUTPUT_DIR / "wowhead_profile_audit.csv"
    json_path = OUTPUT_DIR / "wowhead_profile_audit.json"
    fieldnames = [
        "class",
        "build_archetype",
        "phase",
        "role",
        "url",
        "runtime_profile_key",
        "support_status",
        "support_path",
        "mismatch_categories",
        "notes",
    ]
    with csv_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    json_path.write_text(json.dumps({"summary": summary, "records": rows}, indent=2), encoding="utf-8")
    print(f"Wrote {csv_path}")
    print(f"Wrote {json_path}")


if __name__ == "__main__":
    main()

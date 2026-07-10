import argparse
import json
import shutil
from pathlib import Path


DEFAULT_BASE_URL = "http://8.163.115.183/guoguo/worksheets/"


def _load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def _rewrite_image_refs(value, base_url: str):
    if isinstance(value, list):
        return [_rewrite_image_refs(item, base_url) for item in value]
    if isinstance(value, dict):
        return {key: _rewrite_image_refs(item, base_url) for key, item in value.items()}
    if isinstance(value, str) and value.startswith("assets/worksheets/images/"):
        relative = value.removeprefix("assets/worksheets/images/")
        return f"{base_url}images/{relative}"
    return value


def build_package(source_root: Path, output_root: Path, base_url: str) -> int:
    if not base_url.endswith("/"):
        base_url = f"{base_url}/"

    if output_root.exists():
        shutil.rmtree(output_root)
    (output_root / "generated").mkdir(parents=True, exist_ok=True)

    images_source = source_root / "images"
    if images_source.exists():
        shutil.copytree(images_source, output_root / "images")
    else:
        (output_root / "images").mkdir(parents=True, exist_ok=True)

    catalog = _load_json(source_root / "index.json")
    remote_sets = []
    for item in catalog.get("sets", []):
        source_asset = item.get("asset", "")
        source_path = Path(source_asset)
        if not source_path.exists():
            continue
        worksheet = _rewrite_image_refs(_load_json(source_path), base_url)
        output_file = output_root / "generated" / source_path.name
        _write_json(output_file, worksheet)

        remote_item = dict(item)
        remote_item["asset"] = f"generated/{source_path.name}"
        remote_sets.append(remote_item)

    _write_json(
        output_root / "index.json",
        {
            "version": 1,
            "baseUrl": base_url,
            "sets": remote_sets,
        },
    )
    return len(remote_sets)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build a server-ready worksheet package.",
    )
    parser.add_argument(
        "--source",
        default="assets/worksheets",
        help="Local worksheet asset root.",
    )
    parser.add_argument(
        "--out",
        default="dist/worksheets_upload",
        help="Output directory for the server package.",
    )
    parser.add_argument(
        "--base-url",
        default=DEFAULT_BASE_URL,
        help="Public URL that serves the worksheet package directory.",
    )
    args = parser.parse_args()

    count = build_package(Path(args.source), Path(args.out), args.base_url)
    print(f"Generated {count} worksheet entries in {args.out}")


if __name__ == "__main__":
    main()

"""Create a text-only Qwen3.5 loader view without copying or modifying weights."""

import argparse
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    source = args.source.expanduser().resolve()
    config = json.loads((source / "config.json").read_text())
    model_type, architecture = {
        "qwen3_5_text": ("qwen3_5", "Qwen3_5ForConditionalGeneration"),
        "qwen3_5_moe_text": ("qwen3_5_moe", "Qwen3_5MoeForConditionalGeneration"),
    }[config["text_config"]["model_type"]]
    original_type = config["model_type"]
    config["model_type"] = model_type
    config["architectures"] = [architecture]
    destination = args.destination.expanduser().absolute()
    destination.mkdir(parents=True)
    (destination / "config.json").write_text(json.dumps(config, indent=2) + "\n")
    for path in source.iterdir():
        if path.is_file() and path.name not in {"config.json", "source.json"}:
            (destination / path.name).symlink_to(path)
    (destination / "source.json").write_text(json.dumps({
        "source": str(source),
        "original_model_type": original_type,
        "scope": "text-only",
    }, indent=2) + "\n")
    print(destination)


if __name__ == "__main__":
    main()

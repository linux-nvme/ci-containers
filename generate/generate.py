#!/usr/bin/env python3

import argparse
import sys
from pathlib import Path

import yaml
from jinja2 import Environment, FileSystemLoader


CONFIG_FILE = "ci-containers.yaml"
TEMPLATE_DIR = "templates"


def load_config():
    with open(CONFIG_FILE, "r") as f:
        return yaml.safe_load(f)


def build_package_list(config, distro, bundle_list):
    packages = []

    for bundle in bundle_list:
        if bundle not in config["bundles"]:
            print(f"Unknown bundle: {bundle}")
            sys.exit(1)

        bundle_block = config["bundles"][bundle]

        if distro not in bundle_block:
            print(f"Bundle '{bundle}' not defined for distro '{distro}'")
            sys.exit(1)

        packages.extend(bundle_block[distro])

    # Deduplicate while preserving order
    seen = set()
    deduped = []
    for pkg in packages:
        if pkg not in seen:
            deduped.append(pkg)
            seen.add(pkg)

    return deduped


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--distro", required=True,
                        choices=["debian", "fedora", "tumbleweed"])
    parser.add_argument("--bundles", required=True,
                        help="Comma separated bundle list (e.g. base,python)")
    parser.add_argument("--output", default=None)

    args = parser.parse_args()

    config = load_config()

    bundle_list = [f.strip() for f in args.bundles.split(",")]
    packages = build_package_list(config, args.distro, bundle_list)

    base_image = config["base_images"][args.distro]

    env = Environment(
        loader=FileSystemLoader(TEMPLATE_DIR),
        trim_blocks=True,
        lstrip_blocks=True,
    )

    template = env.get_template(f"Dockerfile.{args.distro}.j2")

    rendered = template.render(
        base_image=base_image,
        packages=packages,
    )

    output_file = args.output or f"Dockerfile.{args.distro}"

    with open(output_file, "w") as f:
        f.write(rendered)

    print(f"Generated {output_file} "
          f"(distro={args.distro}, bundles={args.bundles})")


if __name__ == "__main__":
    main()

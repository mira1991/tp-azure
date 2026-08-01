#!/usr/bin/env python3
"""Vérification (lecture seule) de la disponibilité des images Kolla requises
dans la registry, avant tout déploiement."""

from __future__ import annotations

import argparse
import os
import sys

import requests

CORE_IMAGES = [
    "kolla-toolbox",
    "fluentd",
    "cron",
    "haproxy",
    "keepalived",
    "mariadb-server",
    "rabbitmq",
    "memcached",
    "keystone",
    "glance-api",
    "nova-api",
    "nova-compute",
    "nova-libvirt",
    "neutron-server",
    "openvswitch-vswitchd",
    "placement-api",
    "horizon",
]


def manifest_exists(
    base_url: str, repository: str, tag: str, auth: tuple[str, str] | None, verify: bool
) -> bool:
    response = requests.head(
        f"{base_url}/v2/{repository}/manifests/{tag}",
        headers={
            "Accept": "application/vnd.docker.distribution.manifest.v2+json,"
            "application/vnd.oci.image.index.v1+json,"
            "application/vnd.docker.distribution.manifest.list.v2+json"
        },
        auth=auth,
        verify=verify,
        timeout=30,
    )
    return response.status_code == 200


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", default=os.environ.get("KOLLA_REGISTRY", ""))
    parser.add_argument("--namespace", default=os.environ.get("KOLLA_REGISTRY_NAMESPACE", "kolla"))
    parser.add_argument("--tag", default=os.environ.get("KOLLA_IMAGE_TAG", ""))
    parser.add_argument("--images", nargs="*", default=CORE_IMAGES)
    parser.add_argument("--insecure", action="store_true")
    args = parser.parse_args(argv)

    if not args.registry or not args.tag:
        raise SystemExit("KOLLA_REGISTRY et KOLLA_IMAGE_TAG sont requis.")

    username = os.environ.get("KOLLA_REGISTRY_USERNAME", "")
    password = os.environ.get("KOLLA_REGISTRY_PASSWORD", "")
    auth = (username, password) if username else None

    scheme = "http" if args.insecure else "https"
    base_url = f"{scheme}://{args.registry}"

    missing = [
        image
        for image in args.images
        if not manifest_exists(base_url, f"{args.namespace}/{image}", args.tag, auth, not args.insecure)
    ]

    if missing:
        for image in missing:
            print(f"MANQUANT: {args.registry}/{args.namespace}/{image}:{args.tag}", file=sys.stderr)
        return 1

    print(f"{len(args.images)} images présentes dans {args.registry}/{args.namespace} (tag {args.tag}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())

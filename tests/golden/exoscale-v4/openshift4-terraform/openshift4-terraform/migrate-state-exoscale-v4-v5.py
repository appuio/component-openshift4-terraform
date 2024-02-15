#!/usr/bin/env python3

# pragma pylint: disable=line-too-long,missing-module-docstring,missing-function-docstring,invalid-name

from __future__ import annotations

import json
import subprocess
import sys

from collections import namedtuple
from typing import Optional

dry_run = False


def read_main_tf_json() -> dict:
    with open("main.tf.json", "r", encoding="utf-8") as f:
        return json.load(f)["module"]["cluster"]


def read_node_count(state: dict, module: str) -> int:
    if "exoscale_compute" in state[module]:
        return len(state[module]["exoscale_compute"]["nodes"]["instances"])
    return 0


def read_state_json(raw_state: dict) -> dict:
    state = {}
    for r in raw_state["resources"]:
        state.setdefault(r["module"], {}).setdefault(r["type"], {})[r["name"]] = r
    return state


def terraform_state_pull() -> dict:
    res = subprocess.run(
        ["terraform", "state", "pull"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    )
    res.check_returncode()
    return read_state_json(json.loads(res.stdout))


def terraform_state_rm(res: str, log: bool = False):
    if log:
        print(f"Removing {res}", file=sys.stderr)

    command = ["terraform", "state", "rm", res]
    if dry_run:
        print(command)
        return

    res = subprocess.run(
        command, capture_output=True, text=True, encoding="utf-8", check=False
    )
    res.check_returncode()
    if "Successfully removed" not in res.stdout:
        print(res.stdout, sys.stderr)
        raise ValueError(f"couldn't remove provided resource {res}")


def terraform_import(res: str, terraform_id: str):
    command = ["terraform", "import", res, terraform_id]
    if dry_run:
        print(command)
        return

    res = subprocess.run(
        command, capture_output=True, text=True, encoding="utf-8", check=False
    )
    res.check_returncode()
    if "Import prepared!" not in res.stdout:
        print(res.stdout, file=sys.stderr)
        raise ValueError(f"couldn't import provided resource {res} from {terraform_id}")


# pylint: disable=too-many-arguments
def migrate_simple_resource(
    state: dict,
    module: str,
    oldtype: str,
    newtype: str,
    name: str,
    index: int = 0,
    zone: str = "",
):
    """Migrate a single resource from `oldtype` to `newtype` by removing the old
    type from the state with `terraform state rm` and importing the resource
    with it's new type with `terraform import`. This function assumes that all
    other parts of the resource (it's module, name and index) remain the same.

    The function supports migrating resources at arbitrary indices (e.g. for
    node groups, we can call this function repeatedly to migrate each node's
    state) by providing `index`. By default the resource at index 0 is migrated.

    For resources whose state identifiers don't have an index (i.e. which are
    referred by `<module>.<type>.<name>` in the state, you can pass `index=-1`,
    which omits the `[0]` from their state identifier. In this case, we still
    read from `instances[0].attributes` to identify the resource's Exoscale ID.

    If `zone` is given, we import the resource as `<Exoscale ID>@<zone>`,
    otherwise we import it as `<Exoscale ID>`.
    """
    # Assumption structure of resource has `attributes` array with at least one entry
    resid = (
        state[module]
        .get(oldtype, {})
        .get(name, {"instances": [{"attributes": {"id": None}}] * (max(index, 0) + 1)})
    )["instances"][max(index, 0)]["attributes"]["id"]

    # Append [{index}] to resource identifier if index >= 0
    res_suffix = ""
    if index >= 0:
        res_suffix = f"[{index}]"

    old_res_loc = f"{module}.{oldtype}.{name}{res_suffix}"
    new_res_loc = f"{module}.{newtype}.{name}{res_suffix}"

    if resid:
        exo_id = f"{resid}@{zone}" if zone else resid
        print(
            f"Migrating {old_res_loc} to {new_res_loc} (Exoscale ID: {exo_id})",
            file=sys.stderr,
        )
        terraform_state_rm(old_res_loc)
        terraform_import(new_res_loc, exo_id)


RuleSpec = namedtuple("RuleSpec", ["exo_id", "proto", "source", "portspec"])


def parse_sg_rule_id(rid: str) -> RuleSpec:
    id_parts = rid.split("_")

    exo_id = id_parts[0]
    proto = id_parts[1]
    source = "_".join(id_parts[2:-1])
    portspec = id_parts[-1]

    return RuleSpec(exo_id, proto, source, portspec)


def migrate_security_group_rules_all_machines(state: dict):
    # Rule map: old description + portspec -> new description
    # Special cases: old description + portspec -> new resource name suffix
    _rules_map = {
        "VXLAN and GENEVE": {
            "4789-4789": "openshift-sdn/OVNKubernetes VXLAN",
            "6081-6081": "openshift-sdn/OVNKubernetes GENEVE",
        },
        "SSH Access": {
            "22-22": "",
        },
        "ICMP Ping": {
            "8:0": "",
        },
        "Cilium Hubble Enterprise metrics": {
            "2112-2112": "Cilium Hubble Enterprise metrics",
        },
        "Cilium Hubble Relay": {
            "4245-4245": "Cilium Hubble Relay",
        },
        "Cilium Hubble Server": {
            "4244-4244": "Cilium Hubble Server",
        },
        "Cilium VXLAN": {
            "8472-8472": "Cilium VXLAN",
        },
        "Cilium Operator Prometheus metrics": {
            "6942-6942": "Cilium Operator Prometheus metrics",
        },
        "Cilium health checks": {
            "4240-4240": "Cilium health checks",
        },
        "Host level services, including the node exporter on ports 9100-9101 and the Cluster Version Operator on port 9099": {
            "9000-9999": "Host level services, including the node exporter on ports 9100-9101 and the Cluster Version Operator on port 9099",
        },
        "Host level services, including the node exporter on ports 9100-9101": {
            "9000-9999": "Host level services, including the node exporter on ports 9100-9101",
        },
        "Ingress Router metrics": {
            "1936-1936": "Ingress Router metrics",
        },
        "Kubernetes NodePort TCP": {
            "30000-32767": "Kubernetes NodePort TCP",
        },
        "Kubernetes NodePort UDP": {
            "30000-32767": "Kubernetes NodePort UDP",
        },
        "The default ports that Kubernetes reserves": {
            "10250-10259": "The default ports that Kubernetes reserves, including the openshift-sdn port",
        },
    }
    sg_id = state["module.cluster"]["exoscale_security_group"]["all_machines"][
        "instances"
    ][0]["attributes"]["id"]
    rules = state["module.cluster"]["exoscale_security_group_rules"]["all_machines"][
        "instances"
    ][0]["attributes"]["ingress"]
    for r in rules:
        desc = r["description"]
        if desc == "openshift-sdn":
            print(
                "Dropping superfluous openshift-sdn rule for port 10256",
                file=sys.stderr,
            )
            continue
        new_rules = _rules_map[desc]
        for rid in r["ids"]:
            # Example rid:
            # 0abf6f67-4782-432e-8510-a0d7e7f2fab4_udp_c-appuio-exoscale-ch-gva-2-0_all_machines_4789-4789
            rspec = parse_sg_rule_id(rid)

            resid_base = "module.cluster.exoscale_security_group_rule"

            if rspec.proto == "icmp":
                # special case icmp rules
                resid = f"{resid_base}.all_machines_icmp"
            elif desc == "SSH Access":
                # special case ssh rules
                ipver = None
                if rspec.source == "::/0":
                    ipver = "v6"
                elif rspec.source == "0.0.0.0/0":
                    ipver = "v4"
                else:
                    print(
                        f"Unknown ssh rule source {rspec.source}, skipping",
                        file=sys.stderr,
                    )
                    continue
                resid = f"{resid_base}.all_machines_ssh_{ipver}"
            else:
                new_desc = new_rules[rspec.portspec]
                resid = f'{resid_base}.all_machines_{rspec.proto}["{new_desc}"]'

            print(
                f"Importing security group rule {resid} (Exoscale ID: {rspec.exo_id})",
                file=sys.stderr,
            )
            terraform_import(resid, f"{sg_id}/{rspec.exo_id}")


def migrate_security_group_rules_simple(state: dict, groupname: str):
    # rule map: portspec -> new resouce name
    rule_map = {
        "control_plane": {
            "6443-6443": "control_plane_kubernetes_api",
            "22623-22623": "control_plane_machine_config_server",
            "2379-2380": "control_plane_etcd",
        },
        "infra": {
            "80-80": 'infra["HTTP"]',
            "443-443": 'infra["HTTPS"]',
        },
        "storage": {
            "3300-3300": 'storage["Ceph Messenger v1"]',
            "6789-6789": 'storage["Ceph Messenger v2"]',
            "6800-7300": 'storage["Ceph daemons"]',
        },
    }[groupname]
    sg_id = state["module.cluster"]["exoscale_security_group"][groupname]["instances"][
        0
    ]["attributes"]["id"]
    rules = state["module.cluster"]["exoscale_security_group_rules"][groupname][
        "instances"
    ][0]["attributes"]["ingress"]

    for r in rules:
        for rid in r["ids"]:
            rspec = parse_sg_rule_id(rid)
            resname = rule_map[rspec.portspec]
            resid = f"module.cluster.exoscale_security_group_rule.{resname}"

            print(
                f"Importing security group rule {resid} (Exoscale ID: {rspec.exo_id})",
                file=sys.stderr,
            )
            terraform_import(resid, f"{sg_id}/{rspec.exo_id}")


def migrate_security_group_rules_lb(state: dict):
    portspec_to_desc = {
        "80-80": "Ingress controller HTTP",
        "443-443": "Ingress controller HTTPS",
        "6443-6443": "Kubernetes API",
    }
    sg_id = state["module.cluster.module.lb"]["exoscale_security_group"][
        "load_balancers"
    ]["instances"][0]["attributes"]["id"]
    rules = state["module.cluster.module.lb"]["exoscale_security_group_rules"][
        "load_balancers"
    ]["instances"][0]["attributes"]["ingress"]

    resid_base = "module.cluster.module.lb.exoscale_security_group_rule"
    for r in rules:
        for rid in r["ids"]:
            rspec = parse_sg_rule_id(rid)
            if rspec.portspec == "22623-22623":
                # special case machine config server rule
                resid = f"{resid_base}.load_balancers_machine_config_server[0]"
            else:
                desc = portspec_to_desc[rspec.portspec]
                if rspec.source == "0.0.0.0/0":
                    ipver = "4"
                elif rspec.source == "::/0":
                    ipver = "6"
                else:
                    print(
                        "Unknown source {desc.source}, skipping rule", file=sys.stderr
                    )
                    continue
                resid = f'{resid_base}.load_balancers_{rspec.proto}{ipver}["{desc}"]'

            print(
                f"Importing security group rule {resid} (Exoscale ID: {rspec.exo_id})",
                file=sys.stderr,
            )
            terraform_import(resid, f"{sg_id}/{rspec.exo_id}")


# pylint: disable=too-many-branches
def main(state_json: Optional[str]):
    default_node_groups = ["master", "infra", "storage", "worker"]

    # Read Exoscale and additional worker group names from main.tf.json
    zone = ""
    main_tf_json = read_main_tf_json()
    zone = main_tf_json["region"]
    additional_worker_groups = list(
        main_tf_json.get("additional_worker_groups", {}).keys()
    )

    if not zone:
        print("Unable to extract Exoscale zone from main.tf.json", file=sys.stderr)
        sys.exit(1)

    if state_json:
        with open(state_json, "r", encoding="utf-8") as f:
            state = read_state_json(json.load(f))
    else:
        state = terraform_state_pull()

    if "module.cluster" not in state:
        print('Module "cluster" not found in state, exiting...', file=sys.stderr)
        sys.exit(1)

    if "module.cluster.module.lb" not in state:
        print('Module "cluster.lb" not found in state, exiting...', file=sys.stderr)
        sys.exit(1)

    # Floating IPs
    for eip in ["api", "ingress"]:
        migrate_simple_resource(
            state,
            "module.cluster.module.lb",
            "exoscale_ipaddress",
            "exoscale_elastic_ip",
            eip,
            # pass index=-1 to omit [{index}] from the terraform resource identifier
            index=-1,
            zone=zone,
        )

    # SSH key
    migrate_simple_resource(
        state,
        "module.cluster",
        "exoscale_ssh_keypair",
        "exoscale_ssh_key",
        "admin",
    )

    # Security group rules
    if "exoscale_security_group_rules" in state["module.cluster"]:
        terraform_state_rm(
            "module.cluster.exoscale_security_group_rules.all_machines", log=True
        )
        migrate_security_group_rules_all_machines(state)
        for group in ["control_plane", "infra", "storage"]:
            terraform_state_rm(
                f"module.cluster.exoscale_security_group_rules.{group}", log=True
            )
            migrate_security_group_rules_simple(state, group)
    if "exoscale_security_group_rules" in state["module.cluster.module.lb"]:
        terraform_state_rm(
            "module.cluster.module.lb.exoscale_security_group_rules.load_balancers",
            log=True,
        )
        migrate_security_group_rules_lb(state)

    # Affinity groups
    migrate_simple_resource(
        state,
        "module.cluster.module.lb",
        "exoscale_affinity",
        "exoscale_anti_affinity_group",
        "lb",
        index=-1,
    )
    for group in default_node_groups:
        migrate_simple_resource(
            state,
            f"module.cluster.module.{group}",
            "exoscale_affinity",
            "exoscale_anti_affinity_group",
            "anti_affinity_group",
        )
    for group in additional_worker_groups:
        migrate_simple_resource(
            state,
            f'module.cluster.module.additional_worker["{group}"]',
            "exoscale_affinity",
            "exoscale_anti_affinity_group",
            "anti_affinity_group",
        )

    # LB network
    # migrate network
    migrate_simple_resource(
        state,
        "module.cluster.module.lb",
        "exoscale_network",
        "exoscale_private_network",
        "lbnet",
        zone=zone,
    )
    # remove no longer used `exoscale_nic` resources
    if "exoscale_nic" in state["module.cluster.module.lb"]:
        terraform_state_rm("module.cluster.module.lb.exoscale_nic.lb", log=True)
        if "additional_network" in state["module.cluster.module.lb"]["exoscale_nic"]:
            terraform_state_rm(
                "module.cluster.module.lb.exoscale_nic.additional_network",
                log=True,
            )

    # Compute
    # LBs
    for i in range(2):
        migrate_simple_resource(
            state,
            "module.cluster.module.lb",
            "exoscale_compute",
            "exoscale_compute_instance",
            "lb",
            index=i,
            zone=zone,
        )
    for group in default_node_groups:
        modname = f"module.cluster.module.{group}"
        for i in range(read_node_count(state, modname)):
            migrate_simple_resource(
                state,
                modname,
                "exoscale_compute",
                "exoscale_compute_instance",
                "nodes",
                index=i,
                zone=zone,
            )

    for group in additional_worker_groups:
        modname = f'module.cluster.module.additional_worker["{group}"]'
        for i in range(read_node_count(state, modname)):
            migrate_simple_resource(
                state,
                modname,
                "exoscale_compute",
                "exoscale_compute_instance",
                "nodes",
                index=i,
                zone=zone,
            )


if __name__ == "__main__":
    state_json_name = None
    if len(sys.argv) >= 2:
        state_json_name = sys.argv[1]
        dry_run = True
    main(state_json_name)

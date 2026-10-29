"""Native customer clone/resize with production SSH dependencies on both distributions."""


def bootstrap_probe(placement: PlacementRef, mode: str, username: str) -> None:
    host_for(placement).succeed(
        shlex.join(["fleet-ssh-bootstrap-guest", mode, placement["placement_id"], username]),
        timeout=90,
    )


def roster_outage(machine: MachineLike, blocked: bool) -> None:
    """Block guest HTTPS while preserving the private listener's local health check."""
    namespace = machine.succeed(
        "systemctl show audi-private.service -p NetworkNamespacePath --value"
    ).strip()
    assert namespace.startswith("/run/netns/lilly-")
    rules = (
        "add table inet bootstrap_outage; "
        "add chain inet bootstrap_outage input { type filter hook input priority -10; }; "
        'add rule inet bootstrap_outage input iifname "lv*" '
        "ip daddr 169.254.254.1 tcp dport 443 reject with tcp reset"
        if blocked
        else "delete table inet bootstrap_outage"
    )
    machine.succeed(shlex.join(["nsenter", "--net=" + namespace, "nft", rules]))


with subtest("customer clone boot tolerates roster outage and preserves guest data"):
    source_vm = provision_when_available(m1, "customer")
    await_running(source_vm["vm_id"])
    owner_id = users["owner_id"]
    assert isinstance(owner_id, str)
    username = canonical_guest_name(owner_id)
    bootstrap_probe(source_vm, "seed", username)
    for machine in provisioners:
        roster_outage(machine, True)
    clone = operator(
        m1,
        dict(
            action="clone",
            owner_id=users["owner_id"],
            vm_id=source_vm["vm_id"],
            key=str(uuid.uuid4()),
        ),
    )
    clone_id = clone["id"]
    destination_value = clone["destination_vm_id"]
    assert isinstance(clone_id, str) and str(uuid.UUID(clone_id)) == clone_id
    assert (
        isinstance(destination_value, str)
        and str(uuid.UUID(destination_value)) == destination_value
    )
    destination_id: str = destination_value
    try:
        eventually(
            lambda: (
                sql(
                    f"SELECT generation::text || ':' || observed_state FROM compute_virtual_machines WHERE id='{source_vm['vm_id']}'"
                )
                == "3:stopped"
            ),
            timeout=120,
        )
        # If the destination's same-pool import starts before the source relaunch,
        # readiness is deferred until that import is adopted, so allow the clone's own budget, not a fixed minute.
        host_for(source_vm).wait_until_succeeds(
            f"systemctl is-active --quiet lilly-vm-{source_vm['placement_id']}.service",
            timeout=600,
        )
        bootstrap_probe(source_vm, "blocked", username)
        assert vm_state(source_vm["vm_id"]) != "running"
    finally:
        for machine in provisioners:
            roster_outage(machine, False)
    eventually(
        lambda: (
            sql(f"SELECT phase FROM compute_clone_requests WHERE id='{clone_id}'") == "complete"
        ),
        timeout=600,
    )
    await_running(source_vm["vm_id"])
    await_running(destination_id)
    destination = current_copy(destination_id)
    bootstrap_probe(source_vm, "check", username)
    bootstrap_probe(destination, "check", username)
    assert (
        sql(
            f"SELECT (source_restored_at IS NOT NULL AND NOT active AND finished_at IS NOT NULL)::text "
            f"FROM compute_clone_requests WHERE id='{clone_id}'"
        )
        == "true"
    )

with subtest("customer resize restart reaches SSH readiness with retained ownership"):
    resize = operator(
        m1,
        dict(
            action="resize", owner_id=users["owner_id"], vm_id=destination_id, key=str(uuid.uuid4())
        ),
    )
    resize_id = resize["id"]
    assert isinstance(resize_id, str) and str(uuid.UUID(resize_id)) == resize_id
    eventually(
        lambda: (
            sql(f"SELECT phase FROM compute_resize_requests WHERE id='{resize_id}'") == "complete"
        ),
        timeout=300,
    )
    await_running(destination_id)
    bootstrap_probe(destination, "check", username)
    lifecycle(destination_id, "delete")
    eventually(lambda: vm_state(destination_id) == "deleted")

with subtest("readiness timeout retains evidence and authorized retry preserves both disks"):
    for machine in provisioners:
        roster_outage(machine, True)
    failed_clone = operator(
        m1,
        dict(
            action="clone",
            owner_id=users["owner_id"],
            vm_id=source_vm["vm_id"],
            key=str(uuid.uuid4()),
        ),
    )
    failed_id = failed_clone["id"]
    retained_value = failed_clone["destination_vm_id"]
    assert isinstance(failed_id, str) and str(uuid.UUID(failed_id)) == failed_id
    assert isinstance(retained_value, str) and str(uuid.UUID(retained_value)) == retained_value
    retained_id: str = retained_value
    try:
        eventually(
            lambda: (
                sql(f"SELECT failure FROM compute_clone_requests WHERE id='{failed_id}'")
                == "source_restart_failed"
                and vm_state(source_vm["vm_id"]) == "failed"
                and vm_state(retained_id) == "failed"
            ),
            timeout=360,
        )
        retained = current_copy(retained_id)
        for placement in [source_vm, retained]:
            machine = host_for(placement)
            boot_log = "/var/lib/lilly/vms/" + placement["placement_id"] + "/boot.log"
            machine.succeed("test -s " + shlex.quote(boot_log))
            machine.succeed(
                "journalctl -u lilly.service --no-pager -o cat | "
                "grep -F 'vm.readiness_failed' | grep -F "
                + shlex.quote(placement["placement_id"])
                + " >/dev/null"
            )
            machine.fail(
                "systemctl is-active --quiet lilly-vm-" + placement["placement_id"] + ".service"
            )
    finally:
        for machine in provisioners:
            roster_outage(machine, False)
    retry_clone = operator(
        m1, dict(action="retry-clone", owner_id=users["owner_id"], request_id=failed_id)
    )
    assert retry_clone["id"] == failed_id
    lifecycle(retained_id, "start")
    eventually(
        lambda: (
            sql(f"SELECT phase FROM compute_clone_requests WHERE id='{failed_id}'") == "complete"
        ),
        timeout=600,
    )
    await_running(source_vm["vm_id"])
    await_running(retained_id)
    assert current_copy(source_vm["vm_id"])["placement_id"] == source_vm["placement_id"]
    assert current_copy(retained_id) == retained
    bootstrap_probe(source_vm, "check", username)
    bootstrap_probe(retained, "check", username)
    for vm_id in [source_vm["vm_id"], retained_id]:
        lifecycle(vm_id, "delete")

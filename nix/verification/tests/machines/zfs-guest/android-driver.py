"""Boot, resize and restart the production Android image through Lilly."""

import json

storage.start()
storage.wait_for_unit("multi-user.target")
storage.succeed("test -c /dev/kvm", "systemctl is-active lilly-hostd.service")
storage.succeed(
    "zpool create -f -O compression=lz4 -O mountpoint=/tank tank mirror /dev/vdb /dev/vdc"
)
vm = "dddddddd-dddd-4ddd-8ddd-000000000201"

with subtest("the production Android image create/resize/start/stop lifecycle"):
    exit_code, diagnostic = storage.execute("zfs-guest android-start 1", timeout=1800)
    if exit_code != 0:
        raise AssertionError("Android guest did not report readiness: " + diagnostic[-2000:])
    result = json.loads(diagnostic.splitlines()[-1])
    assert result["image_id"]
    storage.succeed("zfs-guest android-stop 2", timeout=600)
    storage.succeed("zfs-guest android-resize 3", timeout=900)
    storage.succeed("zfs-guest android-start 4", timeout=1800)
    storage.succeed("zfs-guest observe 5", timeout=300)
    storage.succeed("zfs-guest android-stop 6", timeout=600)
    storage.succeed("zfs-guest android-delete 7", timeout=600)

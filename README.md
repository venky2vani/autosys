# autosys
System Automation utilities

## Scripts

### `scripts/remove-waydroid.sh`

Removes the Waydroid setup that was used to run gCOB, plus everything it left
on the system: the `waydroid-container` service, the Waydroid package and its
apt/dnf repo, `/var/lib/waydroid` and container images, per-user Waydroid data,
Android app launchers, gCOB shortcuts that launch through Waydroid, and the
`waydroid0` network bridge.

```sh
sudo ./scripts/remove-waydroid.sh          # dry run: list what would be removed
sudo ./scripts/remove-waydroid.sh --apply  # remove it
```

binder/ashmem kernel module configs are reported but not deleted, since other
Android tooling may use them.

# DMS Niri brightness bindings

## Confirmed adjustment

On DMS 1.5.3 with Niri, brightness IPC methods require both positional arguments: the percentage step and a device identifier. To use the preferred backlight device, pass an empty string as that second argument.

```kdl
XF86MonBrightnessUp allow-when-locked=true {
    spawn "dms" "ipc" "call" "brightness" "increment" "5" "";
}
XF86MonBrightnessDown allow-when-locked=true {
    spawn "dms" "ipc" "call" "brightness" "decrement" "5" "";
}
```

Without the final `""`, DMS rejects the call with `Too few arguments provided (2 required but 1 were provided.)`. Volume bindings are unaffected because their IPC methods take only the step argument.

## Validate and apply

1. Check the generated Niri include at `$HOME/.config/niri/dms/binds.kdl`.
2. Reload the active Niri configuration:

   ```bash
   niri msg action load-config-file
   ```

3. Confirm the DMS API can control the preferred display before testing the physical keys:

   ```bash
   dms brightness list
   dms ipc call brightness increment 5 ""
   dms ipc call brightness decrement 5 ""
   ```

DMS should continue to be launched from Niri with `dms run --session`; do not enable a second `dms.service` instance for the same session.

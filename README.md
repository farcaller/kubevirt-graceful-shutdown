# kubevirt-graceful-shutdown

kubevirt-graceful-shutdown prodides a nixos service to gracefully shutdown kubevirt VMs when the machine is shutting down.

## Usage with nix flakes

```nix
{
  inputs = {
    # add the flake to your system inputs:
    kubevirt-graceful-shutdown.url = "github:farcaller/kubevirt-graceful-shutdown";
  };
  
  outputs = { kubevirt-graceful-shutdown, ... }: {
    nixosConfigurations."<hostname>" = {
      modules = [
        # add the module to your system's modules:
        kubevirt-graceful-shutdown.nixosModule
      ];
    };
  };
}
```

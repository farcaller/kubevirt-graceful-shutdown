{
  description = "Kubevirt graceful shutdown service.";

  outputs = { self, mach-nix, ... }:
    {
      packages.x86_64-linux.shutdownService = mach-nix.lib.x86_64-linux.buildPythonPackage ./.;
      packages.x86_64-linux.default = self.packages.x86_64-linux.shutdownService;

      devShells.x86_64-linux.default = mach-nix.lib.x86_64-linux.mkPythonShell {
        requirements = "autopep8";
        packagesExtra = [
          self.packages.x86_64-linux.shutdownService
        ];
      };

      nixosModule = { config, ... }: {
        systemd.services.kubevirt-graceful-shutdown = {
          wants = [ "k3s.service" ];
          after = [ "k3s.service" ];
          before = [ "halt.target" "shutdown.target" "reboot.target" ];
          wantedBy = [ "default.target" ];
          script = "sleep 60 && ${self.packages.x86_64-linux.default}/bin/kubevirt-graceful-shutdown start";
          preStop = "${self.packages.x86_64-linux.default}/bin/kubevirt-graceful-shutdown stop";
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = "yes";
          };
          environment = {
            KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
          };
        };
      };
    };
}

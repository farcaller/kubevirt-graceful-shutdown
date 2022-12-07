{
  description = "Kubevirt graceful shutdown service.";

  outputs = { self, nixpkgs, mach-nix, ... }:
    {
      packages.x86_64-linux.shutdownService = mach-nix.lib.x86_64-linux.buildPythonPackage ./.;
      packages.x86_64-linux.kube-drain-node =
        let
          pkgs = import nixpkgs { system = "x86_64-linux"; };
        in
        pkgs.writeShellScriptBin "kube-drain-node" ''
          HOSTNAME=$(${pkgs.nettools}/bin/hostname)
          if [ "$1" = "drain" ]; then
            exec ${pkgs.k3s}/bin/k3s kubectl drain --force --grace-period=30 --timeout=40s $HOSTNAME
          elif [ "$1" = "undrain" ]; then
            exec ${pkgs.k3s}/bin/k3s kubectl uncordon $HOSTNAME
          fi
          exit 2
        '';

      packages.x86_64-linux.default = self.packages.x86_64-linux.shutdownService;

      devShells.x86_64-linux.default = mach-nix.lib.x86_64-linux.mkPythonShell {
        requirements = "autopep8";
        packagesExtra = [
          self.packages.x86_64-linux.shutdownService
        ];
      };

      nixosModules = {
        drain = { config, ... }: {
          systemd.services.kube-drain-node = {
            wants = [ "k3s.service" ];
            after = [ "k3s.service" ];
            before = [ "halt.target" "shutdown.target" "reboot.target" ];
            wantedBy = [ "default.target" ];
            script = "${self.packages.x86_64-linux.kube-drain-node}/bin/kube-drain-node undrain";
            preStop = "${self.packages.x86_64-linux.kube-drain-node}/bin/kube-drain-node drain";
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = "yes";
            };
          };
        };
        kubevirt = { config, ... }: {
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
    };
}

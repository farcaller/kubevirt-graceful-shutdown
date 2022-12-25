{
  description = "Kubevirt graceful shutdown service.";

  outputs = { self, nixpkgs, flake-utils, mach-nix, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        machlib = mach-nix.lib.${system};
      in
      rec {
        packages = flake-utils.lib.flattenTree {
          shutdownService = machlib.buildPythonPackage ./.;
          kube-drain-node = pkgs.writeShellScriptBin "kube-drain-node" ''
            HOSTNAME=$(${pkgs.nettools}/bin/hostname)
            if [ "$1" = "drain" ]; then
              exec ${pkgs.k3s}/bin/k3s kubectl drain --force --grace-period=30 --timeout=40s $HOSTNAME
            elif [ "$1" = "undrain" ]; then
              for i in 1 2 3 4 5; do 
                ${pkgs.k3s}/bin/k3s kubectl get node $HOSTNAME && break || sleep 15
              done

              ${pkgs.k3s}/bin/k3s kubectl get node $HOSTNAME -o jsonpath="{.spec.taints[0]}" | grep NoSchedule
              if [ $? -eq 0 ]; then
                ${pkgs.k3s}/bin/k3s kubectl uncordon $HOSTNAME
                exit $?
              else
                echo "the node is already undrained"
                exit 0
              fi
            fi
            exit 2
          '';
        };
        
        apps.shutdownService = flake-utils.lib.mkApp { drv = packages.shutdownService; };
        apps.kube-drain-node = flake-utils.lib.mkApp { drv = packages.kube-drain-node; };

        devShells.default = machlib.mkPythonShell {
          requirements = "autopep8";
          packagesExtra = [ packages.shutdownService ];
        };

        nixosModules = {
          drain = { config, ... }: {
            systemd.services.kube-drain-node = {
              wants = [ "k3s.service" ];
              after = [ "k3s.service" "kubepods.slice" "machines.target" ];
              before = [ "halt.target" "shutdown.target" "reboot.target" ];
              wantedBy = [ "default.target" ];
              script = "${packages.kube-drain-node}/bin/kube-drain-node undrain";
              preStop = "${packages.kube-drain-node}/bin/kube-drain-node drain";
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = "yes";
                TimeoutStopSec = 90;
              };
            };
          };
          kubevirt = { config, ... }: {
            systemd.services.kubevirt-graceful-shutdown = {
              wants = [ "k3s.service" ];
              after = [ "k3s.service" ];
              before = [ "halt.target" "shutdown.target" "reboot.target" ];
              wantedBy = [ "default.target" ];
              script = "sleep 60 && ${packages.shutdownService}/bin/kubevirt-graceful-shutdown start";
              preStop = "${packages.shutdownService}/bin/kubevirt-graceful-shutdown stop";
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
      });
}

{
  description =
    "Flake for omnictl - CLI for the Sidero Omni Kubernetes management platform";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems =
        [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      perSystem = { config, self', pkgs, lib, system, ... }:
        let
          omnictl = pkgs.buildGoModule rec {
            pname = "omnictl";
            version = "0.44.0";

            src = pkgs.fetchFromGitHub {
              owner = "siderolabs";
              repo = "omni";
              rev = "v${version}";
              hash = "sha256-vD/Z54CxMGuIKjiyYTx2shXyu0QzJkNIL0U6UEceT5Y=";
            };

            vendorHash = "sha256-7cx+ys9CqL8Yjy1Jd1iXSfmlfG9yCNckhOId5EFqtQc=";
            preBuild = ''
              mkdir -p internal/version/data
              echo -n "v${version}" > internal/version/data/tag
              echo -n "${src.rev}" > internal/version/data/sha  # This should give us the Git SHA
            '';
            ldflags = [
              "-s"
              "-w"
              "-X internal/version.Name=omnictl"
              "-X internal/version.Tag=v${version}"
            ];
            env = { GOWORK = "off"; };
            subPackages = [ "cmd/omnictl" ];
            nativeBuildInputs = with pkgs; [ installShellFiles git ];
            postInstall = ''
              installShellCompletion --cmd omnictl \
                --bash <($out/bin/omnictl completion bash) \
                --fish <($out/bin/omnictl completion fish) \
                --zsh <($out/bin/omnictl completion zsh)
            '';
            doCheck = false; # no tests
            meta = {
              description =
                "CLI for the Sidero Omni Kubernetes management platform";
              mainProgram = "omnictl";
              homepage = "https://omni.siderolabs.com/";
            };
          };
        in {
          packages.default = omnictl;
          devShells.default = pkgs.mkShell {
            shellHook = ''
              export KREW_ROOT="$HOME/.local/share/krew"
              export PATH="$''${KREW_ROOT}/bin:$PATH"
              krew install oidc-login  >/dev/null 2>&1 # required by omnictl for using kubectl
              krew install cnpg >/dev/null 2>&1 # provides kubectl cnpg for managing postgres clusters

              kubectl() {
                kubecolor "$@"
              }
            '';
            buildInputs = [ omnictl ] # SaaS for Talos management
              ++ (with pkgs; [
                kubectl
                kustomize
                krew # package manager for kubectl
                kubectx # fast namespace and context switching
                kubecolor # colorized kubectl output
                kubernetes-helm # k8s package manager
                talosctl # Talos (k8s OS)

                xdg-utils # required by oidc-login and omnictl
                gnupg # required by oidc-login and omnictl
              ]);
          };
        };
    };
}

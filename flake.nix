{
  description = "eBPF Exporter";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs";

  outputs = {
    self,
    nixpkgs,
  }: let
    supportedSystems = ["x86_64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    nixpkgsFor = forAllSystems (system: import nixpkgs {inherit system;});

    packages = forAllSystems (system: let
      pkgs = nixpkgsFor.${system};
    in {
      ebpfExporter = pkgs.buildGoModule {
        name = "ebpf-exporter";
        version = 0.1;
        src = self;
        nativeBuildInputs = with pkgs; [
          llvmPackages.clang
          pkg-config
        ];

        buildInputs = with pkgs; [go zlib elfutils libbpf libclang];

        hardeningDisable = ["stackprotector"];

        buildPhase = ''
          make build-dynamic
          make -C examples build
        '';

        installPhase = ''
          mkdir -p $out/exporters
          mkdir -p $out/bin
          cp ebpf_exporter $out/bin

          # copy the compiled bpf objects
          cp examples/*.o $out/exporters
          # copy the yaml files
          cp examples/*.yaml $out/exporters

        '';
        vendorSha256 = "sha256-JD31z6uhHRhoYGZpTYYH2Au4tYaQdOHy1Hy00Rm/I5w=";

        doCheck = false;
      };
    });
  in {
    packages = forAllSystems (system: let
      pkgs = nixpkgsFor.${system};
    in {
      dockerImage = pkgs.dockerTools.buildLayeredImage {
        name = "ebpf-exporter";
        tag = self.rev;
        config = {Cmd = ["${packages.${system}.ebpfExporter}/bin/ebpf_exporter --config.dir exporters --config.names nfs_client --debug"];};
      };

      default = packages.${system}.ebpfExporter;
    });

    formatter =
      forAllSystems (system:
        nixpkgsFor.${system}.alejandra);

    devShells = forAllSystems (system: let
      pkgs = nixpkgsFor.${system};
    in {
      default = pkgs.mkShell {
        nativeBuildInputs = packages.${system}.ebpfExporter.nativeBuildInputs;
        buildInputs = packages.${system}.ebpfExporter.buildInputs;
        shellHook = ''
          ${pkgs.cowsay}/bin/cowsay development shell
        '';
      };
    });
  };
}

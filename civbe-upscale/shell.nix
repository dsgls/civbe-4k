# Dev shell for civbe-upscale.
#
# torch comes from torch-bin (upstream wheels): the source build is hours long
# and the wheels already carry CUDA. spandrel and everything else that depends
# on torch is rebuilt against it via packageOverrides, otherwise two torches end
# up on sys.path.
#
# cudaPackages is pinned to 13: the default set (12.9) is older than the
# cuda-bindings the torch wheels declare, and torch-bin refuses to evaluate
# against it.
#
# libnvshmem is the one dependency here with no binary cache entry, so it builds
# from source. Stock it compiles device code for nine GPU architectures with its
# test and example suites — enough to exhaust this machine. Both cuts below are
# safe for this tool: inference is single-GPU (nvshmem is a multi-GPU/multi-node
# transport that never runs), and torch-bin needs the library only so
# autoPatchelf can resolve libtorch_cuda.so's link against it.
{ pkgs ? import <nixpkgs> {
    config.allowUnfree = true;
    # Blackwell (RTX 5090) only. Every extra capability is another full pass of
    # device-code compilation through every CUDA package built from source.
    config.cudaCapabilities = [ "12.0" ];
    overlays = [
      (final: prev: {
        cudaPackages = final.cudaPackages_13.overrideScope (cudaFinal: cudaPrev: {
          # nixpkgs pins this backport to cccl's squash-merge commit, which
          # NVIDIA has since rewritten away — the URL 404s. The PR refs still
          # serve the same diff (only hunk context differs, hence a new hash).
          cccl = cudaPrev.cccl.overrideAttrs (old: {
            patches = map (p:
              if (p.name or "") == "fix-invalid-cpp-syntax" then
                final.fetchpatch {
                  name = "fix-invalid-cpp-syntax";
                  url = "https://github.com/NVIDIA/cccl/pull/8771.patch";
                  stripLen = 2;
                  extraPrefix = "include/";
                  hash = "sha256-SSUtfO9cKMkefVD/e2yLvRV0IeRNeNBKuT6DKX9rhpE=";
                }
              else p) (old.patches or [ ]);
          });
          libnvshmem = cudaPrev.libnvshmem.overrideAttrs (old: {
            cmakeFlags =
              (builtins.filter
                (flag: !(final.lib.hasPrefix "-DNVSHMEM_BUILD_TESTS" flag
                      || final.lib.hasPrefix "-DNVSHMEM_BUILD_EXAMPLES" flag))
                old.cmakeFlags)
              ++ [
                "-DNVSHMEM_BUILD_TESTS:BOOL=FALSE"
                "-DNVSHMEM_BUILD_EXAMPLES:BOOL=FALSE"
              ];
          });
        });
      })
    ];
  }
}:

let
  python = pkgs.python3.override {
    self = python;
    packageOverrides = self: super: {
      # The wheel caps setuptools below 82 while nixpkgs ships 83, which fails
      # the runtime-deps check. torch only reaches for setuptools through
      # pkg_resources, so the cap is advisory. Patch torch-bin itself rather
      # than the torch alias: torchvision-bin depends on torch-bin by name, and
      # would otherwise pull an unpatched second torch onto sys.path.
      torch-bin = super.torch-bin.overrideAttrs (old: {
        pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [ "setuptools" ];
      });
      torch = self.torch-bin;
      torchvision = self.torchvision-bin;
    };
  };
in
pkgs.mkShell {
  packages = [
    (python.withPackages (ps: with ps; [
      torch
      torchvision
      numpy
      pillow
      scipy
      spandrel
      pytest
    ]))
  ];

  # libcuda lives in the WSL driver mount, not in the nix store. Without this
  # torch.cuda.is_available() is False on an otherwise working GPU.
  shellHook = ''
    export LD_LIBRARY_PATH=/usr/lib/wsl/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
  '';
}

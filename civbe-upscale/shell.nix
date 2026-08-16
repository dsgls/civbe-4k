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
{ pkgs ? import <nixpkgs> {
    config.allowUnfree = true;
    overlays = [ (final: prev: { cudaPackages = final.cudaPackages_13; }) ];
  }
}:

let
  python = pkgs.python3.override {
    self = python;
    packageOverrides = self: super: {
      torch = super.torch-bin;
      torchvision = super.torchvision-bin;
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

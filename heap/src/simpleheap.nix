{ pkgs ? import <nixpkgs> {} }:

let
  # source:
  # https://lazamar.co.uk/nix-versions/?channel=nixpkgs-unstable&package=glibc
  glibcVersions = {
    "2.23" = "cb5a2acaa118b61765fb59d176555535da582a62";  # 2016-08-17
    "2.24" = "c0c50dfcb70d48e5b79c4ae9f1aa9d339af860b4";  # 2017-02-13
    "2.26" = "0b307aa73804bbd7a7172899e59ae0b8c347a62d";  # 2018-04-09 (2.26-131)
    "2.27" = "a9eb3eed170fa916e0a8364e5227ee661af76fde";  # 2019-12-30
    "2.30" = "136a26be29a9daa04e5f15ee7694e9e92e5a028c";  # 2020-06-27
    "2.35" = "1dfd0f069d2d348d732f81c813d842e15aa20da5";  # 2023-03-15 (2.35-224)
  };

  # source:
  # https://lazamar.co.uk/nix-versions/?channel=nixpkgs-unstable&package=jemalloc
  jemallocVersions = {
    "5.3.0" = "e6f23dc08d3624daab7094b701aa3954923c6bbb";  # 2025-06-16
  };

  mkSimpleheapGlibc = glibcVer: commitHash:
    let
      targetPkgs = import (builtins.fetchTarball {
        url = "https://github.com/NixOS/nixpkgs/archive/${commitHash}.tar.gz";
      }) {};
    in
    targetPkgs.stdenv.mkDerivation {
      name = "simpleheap-glibc-${glibcVer}";
      src = ./.;
      
      nativeBuildInputs = with targetPkgs; [ gcc ];
      buildInputs = with targetPkgs; [ stdenv.cc.cc.lib ];
      
      buildPhase = ''
        gcc -o simpleheap-glibc-${glibcVer} simpleheap.c
      '';
      
      installPhase = ''
        mkdir -p $out/bin
        cp simpleheap-glibc-${glibcVer} $out/bin/
        chmod +x $out/bin/simpleheap-glibc-${glibcVer}
      '';
    };

  mkSimpleheapJemalloc = jemallocVer: commitHash:
    let
      targetPkgs = import (builtins.fetchTarball {
        url = "https://github.com/NixOS/nixpkgs/archive/${commitHash}.tar.gz";
      }) {};
      # Use jemalloc with debug symbols and stats, prevent stripping
      jemallocDebug = targetPkgs.jemalloc.overrideAttrs (oldAttrs: {
        configureFlags = (oldAttrs.configureFlags or []) ++ [
          "--enable-debug"
          "--enable-prof"
          "--enable-stats"
        ];
        dontStrip = true;
        separateDebugInfo = false;
      });
    in
    targetPkgs.stdenv.mkDerivation {
      name = "simpleheap-jemalloc-${jemallocVer}";
      src = ./.;

      nativeBuildInputs = with targetPkgs; [ gcc ];
      buildInputs = [ jemallocDebug ];

      dontStrip = true;

      buildPhase = ''
        gcc -g -O0 -o simpleheap-jemalloc-${jemallocVer} simpleheap.c \
          -DUSE_JEMALLOC \
          -I${jemallocDebug}/include \
          ${jemallocDebug}/lib/libjemalloc.a \
          -lpthread -ldl -lm
      '';

      installPhase = ''
        mkdir -p $out/bin
        cp simpleheap-jemalloc-${jemallocVer} $out/bin/
        chmod +x $out/bin/simpleheap-jemalloc-${jemallocVer}
      '';
    };

  glibcBuilds = pkgs.lib.mapAttrs mkSimpleheapGlibc glibcVersions;
  jemallocBuilds = pkgs.lib.mapAttrs mkSimpleheapJemalloc jemallocVersions;

in
pkgs.symlinkJoin {
  name = "simpleheap-all-versions";
  paths = pkgs.lib.attrValues glibcBuilds ++ pkgs.lib.attrValues jemallocBuilds;
}
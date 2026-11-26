{ pkgs, lib, config, ... }:

let
  # Elm toolchain for the Graphos Studio SPA (elm.json requires elm 0.19.2).
  # `nixpkgs` is pinned in devenv.yaml to the revision that ships 0.19.2.
  elm = pkgs.elmPackages;
in
{
  # Elm toolchain — the same four packages the studio's CI uses.
  packages = [
    elm.elm
    elm.elm-test
    elm.elm-format
    elm.elm-review
    # `.scripts/fixture-drift-check.sh` (graph.json vs Fixtures.fixtureJson).
    pkgs.python3
    # `openspec-view/` is a base-only Haskell package (the `graphos view`
    # backend). GHC + cabal let it be built and tested from this repo alone.
    # The dev stack builds the pinned mnemo binary with the same GHC.
    pkgs.ghc
    pkgs.cabal-install
    # The dev stack fetches verified release artifacts and clones the pinned
    # mnemo source. `pkg-config` lets cabal find system libraries.
    pkgs.curl
    pkgs.jq
    pkgs.git
    pkgs.gh
    pkgs.pkg-config
  ];

  # Fail fast if the pin ever drifts off Elm 0.19.2: elm.json rejects anything
  # else, and a silent 0.19.1 downgrade is what broke studio CI before.
  enterShell = ''
    elm_version="$(${elm.elm}/bin/elm --version)"
    if [ "$elm_version" != "0.19.2" ]; then
      echo "devenv: expected Elm 0.19.2 (studio/elm.json), got $elm_version" >&2
      echo "devenv: check the nixpkgs pin in devenv.yaml" >&2
    fi
    echo "Graphos Studio — elm $elm_version · elm-test $(${elm.elm-test}/bin/elm-test --version)"

    # Dev-stack configuration paths: an exported value wins, otherwise the
    # file lives under the user's home. scripts/dev-stack/lib.sh resolves the
    # same defaults so the processes also work without this interactive shell.
    export GRAPHOS_CONFIG="''${GRAPHOS_CONFIG:-$HOME/.config/graphos/graphos.yaml}"
    export MNEMO_CONFIG="''${MNEMO_CONFIG:-$HOME/.config/mnemo/graphos-studio.yaml}"
    echo "  config   GRAPHOS_CONFIG=$GRAPHOS_CONFIG"
    echo "  config   MNEMO_CONFIG=$MNEMO_CONFIG"
  '';

  # `devenv up` supervises the three services in the foreground and prefixes
  # their logs; Ctrl-C stops it. `devenv processes start` / `devenv processes
  # down` is the background pair. Each wrapper verifies its pinned artifact
  # before the service starts, so a stale or corrupted cache fails closed. A
  # failed service stays failed (no restart loop) so its log stays readable.
  processes = {
    studio = {
      exec = "scripts/dev-stack/studio.sh";
      process-compose.restart = "no";
    };
    graphos = {
      exec = "scripts/dev-stack/graphos.sh";
      process-compose.restart = "no";
    };
    mnemo = {
      exec = "scripts/dev-stack/mnemo.sh";
      process-compose.restart = "no";
    };
  };

  tasks = {
    "studio:build" = {
      exec = "elm make src/Main.elm --optimize --output=public/studio.js";
      execIfModified = [
        "src/**/*.elm"
        "elm.json"
      ];
    };

    # The Mnemo page is a second entry (`mnemo-workbench`), served by the
    # console's `--frontend-dir public/mnemo`; it does not load the graph
    # workbench's bundle.
    "mnemo:build" = {
      exec = "elm make src/Mnemo/Main.elm --optimize --output=public/mnemo/mnemo.js";
      execIfModified = [
        "src/Mnemo/**/*.elm"
        "src/Studio/DesignSystem/**/*.elm"
        "elm.json"
      ];
    };

    "studio:test" = {
      exec = "elm-test";
      execIfModified = [
        "src/**/*.elm"
        "tests/**/*.elm"
        "elm.json"
      ];
    };

    # The copied sources are not elm-format-clean yet, so this task rewrites
    # them on demand instead of validating; CI does not gate on formatting.
    "studio:format" = {
      exec = "elm-format --yes src tests";
      execIfModified = [
        "src/**/*.elm"
        "tests/**/*.elm"
      ];
    };

    "studio:review" = {
      exec = "elm-review";
      execIfModified = [
        "src/**/*.elm"
        "tests/**/*.elm"
        "review/**/*.elm"
        "review/elm.json"
      ];
    };

    "studio:fixture-drift" = {
      exec = ".scripts/fixture-drift-check.sh";
      execIfModified = [
        "tests/fixtures/graph.json"
        "tests/Fixtures.elm"
      ];
    };

    # The openspec-view Haskell package: `graphos view`'s rendering backend.
    # Its disk-scanning specs mark themselves pending when no openspec/changes
    # tree is above the working directory, so it tests green standalone.
    "openspec-view:test" = {
      exec = "cd openspec-view && cabal test";
      execIfModified = [
        "openspec-view/**/*.hs"
        "openspec-view/openspec-view.cabal"
      ];
    };

    # What CI runs, in the same order as .github/workflows/studio.yml.
    "studio:ci" = {
      exec = ''
        set -e
        elm make src/Main.elm --optimize --output=public/studio.js
        elm-test
        elm-review
        .scripts/fixture-drift-check.sh
        violations=$(grep -rnE '#[0-9a-fA-F]{6}' src/ --include='*.elm' | grep -v 'DesignSystem/Tokens.elm' || true)
        if [ -n "$violations" ]; then
          echo "Color literals outside Studio.DesignSystem.Tokens:" >&2
          echo "$violations" >&2
          exit 1
        fi
      '';
      after = [
        "studio:build@succeeded"
        "studio:test@succeeded"
        "studio:review@succeeded"
      ];
    };

    # Fetch and verify both pinned artifacts ahead of time, for a first run or
    # an offline check. The task is idempotent: verified cache entries are
    # reported and reused, never downloaded or rebuilt again.
    "dev-stack:fetch" = {
      exec = ''
        set -e
        scripts/dev-stack/fetch-graphos.sh
        scripts/dev-stack/fetch-mnemo.sh
      '';
    };

    # Preflight: pins, cached artifacts and sidecars, configuration paths, the
    # selected graph and the three ports. Every failure names its remediation.
    "dev-stack:check" = {
      exec = "scripts/dev-stack/check.sh";
    };
  };
}

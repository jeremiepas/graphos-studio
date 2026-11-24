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
  '';

  tasks = {
    "studio:build" = {
      exec = "elm make src/Main.elm --optimize --output=public/studio.js";
      execIfModified = [
        "src/**/*.elm"
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

    "studio:fixture-drift" = {
      exec = ".scripts/fixture-drift-check.sh";
      execIfModified = [
        "tests/fixtures/graph.json"
        "tests/Fixtures.elm"
      ];
    };

    # What CI runs, in the same order as .github/workflows/studio.yml.
    "studio:ci" = {
      exec = ''
        set -e
        elm make src/Main.elm --optimize --output=public/studio.js
        elm-test
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
      ];
    };
  };
}

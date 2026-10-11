# STAMPED evidence map

This is an implementation-oriented self-assessment, not a human-reviewed certification.
It uses STAMPED principles version 0.2.0 from the [principles schema repository](https://github.com/stamped-principles/stamped-principles-schema/tree/2c7c3a7442b2f63649ff70a1893db7557ac19461).
The reference JSON and immutable lock are included in `references/`.

| Principle | Application and evidence |
| --- | --- |
| Self-contained (S.1) | One repository contains the upstream source archive, patch, fixtures, environment definition, executable procedure, and selected results. External image and package components are reachable through pinned public references. |
| Tracked (T.1–T.5) | Git tracks the research object. SHA-256 manifests identify source, patch, and procedures. Results record actual installed packages, binary hashes, image identity, and commands encoded by the runner. Git history records authored changes and agent provenance. |
| Actionable (A.1–A.2) | `python3 scripts/run-experiment.py` compiles and compares both variants. Defined expected outcomes distinguish target reproduction, successful correction, and unrelated setup failures. |
| Modular (M.1–M.2, M.4) | Source, patch, tests, documentation, references, and results are separate components. Private host execution logs remain outside the repository; selected public evidence contains no credential or host-environment dump. |
| Portable (P.1–P.3) | A digest-pinned Debian base and timestamped package snapshot specify the build environment. Both binaries share compiler, dependencies, and flags. Python's standard library orchestrates an explicitly selected Linux amd64 container platform. |
| Ephemeral (E.1) | Fixtures use temporary directories, test containers use `--rm`, and the compilation occurs inside container build stages. Durable evidence is recorded separately from disposable execution state. |
| Distributable (D.1–D.2) | Source and procedures are available in the public repository. Upstream licenses and STAMPED attribution are preserved. Image digest and package snapshot support reconstruction without a moving package solve. |

## Limits

The experiment verifies behavioral reproduction, not byte-identical rebuilds.
Compiler timestamps, paths, and binary layout can affect binary hashes.
Only the recorded platform and selected regression/property tests are claimed.
Building requires external registry and Debian snapshot availability and sufficient disk.
The exploratory standalone image uses a moving download and is retained only as historical procedure; it is not the pinned comparison environment.

No raw host execution logs, private conversation, or unreviewed upstream comments are published.
Workshop evidence remains separately classified.
This research object contains a proposed patch and executable evidence, not an upstream release.

The source build disables optional assistant, D-Bus, libmagic, Botan, BLAKE3, XXH3, OsPath, and TAP support.
The snapshot supplies file-io 0.1.5, below the source's OsPath requirement of 0.2.0, and lacks tasty-tap.
Both variants use the same fallback filename API and build flags.
The non-OsPath path therefore is the compiled regression scope; the earlier standalone reproduction used upstream's own build configuration.

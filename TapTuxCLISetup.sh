#!/usr/bin/env bash
# TapTuxCLISetup.sh
# ===================
# One-time, run-it-yourself bootstrap for TapTux's shared runtime. This is
# deliberately plain bash, not Python - TapTux.py itself is a .py file, so
# something has to be able to run it before any TapTux-owned Python exists.
# A shell script is the only thing that can do that first step without
# already depending on Python (or anything else TapTux would otherwise
# need to fetch), and Termux's base install already includes bash + tar
# + basic coreutils. curl is the one thing this script needs that ISN'T
# in Termux's base bootstrap (that install only has busybox's own wget,
# whose HTTPS support depends on spawning an external SSL helper and
# whose custom-header handling has had real bugs in some busybox builds -
# not something to build an authenticated GitHub download on). `pkg
# install curl` is one lightweight package, a very different ask than
# the full python runtime this replaces.
#
# What this does, and ONLY this:
#   1. Fetches TapTuxEnviroments.json and takes the first container's
#      "requirements" map as the shared runtime's bootstrap set.
#   2. Downloads and merges those into TapTuxInstallRoot/Python - see
#      classify_and_merge() below for how each one is placed. This is
#      the SAME classification logic TapTuxRuntimeProvisioning.py uses
#      for a per-ENVIRONMENT install (see that module) - kept as two
#      separate implementations (bash here, Python there) since this
#      script cannot depend on Python existing yet, but deliberately
#      matching conventions so they don't drift apart.
#   3. Writes the `taptux` command with a shebang straight into the
#      downloaded interpreter, pointed at TapTux.py next to this script.
#   4. Cleans up every downloaded archive and temp file.
#   5. Deletes ITSELF. Its only job was steps 1-4, once, ever - it isn't
#      a library TapTuxCLI.py reaches for on every environment install
#      (that would mean re-running a whole bootstrap flow, with its own
#      manifest fetch and its own scratch/cleanup, every single time
#      someone installs an environment, which is a heavier, repeated
#      version of exactly the "downloads a general-purpose tool every
#      time" pattern this script exists to do ONCE). Per-environment
#      requirement installs are TapTuxRuntimeProvisioning.py's job.
#
# Token: TAPTUX_GITHUB_TOKEN env var, or a plain-text file at
# TapTuxInstallRoot/github_token - same two sources, same names,
# RemoteEnvironmentCatalog.py's LoadGithubToken() reads later. Never
# hardcoded, never logged, never written by this script.
set -euo pipefail

TapTuxInstallRoot="/data/data/com.termux/files/usr/var/lib/TapTux"
SharedInterpreterRoot="$TapTuxInstallRoot/Python"
DownloadCacheDirectory="$TapTuxInstallRoot/DownloadCache"
TermuxBinDirectory="/data/data/com.termux/files/usr/bin"
TapTuxCommandName="taptux"

GithubTokenEnvironmentVariable="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"
GithubTokenFileName="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"
GithubApiVersion="2022-11-28"
GithubApiBaseUrl="https://github.com/UniSoftCorp/TapTux-Repository/tree/main"
RepositoryOwner="UniSoftCorp"
RepositoryName="TapTux-Repository"
RepositoryBranch="main"
ManifestPath="TapTuxEnviroments.json"  # sic - the real filename in the repository
UserAgentValue="TapTuxCLISetup/1.0GithubTokenEnvironmentVariable="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"
GithubTo"

ScriptPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
ScriptDirectory="$(dirname "$ScriptPath")"
EntryScriptPath="$ScriptDirectory/TapTux.py"

log() { echo "TapTuxCLISetup: $*"; }
die() { echo "TapTuxCLISetup: $*" >&2; exit 1; }

require_curl() {
    command -v curl >/dev/null 2>&1 || die "curl is required but not installed - run: pkg install curl"
}

load_github_token() {
    if [ -n "${!GithubTokenEnvironmentVariable:-}" ]; then
        printf '%s' "${!GithubTokenEnvironmentVariable}"
        return 0
    fi
    local token_file="$TapTuxInstallRoot/$GithubTokenFileName"
    if [ -r "$token_file" ]; then
        tr -d '\n' < "$token_file"
        return 0
    fi
    return 1
}

# fetch_manifest <token> <dest_path> - single authenticated GET, no
# redirect involved (unlike release assets): the Contents API returns the
# raw file body directly when Accept is vnd.github.raw+json.
fetch_manifest() {
    local token="$1" dest="$2" url http_code
    url="$GithubApiBaseUrl/repos/$RepositoryOwner/$RepositoryName/contents/$ManifestPath?ref=$RepositoryBranch"
    http_code=$(curl -sS -o "$dest" -w '%{http_code}' \
        -H "Authorization: Bearer $token" \
        -H "Accept: application/vnd.github.raw+json" \
        -H "X-GitHub-Api-Version: $GithubApiVersion" \
        -H "User-Agent: $UserAgentValue" \
        "$url")
    [ "$http_code" = "200" ] || die "couldn't fetch $ManifestPath (HTTP $http_code)"
}

# extract_requirements <manifest_json_path> - prints "key<TAB>url" per
# entry of the FIRST container's "requirements" object. Brace-depth aware,
# not tied to any particular formatting; relies only on that object being
# a flat string->string map (no nesting), same assumption
# RemoteEnvironmentCatalog.py's ParseManifest makes.
extract_requirements() {
    awk '
        BEGIN { depth = 0; capturing = 0 }
        {
            line = $0
            if (!capturing) {
                if (match(line, /"requirements"[ \t]*:/)) {
                    capturing = 1
                    line = substr(line, RSTART + RLENGTH)
                } else { next }
            }
            n = gsub(/\{/, "{", line); m = gsub(/\}/, "}", line)
            if (capturing == 1 && n > 0) capturing = 2
            depth += n - m
            print line
            if (capturing == 2 && depth <= 0) exit
        }
    ' "$1" | grep -oE '"[A-Za-z0-9_-]+"[ \t]*:[ \t]*"[^"]*"' \
      | sed -E 's/^"([^"]+)"[ \t]*:[ \t]*"([^"]*)"$/\1\t\2/'
}

# download_asset <url> <token> <dest_path> - GitHub authenticates hop 1
# (Authorization + Accept: application/octet-stream) and 302s to a
# short-lived, pre-signed object-storage URL; hop 2 carries NO
# Authorization header - an unexpected auth header on a pre-signed URL
# commonly fails its own signature check. This is what a manifest entry's
# "download": {"type": "redirect"} names.
download_asset() {
    local url="$1" token="$2" dest="$3"
    local headers_file body_file http_code location
    headers_file="$(mktemp)"; body_file="$(mktemp)"

    http_code=$(curl -sS -D "$headers_file" -o "$body_file" -w '%{http_code}' --max-redirs 0 \
        -H "Authorization: Bearer $token" \
        -H "Accept: application/octet-stream" \
        -H "X-GitHub-Api-Version: $GithubApiVersion" \
        -H "User-Agent: $UserAgentValue" \
        "$url" 2>/dev/null) || http_code=$(grep -m1 -oE '^HTTP/[0-9.]+ [0-9]+' "$headers_file" | awk '{print $2}')

    case "$http_code" in
        200) mv "$body_file" "$dest"; rm -f "$headers_file" ;;
        301|302|303|307|308)
            location=$(grep -im1 '^location:' "$headers_file" | sed -E 's/^[Ll]ocation:[ \t]*//' | tr -d '\r\n')
            rm -f "$headers_file" "$body_file"
            [ -n "$location" ] || { echo "download_asset: redirect with no Location header" >&2; return 1; }
            local code2
            code2=$(curl -sS -o "$dest" -w '%{http_code}' -H "User-Agent: $UserAgentValue" "$location")
            [ "$code2" = "200" ] || { echo "download_asset: redirect target returned $code2" >&2; return 1; }
            ;;
        *) rm -f "$headers_file" "$body_file"; echo "download_asset: unexpected status '$http_code'" >&2; return 1 ;;
    esac
}

# process_requirement / finalize_pending_packages: classify PURELY by
# content/shape, never by the requirement's key name - the manifest's set
# of requirement keys is a sample, expected to grow, so nothing here may
# assume a fixed, known list of names. Two-pass so nothing needs a
# particular requirement to arrive first: package-shaped archives are
# staged under a pending dir and only placed into site-packages once
# every runtime-shaped archive (whichever one turns out to provide
# lib/pythonX.Y/) has already been merged.
process_requirement() {
    local downloaded="$1" runtime_root="$2" req_key="$3" pending_dir="$4"
    if tar tzf "$downloaded" >/dev/null 2>&1; then
        local scratch; scratch="$(mktemp -d)"
        tar xzf "$downloaded" -C "$scratch"
        if find "$scratch" -mindepth 1 -maxdepth 1 \
             \( -name bin -o -name lib -o -name include -o -name etc -o -name share \) | grep -q .; then
            mkdir -p "$runtime_root"; cp -a "$scratch"/. "$runtime_root"/
            log "runtime-merge: $req_key"
            rm -rf "$scratch"
        elif [ -f "$scratch/__init__.py" ]; then
            mkdir -p "$pending_dir"; mv "$scratch" "$pending_dir/$req_key"
            log "deferred (importable-package shape): $req_key"
        else
            local entries only_dir
            entries="$(find "$scratch" -mindepth 1 -maxdepth 1 | wc -l)"
            only_dir="$(find "$scratch" -mindepth 1 -maxdepth 1 -type d)"
            if [ "$entries" = "1" ] && [ -n "$only_dir" ] && [ -f "$only_dir/__init__.py" ]; then
                mkdir -p "$pending_dir"; mv "$only_dir" "$pending_dir/$(basename "$only_dir")"
                log "deferred (wrapped package shape): $req_key -> $(basename "$only_dir")"
                rm -rf "$scratch"
            else
                log "WARNING: unrecognized archive shape for '$req_key' - merging into runtime root as a best-effort default"
                mkdir -p "$runtime_root"; cp -a "$scratch"/. "$runtime_root"/
                rm -rf "$scratch"
            fi
        fi
    else
        if head -c 64 "$downloaded" | grep -q "BEGIN CERTIFICATE"; then
            mkdir -p "$runtime_root/etc/tls"; cp "$downloaded" "$runtime_root/etc/tls/cert.pem"
            log "ca-cert (from the manifest's own requirement, not Termux's): $req_key"
        else
            mkdir -p "$runtime_root/etc/$req_key"; cp "$downloaded" "$runtime_root/etc/$req_key/"
            log "WARNING: '$req_key' is a standalone file of an unrecognized kind - placed at etc/$req_key/, check it landed correctly"
        fi
    fi
}

finalize_pending_packages() {
    local runtime_root="$1" pending_dir="$2"
    [ -d "$pending_dir" ] || return 0
    local stdlib_dir
    stdlib_dir="$(find "$runtime_root/lib" -mindepth 1 -maxdepth 1 -type d -name 'python*' 2>/dev/null | head -n1)"
    if [ -z "$stdlib_dir" ]; then
        die "no stdlib directory was ever established (no requirement provided one) - can't place: $(ls "$pending_dir" | tr '\n' ' ')"
    fi
    local pkg name
    for pkg in "$pending_dir"/*; do
        [ -d "$pkg" ] || continue
        name="$(basename "$pkg")"
        mkdir -p "$stdlib_dir/site-packages/$name"
        cp -a "$pkg"/. "$stdlib_dir/site-packages/$name"/
        log "site-packages: $name"
    done
    rm -rf "$pending_dir"
}

install_taptux_command() {
    local binary="$1"
    [ -d "$TermuxBinDirectory" ] || { log "not a Termux install - skipping the '$TapTuxCommandName' command"; return 0; }
    local command_path="$TermuxBinDirectory/$TapTuxCommandName"
    {
        echo "#!$binary"
        echo "import runpy"
        echo "runpy.run_path('$EntryScriptPath', run_name='__main__')"
    } > "$command_path"
    chmod +x "$command_path"
}

main() {
    require_curl

    if [ -x "$SharedInterpreterRoot/bin/python3" ] || compgen -G "$SharedInterpreterRoot/bin/python3.*" >/dev/null 2>&1; then
        die "a shared runtime already exists at $SharedInterpreterRoot - nothing to do. Remove it first if you want to redo this."
    fi

    local token
    if ! token="$(load_github_token)"; then
        die "no GitHub token configured - set \$$GithubTokenEnvironmentVariable or write one to $TapTuxInstallRoot/$GithubTokenFileName"
    fi

    mkdir -p "$DownloadCacheDirectory" "$SharedInterpreterRoot"
    local manifest_path="$DownloadCacheDirectory/manifest.json"
    log "fetching $ManifestPath..."
    fetch_manifest "$token" "$manifest_path"

    local pending_dir="$DownloadCacheDirectory/pending"
    rm -rf "$pending_dir"
    local saw_any=0
    while IFS=$'\t' read -r req_key req_url; do
        [ -n "$req_key" ] || continue
        saw_any=1
        log "downloading '$req_key'..."
        local archive_path="$DownloadCacheDirectory/$req_key.download"
        download_asset "$req_url" "$token" "$archive_path" || die "failed to download requirement '$req_key'"
        process_requirement "$archive_path" "$SharedInterpreterRoot" "$req_key" "$pending_dir"
        rm -f "$archive_path"
    done < <(extract_requirements "$manifest_path")
    [ "$saw_any" = "1" ] || die "manifest has no requirements listed for its first container - nothing to install"

    finalize_pending_packages "$SharedInterpreterRoot" "$pending_dir"
    rm -f "$manifest_path"

    local binary
    binary="$(compgen -G "$SharedInterpreterRoot/bin/python3.*" | head -n1)"
    [ -n "$binary" ] || die "no interpreter binary found under $SharedInterpreterRoot/bin after extraction"
    chmod +x "$SharedInterpreterRoot/bin/"* 2>/dev/null || true

    log "smoke-testing the runtime..."
    PYTHONHOME="$SharedInterpreterRoot" LD_LIBRARY_PATH="$SharedInterpreterRoot/lib:${LD_LIBRARY_PATH:-}" \
        "$binary" -c "import sys, ssl; print('shared runtime ok:', sys.executable)" \
        || die "the downloaded runtime failed its smoke test - not installing the '$TapTuxCommandName' command"

    install_taptux_command "$binary"
    log "done - '$TapTuxCommandName' now runs $EntryScriptPath under $binary"

    if [ -f "$ScriptPath" ]; then
        rm -f -- "$ScriptPath"
    fi
}

main "$@"

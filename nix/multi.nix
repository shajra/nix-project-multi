{ coreutils
, jq
, nix-project-lib
, yj
}:

let
    progName = "nix-project-multi";
    meta.description =
        "Manage dependencies with a central project";
in

nix-project-lib.writeShellCheckedExe progName
{
    inherit meta;
    path = [
        coreutils
        jq
        yj
    ];
}
''
set -eu
set -o pipefail


PROJECTS=()
CONFIG_BASE=~/.config/nix-project/multi
CONFIG=
CENTRAL=
DRY_RUN=false
MODE=

. "${nix-project-lib.common}/share/nix-project/common.bash"


print_usage()
{
    cat - <<EOF
USAGE: ${progName} MODE [OPTION]... [PROJECT_SOURCES_JSON]...

DESCRIPTION:

    Manage dependencies for many projects from a centralized
    project.  The dependencies must be in the JSON format of
    the Niv tool.

MODES

    pull   pull dependencies into centralized project
    push   push dependencies out to managed projects

OPTIONS:

    --help             print this help message
    -C --config  PATH  path to configuration file to use
    -c --central PATH  centralized sources JSON
    -n --dry-run       print files affects, but don't run

EOF
}

main()
{
    CONFIG="$(guess_config)"
    while ! [ "''${1:-}" = "" ]
    do
        case "$1" in
        push|pull)
            MODE="$1"
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        -n|--dry-run)
            DRY_RUN=true
            ;;
        -C|--config)
            if [ -z "''${2:-}" ]
            then die "$1 requires argument"
            fi
            CONFIG="''${2:-}"
            shift
            ;;
        -p|--project)
            if [ -z "''${2:-}" ]
            then die "$1 requires argument"
            fi
            PROJECTS+=("''${2:-}")
            shift
            ;;
        -c|--central)
            if [ -z "''${2:-}" ]
            then die "$1 requires argument"
            fi
            CENTRAL="''${2:-}"
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            break
            ;;
        esac
        shift
    done

    if [ "$#" -gt 0 ]
    then PROJECTS=("$@")
    fi

    validate_and_read_config
    validate_inputs
    report_plan
    if "$DRY_RUN"
    then
        log_info "DRY RUN: no files will be altered"
    else
        case "$MODE" in
        pull) pull ;;
        push) push ;;
        esac
    fi
}

guess_config()
{
    for ext in yaml json
    do
        if [ -r "$CONFIG_BASE.$ext" ] && [ -f "$CONFIG_BASE.$ext" ]
        then
            echo "$CONFIG_BASE.$ext"
            break
        fi
    done
}

validate_and_read_config()
{
    if [ -n "$CONFIG" ]
    then
        if [ -r "$CONFIG" ] && [ -f "$CONFIG" ]
        then read_config
        else die "not readable file: $CONFIG"
        fi
    fi
}

read_config()
{
    log_info "CONFIG: $CONFIG"
    local config
    config="$(
        if [[ "$CONFIG" == *.yaml ]]
        then yj -yj < "$CONFIG"
        elif [[ "$CONFIG" == *.hcl ]]
        then yj -cj < "$CONFIG"
        elif [[ "$CONFIG" == *.toml ]]
        then yj -tj < "$CONFIG"
        elif [[ "$CONFIG" == *.json ]]
        then yj -jj < "$CONFIG"
        else die "file format not recognized: $CONFIG"
        fi | jq '{packages: [], central: ""} + .'
    )"
    if [ "''${#PROJECTS[@]}" -eq 0 ]
    then mapfile -t PROJECTS < <(echo "$config" | jq -r '.packages[]')
    fi
    if [ -z "$CENTRAL" ]
    then CENTRAL=$(echo "$config" | jq -r '.central')
    fi
}

validate_inputs()
{
    if [ -z "$CENTRAL" ]
    then die "no central sources JSON specified"
    fi

    case "$MODE" in
    pull)
        if ! [ -w "$CENTRAL" ]
        then die "can't write to central sources JSON: $CENTRAL"
        fi
        ;;
    push)
        if ! [ -r "$CENTRAL" ]
        then die "can't read from central sources JSON: $CENTRAL"
        fi
        ;;
    *)
        die "no mode provided"
        ;;
    esac

    for p in "''${PROJECTS[@]}"
    do
        case "$MODE" in
        pull)
            if ! [ -r "$p" ]
            then die "can't read from project sources JSON: $p"
            fi
            ;;
        push)
            if ! [ -w "$p" ]
            then die "can't write to project sources JSON: $p"
            fi
            ;;
        esac
        if [ "$(readlink -f "$p")" = "$(readlink -f "$CENTRAL")" ]
        then die "projects can't include central project: $p"
        fi
    done
}

report_plan()
{
    for p in "''${PROJECTS[@]}"
    do log_info "PROJECT: $p"
    done
    log_info "CENTRAL: $CENTRAL"
}

pull()
{
    jq --sort-keys --slurp \
        'reduce .[] as $p ({}; . + $p)' \
        "''${PROJECTS[@]}" \
        >"$CENTRAL"
}

push()
{
    for p in "''${PROJECTS[@]}"
    do
        jq --sort-keys --slurp '
              .[0] as $project
            | .[1] as $central
            | $central
            | to_entries
            | reduce .[] as $c ([] ; if ($c.key | in($project)) then . + [$c] else . end)
            | from_entries
            | $project + .
        ' \
        "$p" "$CENTRAL" \
        >"$p.replacement"
        mv "$p.replacement" "$p"
    done
}

log_info()
{
    echo "INFO: $*" >&2
}


main "$@"
''

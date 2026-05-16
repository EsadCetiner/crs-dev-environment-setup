#!/bin/bash

set -eEuo pipefail
trap 'echo "Error on line $LINENO with command: $BASH_COMMAND"; exit 1' ERR
rules_path=""
new_tests_generated=false

help()
{

cat << EOF
generate-template-tests.sh: Generates boilerplate tests for new SecLang rules
Usage:
Syntax: generate-template-tests.sh -p [/path/to/seclang-rules/]

options:
  -h, --help    Displays this help menu
  -p, --path    The path to the SecLang rules (Required)
  -a, --author  Specifies the Author to add in tests.
EOF

}

parse_args()
{
    if [[ $# -eq 0 ]]; then
        echo "error: No arguments provided"
        help
        exit 1
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                help
                exit
                ;;
            -p|--path)
                if [[ -n "$2" ]]; then
                    rules_path="$2"
                    shift 2
                else
                    echo "error: Argument for option -p/--path is missing."
                    help
                    exit 1
                fi
                ;;
            -a|--author)
                if [[ -n "$2" ]]; then
                    test_author="$2"
                    shift 2
                else
                    echo "error: Argument for option -p/--path is missing."
                    help
                    exit 1
                fi
                ;;
            *)
                echo "error: Unknown option '$1'"
                help
                exit 1
                ;;
        esac
    done
}

generate_templates()
{
    # When grepping for rule ids, this command could fail if a *-before or *-after .conf doesn't exist.
    # In some cases that can be expected behavior, such errors are filtered out and ignored only here.
    # Worst case scenario this means no test templates are generated,
    # that case is handled later in this function.
    #
    # Globbing is a feature, not a bug
    # shellcheck disable=SC2086
    rule_ids=$(grep -v "\#" $rules_path/plugins/*-{before,after}.conf 2> >(grep -v 'No such file or directory' >&2) | grep -oE "id:[0-9]+" | sed "s/id://g" || true)

    # Tests are usually located in tests/regression/<plugin-name>, this tries to get
    # the last folder name.
    tests_folder=$(ls "$rules_path/tests/regression/")

    # Splitting is a feature not a bug
    # shellcheck disable=SC2068
    for i in ${rule_ids[@]};do
        # Avoid overriding existing tests
        if [ ! -f "$rules_path/tests/regression/$tests_folder/$i.yaml" ];then
            cat <<EOF > "$rules_path/tests/regression/$tests_folder/$i.yaml"
---
meta:
  author: "$test_author"
  description: "FIXME"
rule_id: $i
tests:
  - test_id: 1
    desc: FIXME
    stages:
      - input:
          dest_addr: 127.0.0.1
          headers:
            Host: localhost
            User-Agent: OWASP CRS test agent
            Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5
          port: 80
          method: GET
          uri: /
          version: HTTP/1.1
        output:
          log:
            no_expect_ids: [FIXME]
EOF
        new_tests_generated=true
        fi
    done;

    # Check if tests were actually generated, if not then that
    # could indicate something is broken.
    if [ "$new_tests_generated" == true ];then
        echo "Boilerplate tests have been generated successfully!"
        exit
    fi
    echo "Warning: New boilerplate tests were not generated, do tests already exist?"
}

main()
{
    parse_args "$@"
    generate_templates
}

main "$@"

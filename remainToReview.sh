#!/bin/bash
#
# Check how many assignments have been reviewed and graded.
#


die() { echo "$*" >&2; exit 2; }  # complain to STDERR and exit with error
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --$OPT option"; fi; }

GRADED=0;

while getopts vhg: OPT; do
    if [ "$OPT" = "-" ]; then
	OPT="${OPTARG%%=*}"       # extract long option name
	OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
	OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
    fi
    
    case "${OPT}" in
	g | graded)
	    GRADED=1
	    ;;
        h)
            echo "usage: $0 [-v] [--graded] <FOLDER>" >&2
            exit 2
            ;;

        v) 
	    VERBOSE=true
            ;;
        *)
            if [ "$OPTERR" != 1 ] || [ "${optspec:0:1}" = ":" ]; then
                echo "Non-option argument: '-${OPTARG}'" >&2
            fi
            ;;
    esac
done



shift $((OPTIND-1)) # remove parsed options and args from $@ list

folder=$1


assignments=$(ls "$folder" | wc -l | tr -d ' ')
reviewed=$(ls "$folder"/*/feedback.txt | wc -l | tr -d ' ')
graded=$(grep 'GRADE:' "$folder"/*/feedback.txt | wc -l | tr -d ' ')
grades=$(grep -h 'GRADE:' "$folder"/*/feedback.txt | sort | uniq -c)


if [[ "$GRADED" == "1" ]]; then
    echo "$grades"
else
    
    echo "$graded $reviewed/$assignments"
fi

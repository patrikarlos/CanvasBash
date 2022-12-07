#!/bin/bash
# Download student submissions from a Canvas Course.
#
# Syntax:
#      listMyCourses.sh [-v] [-h] [role]
# 
#
#
# Description
# role = teacher, student, ta, observer, designer
#
## Requires a CANVAS token in TOKEN
## Requires Openstack credentials to be sourced.



##
## Hard settings..
#What's the educational institutes name(site) at Instructure?
site=bth
##Change this to a larger number, if you have many students/courses.
##Used due to Canvas pagination, normally canvas returns the equivalent of 10.
##This changes it to maxEntries. However, be carefull. 
maxEntries=10000;

die() { echo "$*" >&2; exit 2; }  # complain to STDERR and exit with error
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --$OPT option"; fi; }



VERBOSE=false


while getopts vh: OPT; do
    if [ "$OPT" = "-" ]; then
	OPT="${OPTARG%%=*}"       # extract long option name
	OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
	OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
    fi
    
    case "${OPT}" in
        h)
            echo "usage: $0 [-v] [role]" >&2
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
role=$1


if [ -z $TOKEN ]; then
    echo "Your missing the Canvas API token. Grab one from your Profile page."
    exit;
fi


if [ "$VERBOSE" = true ]; then
    echo "Collecting data from Canvas."
fi

#Trying to find ID
if [ -z "$role" ]; then
    echo "Looking for all roles"
    role="teacher student ta obsererver designer"
else
    echo "Looking only for $role."
fi



all=("$role")
#echo "Loop: $all"
for myRole in $all; do
#    echo "$myRole;"
    courseData=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses?enrollment_type=$myRole&state=available&per_page=$maxEntries" | jq -r '.[] | {id, name}' |  jq "[.[]] | @tsv" | sed 's/\\t/*/g' | tr -d '"' )

    if [ -z "$courseData" ]; then
	continue;
    fi
	
#    echo "CourseData = |$courseData| "
    while read Q; do
#	echo "Q=|$Q| "
	courseID=$(echo "$Q" | awk -F'*' '{print $1}')
	courseString=$(echo "$Q" | awk -F'*' '{print $2}')
	echo "$myRole - $courseID - '$courseString' "	
    done < <(echo "$courseData")

#    courseID=$(echo "$courseData" | awk -F'*' '{print $2}')
#    courseString=$(echo "$courseData" | awk -F'*' '{print $1}')

    found=$(echo "$courseID" | wc -l )
    if [ "$VERBOSE" = true ]; then
	echo "found $found"
    fi
   

done
	      


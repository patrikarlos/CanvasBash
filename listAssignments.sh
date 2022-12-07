#!/bin/bash
# List assignments associated with a Canvas Course.
#
# Syntax:
#      listAssignments.sh [-v] [-h] CourseCode
# 
#
#
# Description
#
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
IGNOREFILE=
created=0
added=0


while getopts vhi:-: OPT; do
    if [ "$OPT" = "-" ]; then
	OPT="${OPTARG%%=*}"       # extract long option name
	OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
	OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
    fi
    
    case "${OPT}" in
	i | ignore)
	    needs_arg;
	    IGNOREFILE="$OPTARG"
	    ;;
        h)
            echo "usage: $0 [-v] [--ignore=<filename>] <COURSECODE> <ASSIGNMENT>" >&2
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

courseCode=$1
assignment=$2
location=$3

if [ -z $TOKEN ]; then
    echo "Your missing the Canvas API token. Grab one from your Profile page."
    exit;
fi

if [ -z "$courseCode" ]; then
    echo "Your missing the course ID, find it from Canvas."
    exit;
fi

echo  "My input; '$courseCode' "



#echo "curl -H \"Authorization: Bearer $TOKEN\" \"https://$site.instructure.com/api/v1/courses/$courseID/users\" "
if [ "$VERBOSE" = true ]; then
    echo "Collecting data from Canvas."
fi

#Trying to find ID
courseData=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses?enrollment_type=teacher&state=available&per_page=$maxEntries" | jq -r '.[] | {name, id}' |  jq "[.[]] | @tsv" | sed 's/\\t/*/g' | tr -d '"' | grep "$courseCode")
courseID=$(echo "$courseData" | awk -F'*' '{print $2}')
courseString=$(echo "$courseData" | awk -F'*' '{print $1}')


found=$(echo "$courseID" | wc -l | tr -d ' ')

#echo "|$courseData|$courseID|$courseString|$found|"


if [ "$VERBOSE" = true ]; then
    echo "found $found"
fi

if [[ "$found" -gt "1" ]]; then
    echo "Too many matches, narrow your Course code."
    echo "Add semester, i.e. 'CourseCode HT22'"
    exit;
fi

if [ -z "$courseID" ]; then
    echo "Did not find a course. Check your syntax (code),|$courseCode|."
    echo "Did not find a course. Check your syntax (ID),|$courseID|."
    
    exit;
fi

echo "Course ID: $courseID - $courseString "


data1=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID")
name=$(echo $data1 | jq '.name')
if [ "$VERBOSE" = true ]; then
    echo "Course: $name"
fi

#TEST
assignmentData=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments?per_page=$maxEntries" | jq -r '.[] | {name, id}' |  jq "[.[]] | @tsv" | sed 's/\\t/*/g' | tr -d '"')


echo "AssignmentID - Name - Graded - Ungraded - Notsubmitted."
while read Q; do 

#    echo "Q=|$Q|"
    assignmentID=$(echo "$Q" | awk -F'*' '{print $2}')
    assignmentString=$(echo "$Q" | awk -F'*' '{print $1}')


    subStatus=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submission_summary" | jq )
    graded=$(echo "$subStatus" | grep 'graded' | grep -v 'ungraded' | awk -F':' '{print $2}' | tr -d ',')
    ungraded=$(echo "$subStatus" | grep -v 'ungraded' | grep 'graded' | awk -F':' '{print $2}' | tr -d ',' )
    notsubmitted=$(echo "$subStatus" | grep 'not_submitted' | awk -F':' '{print $2}')
    
    echo "$assignmentID - $assignmentString - $graded - $ungraded - $notsubmitted"
    
done < <(echo "$assignmentData")



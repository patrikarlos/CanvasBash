#!/bin/bash
# Lists students in a Canvas Course.
#
# Syntax:
#      listStudents.sh [-v] [-h] CourseCode
# 
#
#
# Description
#
#
## Requires a CANVAS token in TOKEN



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


if [[ $(uname) == "Linux" ]]; then
    HASHALGO=md5sum
    HASHARG=
elif [[ $(uname) == "Darwin" ]]; then
    HASHALGO=md5
    HASHARG=-q
else
    HASHALGO=md5sum
    HASHARG=--quiet
fi
    
VERBOSE=false
MISSING=false
LATE=false
created=0
added=0
DLGRADED=0;

PASSWDFILE=$(mktemp)

while getopts vh:-: OPT; do
    if [ "$OPT" = "-" ]; then
	OPT="${OPTARG%%=*}"       # extract long option name
	OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
	OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
    fi
    
    case "${OPT}" in
        h)
            echo "usage: $0 [-v]  <COURSECODE> " >&2
            exit 2
            ;;

        v)
	    echo "Verbose activated"
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

if [ "$VERBOSE" = true ]; then
    echo  "My input; '$courseCode'"
fi

if ! [[ "$courseCode" =~ ^[a-zA-Z]{1,3} ]]; then
    echo "Argument should be the beginning of a course code."
    echo "At BTH that is for instance dv2602. "
    exit;
fi




#echo "curl -H \"Authorization: Bearer $TOKEN\" \"https://$site.instructure.com/api/v1/courses/$courseID/users\" "
if [ "$VERBOSE" = true ]; then
    echo "Collecting data from Canvas."
fi

#Trying to find ID
courseData=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses?enrollment_type=teacher&state=available&per_page=$maxEntries" | jq -r '.[] | {name, id}' |  jq "[.[]] | @tsv" | sed 's/\\t/*/g' | tr -d '"' | grep "^$courseCode")
courseID=$(echo "$courseData" | awk -F'*' '{print $2}')
courseString=$(echo "$courseData" | awk -F'*' '{print $1}')


found=$(echo "$courseID" | wc -l | tr -d ' ')




if [ "$VERBOSE" = true ]; then
    echo "|$courseData|$courseID|$courseString|$found|"
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




data1=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID")
name=$(echo $data1 | jq '.name')
if [ "$VERBOSE" = true ]; then
    echo "Course ID: $courseID - $courseString - $name"
fi


## Get sections
sections_w_studentcnt=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/sections?include[]=total_students&per_page=$maxEntries" | jq -r '.[] | {id,name,total_students}'|  jq "[.[]] | @tsv" | sed 's/\\t/*/g' | tr -d '"')

#Get students per section
#curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/sections?include[]=students&per_page=$maxEntries" | jq

#Get total students per section
#curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/sections?include[]=total_students&per_page=$maxEntries" | jq


#Get students
studentData=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/users?per_page=$maxEntries" | jq -r '.[] | {id,sortable_name,email}' |  jq "[.[]] | @tsv" | sed 's/\\t/*/g' | tr -d '"')


echo "First Name, Last Name, Email Address"

while read line; do
    read -r data <<<"$(echo "$line")"
    ID=$(echo "$data" | awk -F'*' '{print $1}')
    NAME=$(echo "$data" | awk -F'*' '{print $2}')
    EMAIL=$(echo "$data" | awk -F'*' '{print $3}')


    LASTNAME=$(echo "$NAME" | awk -F',' '{print $1}' | sed 's/^[ \t]*//')
    FIRSTNAME=$(echo "$NAME" | awk -F',' '{print $2}' | sed 's/^[ \t]*//')

    ## Before printing, verify that it is a student, and not something else, like teacher.
    ## Perhaps use sections to identify students/teachers, alt. see assignments? 

    ## COnfig this to be an input option  --lfe, --fle, --efl, --elf, --en
#    echo "$LASTNAME,$FIRSTNAME,$EMAIL"
    echo "$FIRSTNAME,$LASTNAME,$EMAIL"

done < <(echo "$studentData" ) # | head -10 )

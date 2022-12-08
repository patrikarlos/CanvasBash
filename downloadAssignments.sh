#!/bin/bash
# Download student submissions from a Canvas Course.
#
# Syntax:
#      downloadAssignments.sh [-v] [-h] CourseCode AssignmentID
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
MISSING=false
LATE=false
created=0
added=0
DLGRADED=0;

PASSWDFILE=$(mktemp)

while getopts glmvhi:-: OPT; do
    if [ "$OPT" = "-" ]; then
	OPT="${OPTARG%%=*}"       # extract long option name
	OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
	OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
    fi
    
    case "${OPT}" in
	m | missing)
	    MISSING=true
	    ;;
	g | graded)
	    DLGRADED=1
	    ;;
	l | late)
	    LATE=true
	    ;;	
        h)
            echo "usage: $0 [-v] [--late] [--missing] <COURSECODE> <ASSIGNMENT>" >&2
            exit 2
            ;;

        v) 
	    VERBOSE=true
	    LATE=true
	    MISSING=true
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

if [ -z "$assignment" ]; then
    echo "Your missing the assignment ID, find it from Canvas."
    exit;
fi

if [ -z "$location" ]; then
    echo "Your missing the location where to store the downloaded data."
    exit;
fi

echo  "My input; '$courseCode' / $assignment "



#echo "curl -H \"Authorization: Bearer $TOKEN\" \"https://$site.instructure.com/api/v1/courses/$courseID/users\" "
if [ "$VERBOSE" = true ]; then
    echo "Collecting data from Canvas."
fi

#Trying to find ID
courseData=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses?enrollment_type=teacher&state=available&per_page=$maxEntries" | jq -r '.[] | {name, id}' |  jq "[.[]] | @tsv" | sed 's/\\t/*/g' | tr -d '"' | grep "^$courseCode")
courseID=$(echo "$courseData" | awk -F'*' '{print $2}')
courseString=$(echo "$courseData" | awk -F'*' '{print $1}')


found=$(echo "$courseID" | wc -l | tr -d ' ')

echo "|$courseData|$courseID|$courseString|$found|"


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

#echo "Course ID: $courseID - $courseString "


data1=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID")
name=$(echo $data1 | jq '.name')
if [ "$VERBOSE" = true ]; then
    echo "Course: $name"
fi

#TEST
assignmentData=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments?per_page=$maxEntries" | jq -r '.[] | {name, id}' |  jq "[.[]] | @tsv" | sed 's/\\t/*/g' | tr -d '"' | grep "^$assignment\*" )


assignmentID=$(echo "$assignmentData" | awk -F'*' '{print $2}')
assignmentString=$(echo "$assignmentData" | awk -F'*' '{print $1}')

found=$(echo "$assignmentID" | wc -l )
if [ "$VERBOSE" = true ]; then
    echo "found $found"
fi

if [[ "$found" -gt "1" ]]; then
    echo "Too many matches, narrow your assignment identifier."
    echo "Add semester, i.e. 'CourseCode HT22'"
    exit;
fi

if [ -z "$assignmentID" ]; then
    echo "Did not find the assignmen. Check your syntax,|$assignment|."
    exit;
fi


echo "Course ID: $courseID - $courseString  Assignment: $assignmentID - $assignmentString"

## Grab student id + names.
##PRODUCTION
data=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/users?per_page=$maxEntries")

emails=$(echo "$data" | jq ".[].email" | tr -d '"')
names=$(echo "$data" | jq ".[].name" | tr -d '"')
studids=$(echo "$data" | jq ".[].name" | tr -d '"')


emname=$(echo "$data" | jq ".[] | {id,email,name}"  | jq "[.[]] | @csv" |  sed 's|\\\"||g' | sed 's|,|\",\"|g') # | tr -d '\\' | tr ',' ' ' )
#echo "$emname"
emStrip=$(echo "$emname" | awk -F',' '{print $1","$2","$3}' | tr -d '"')
#echo "$emname"

echo "$emStrip" > bobby
echo "$emname" > bob

cnt=$(echo "$emStrip" | wc -l | tr -d ' ') 

submissions=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions?per_page=$maxEntries" | jq | grep 'submitted_at' | grep -v 'null' | wc -l | tr -d ' ')

studSubmitted=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions?per_page=$maxEntries" | jq ".[] | {user_id} | to_entries|map(.value)|@csv" | sed 's|\\\"||g' | sed 's|,|\",\"|g')
#reqGrading=$(echo "$studReqGrading" | wc -l | tr -d ' ')

subStatus=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submission_summary" | jq )
graded=$(echo "$subStatus" | grep 'graded' | grep -v 'ungraded' | awk -F':' '{print $2}')
ungraded=$(echo "$subStatus" | grep -v 'ungraded' | grep 'graded' | awk -F':' '{print $2}')
notsubmitted=$(echo "$subStatus" | grep 'not_submitted' | awk -F':' '{print $2}')


#echo "We have $cnt students to check, $submissions submissions, and $reqGrading students needed to be graded."
echo "We have $cnt students to check and $submissions submissions."
echo "We have $cnt students, and there are $graded graded, $ungraded ungraded, and $notsubmitted assignments."

missingStudents=""
lateStudents=""

while read line; do
    read -r data <<<"$(echo "$line")"
    ID=$(echo "$data" | awk -F',' '{print $1}')
    EMAIL=$(echo "$data" | awk -F',' '{print $2}')
    NAME=$(echo "$data" | awk -F',' '{print $3}')

    canvasDownloadName=$(echo "$NAME" | awk '{printf tolower($(NF)); for(c=1;c<NF;c++)printf tolower($c);}' )
    
    #check if student is among the submitted.
    here=$(echo "$studSubmitted" | grep -e "$ID")
    if [ -z "$here" ]; then
	echo "$ID -- $NAME have not submitted this assignment for some reason."
	continue;
    fi


    checkForErrorMessage=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID" | jq | grep "The specified resource does not exist." )
    if [ ! -z "$checkForErrorMessage" ]; then
	echo "$ID -- $NAME should be ignornoSubmissioncheckForErrorMessage'"
	continue;
    fi

    
    
    #Translate NAME to a FOLDER"  ie (replace ' '  with '_'
    studFolderName=$(echo "$NAME" | tr ' ' '_')
    noAttachements=$(echo "$aData" | wc -l | tr -d ' ')								     
#    echo " $noAttachements"


    
    echo -n "$ID -- $NAME -- $EMAIL -> $location/$studFolderName "


    
    noSubmission=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID" | jq | grep workflow_state | grep unsubmitted)
    submissionGraded=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID" | jq | grep workflow_state | grep graded)
    
    ## Add logic to check if its a 'new' or old (reviewed) submission. If old, and already reviewed do not work with it.
    OVERRIDE=0
    if [[ "$submissionGraded" && "$DLGRADED" -eq "1" ]]; then
	submissionGraded=""
	OVERRIDE=1
    fi


    
    if [[ -z "$noSubmission"  && -z "$submissionGraded" ]]; then

	echo -n " submitted"
	if [ "$OVERRIDE" -eq "1" ]; then
	    echo " (forced retreival, already graded)."
	else
	    echo "."
	fi
	
	#Create dir, abort if failed.?
	mkdir -p $location/$studFolderName
	if [ $? -ne 0 ]; then
	    echo "Cant create $location/$studFolderName";
	    exit;
	fi

	
	metaData=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID" | jq '{grade,graded_at,grader_id,seconds_late,submitted_at} | to_entries|map(.value)|@csv ')

	grade=$(echo "$metaData" | awk -F',' '{print $1}' | tr -d '"\')
	gradedat=$(echo "$metaData" | awk -F',' '{print $2}' | tr -d '"\')
	graderid=$(echo "$metaData" | awk -F',' '{print $3}' | tr -d '"\')
	lateSeconds=$(echo "$metaData" | awk -F',' '{print $4}' | tr -d '"\')
	submittedat=$(echo "$metaData" | awk -F',' '{print $5}' | tr -d '"\')

	lateDays=$(echo "scale=0; $lateSeconds/86400"|bc )
	lateHours=$(echo "scale=0; $lateSeconds/3600"|bc )

	graderName=$(echo "$emname" | tr -d '"' | grep "^$graderid," | awk -F',' '{print $3}' )
	
	if [ -z "$submittedat" ]; then
	    echo "Not submitted."
	    continue;
	fi
	
	if [ "$lateDays" -ne "0" ]; then
	    lateTime="$lateDays days"
	else
	    lateTime="$lateHours hours"
	fi

	if [ "$lateSeconds" -eq "0" ]; then
	    lateTime="Not late"
	else
	    if [ -z "$lateStudents" ]; then
		lateStudents="$ID -- $NAME -- $EMAIL -- $lateTime ($lateSeconds)"
	    else
		lateStudents="$lateStudents\n$ID -- $NAME -- $EMAIL -- $lateTime ($lateSeconds)"
	    fi
	fi
	
	if [ -z "$grade" ]; then	   
	    echo -e "\tAssignment has not been graded, it was submitted on $submittedat ($lateTime)"
	else
	    echo -e "\tMETA:$grade, $gradedat, $graderid ($graderName), $submittedat ($lateTime)"
	fi
	
	if [ -z "$grade" ]; then grade="Not graded";  fi
	if [ -z "$gradedat" ]; then gradedat="Not graded";  fi
	if [ -z "$graderid" ]; then graderid="Not graded";  fi
	if [ -z "$lateSeconds" ]; then lateSeconds="0";  fi
	

	echo -e "ID:$ID\nNAME:$NAME\nEMAIL:$EMAIL\nCANVASDLNAME:$canvasDownloadName" > "$location/$studFolderName/META.txt"
	echo -e "GRADE:$grade\nGRADEDAT:$gradedat\nGRADERID:$graderid\nLATESECONDS:$lateSeconds\nLATEDAYS:$lateDays\nLATEHOURS:$lateHours\nSUBMITTEDAT:$submittedat" >> "$location/$studFolderName/META.txt"


	aData=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID" | jq '.attachments[] | {display_name,size,updated_at,filename,url,id,created_at, updated_at} | to_entries|map(.value)|@csv ')
	noAttachements=$(echo "$aData" | wc -l | tr -d ' ')

	while read assData; do
	    dname=$(echo "$assData" | awk -F',' '{print $1}' | tr -d '"')
	    fsize=$(echo "$assData" | awk -F',' '{print $2}' | tr -d '"')
	    updated=$(echo "$assData" | awk -F',' '{print $3}' | tr -d '"')
	    url=$(echo "$assData" | awk -F',' '{print $5}' | sed 's|\"\"|\"|g' | tr -d '"')
	    assID=$(echo "$assData" | awk -F',' '{print $6}' | tr -d '"')

	    echo -en "\t$dname ($fsize) $url " #(|$assData|)"

	    ##Making sure that we will not have collisions on filenames that we will use. 
	    if [[ "$dname" == *"Feedback.txt" ]]; then
		echo "Changing filename, to student_Feedback.txt"
		dname="student_Feedback.txt"
	    fi

	    if [[ "$dname" == *"META.txt" ]]; then
		echo "Changing filename, to student_META.txt"
		dname="student_META.txt"
	    fi

	    if [[ "$dname" == *"turnitin.txt" ]]; then
		echo "Changing filename, to student_turnitin.txt"
		dname="student_turnitin.txt"
	    fi
	    if [[ "$dname" == *"comments.txt" ]]; then
		echo "Changing filename, to student_comments.txt"
		dname="student_comments.txt"
	    fi
	    
	    
	    
#	    echo " "
#	    echo "Download curl --output \"$location/$studFolderName/$dname\" -L \"$url\" "
	    curl -s --output "$location/$studFolderName/$dname" -L "$url"
	    datum1=$(date +%s)
	    datum2=$(date)
	    if [ $? -ne 0 ]; then
		echo " Problems downloading."
	    else
		echo " Downloaded."
		echo -e "FILE:$dname $datum1 ($datum2)" >> "$location/$studFolderName/META.txt"
	    fi

	done < <(echo "$aData")
	
	##Grab comments
	comments=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID?include[]=submission_comments" | jq '.submission_comments[]' )
	if [ -z "$comments" ]; then
	    echo -e "\tNo comments found in submission."
	else
	    
	    comments=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID?include[]=submission_comments" | jq '.submission_comments[] | {created_at,author,comment}' | jq --slurp 'map({date: .created_at, who: .author.display_name, com: .comment})' | jq --slurp '.[] | sort_by(.date)' | jq '.[] | "\(.date), \(.who), \(.com)"')
	    echo "$comments" > $location/$studFolderName/comments.txt
	    commentCNT=$(echo "$comments" | wc -l | tr -d ' ')
	    echo -e "\t$commentCNT comments found -> $location/$studFolderName/comments.txt"
	    echo -e "COMMENT:comments" >> "$location/$studFolderName/META.txt"
	fi
	
	##Grab similarity ratings
	turnit=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID?include[]=submission_comments" | jq -r '.turnitin_data | to_entries[] | select(.key|startswith("attachment"))|.value | {attachment_id,similarity_score,report_url} | to_entries | map(.value) | @csv' )


	echo -e "\tPlagiarism report(s)"
	if [ -f "$location/$studFolderName/turnitin.txt" ]; then
	    rm -f "$location/$studFolderName/turnitin.txt"
	fi
	
	while read turnData; do
	    a_id=$(echo "$turnData" | awk -F',' '{print $1}')
	    info=$(echo "$aData" | grep "$a_id")
	    fname=$(echo "$info" | awk -F',' '{print $1}' | tr -d '"\\')
	    fnID=$(echo "$info" | awk -F',' '{print $6}' | tr -d '"\\')
	    score=$(echo "$turnData" | awk -F',' '{print $2}')
	    reportURL=$(echo "$turnData" | awk -F',' '{print $3}')

#	    echo "--------"
	    if [ -z "$score" ]; then
		echo -e "\t\t$fname ($fnID) No analysis done."
		echo "$fname ($fnID) No analysis done." >>  "$location/$studFolderName/turnitin.txt"
		
	    else
		echo -e "\t\t$fname ($fnID) $score $reportURL"
		echo "$fname ($fnID) $score $reportURL" >>  "$location/$studFolderName/turnitin.txt"
	    fi
#	    echo -e "\t$info - $turnData"
	    
	done < <(echo "$turnit")
	
	#	    echo " "
	
	
    else
	
	if [ ! -z "$noSubmission" ]; then 
	    
	    echo " -- Missing Submission -- "
	    if [ -z "$missingStudents" ]; then
		missingStudents="$ID -- $NAME -- $EMAIL"
	    else
		missingStudents="$missingStudents\n$ID -- $NAME -- $EMAIL"
	    fi
	fi
	if [ ! -z "$submissionGraded" ]; then
	    echo " -- Already Graded -- "
	fi
    fi 

    

done < <(echo "$emStrip" | head -10 )

if [ "$LATE" = true ]; then    
    echo "Late submission"
    echo -e "$lateStudents"
fi
if [ "$MISSING" = true ]; then    
    echo "Missing submission"
    echo -e "$missingStudents"
fi

#echo "$emStrip"





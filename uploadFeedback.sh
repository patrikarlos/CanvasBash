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
PUSHGRADED=0



while getopts plmvhi:-: OPT; do
    if [ "$OPT" = "-" ]; then
	OPT="${OPTARG%%=*}"       # extract long option name
	OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
	OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
    fi
    
    case "${OPT}" in
	m | missing)
	    MISSING=true
	    ;;
	p | push)
	    PUSHGRADED=1
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
	if [[ "$ID" == "1" ]]; then # PAL=45
	    echo "$ID -- $NAME SPECIAL TEST CASE!!!"
	else
	    echo "$ID -- $NAME have not submitted this assignment for some reason."
	    continue;
	fi
    fi


    checkForErrorMessage=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID" | jq | grep "The specified resource does not exist." )
    if [ ! -z "$checkForErrorMessage" ]; then
	if [[ "$ID" == "1" ]]; then #PAL = 45
	    echo "$ID -- $NAME SPECIAL TEST CASE!!!"
	else
	    echo "$ID -- $NAME should be ignornoSubmissioncheckForErrorMessage'"
	    continue;
	fi
    fi
    
    #Translate NAME to a FOLDER"  ie (replace ' '  with '_'
    studFolderName=$(echo "$NAME" | tr ' ' '_')
    noAttachements=$(echo "$aData" | wc -l | tr -d ' ')								     

    
    echo -n "$ID -- $NAME -- $EMAIL -> $location/$studFolderName "

    
    noSubmission=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID" | jq | grep workflow_state | grep unsubmitted)
    submissionGraded=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID" | jq | grep workflow_state | grep graded)

    ## Add logic to check if its a 'new' or old (reviewed) submission. If old, and already reviewed do not work with it.
    OVERRIDE=0
    if [[ "$submissionGraded" && "$PUSHGRADED" -eq "1" ]]; then
	submissionGraded=""
	OVERRIDE=1
	##Reading old info.
	metaData=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID" | jq '{grade,graded_at,grader_id,seconds_late,submitted_at} | to_entries|map(.value)|@csv ')
	
	OLDgrade=$(echo "$metaData" | awk -F',' '{print $1}' | tr -d '"\')
	OLDgradedat=$(echo "$metaData" | awk -F',' '{print $2}' | tr -d '"\')
	OLDgraderid=$(echo "$metaData" | awk -F',' '{print $3}' | tr -d '"\')
	OLDlateSeconds=$(echo "$metaData" | awk -F',' '{print $4}' | tr -d '"\')
	OLDsubmittedat=$(echo "$metaData" | awk -F',' '{print $5}' | tr -d '"\')
	
#	echo -e "\nold Grade: $grade|$gradedat|$graderid|$submittedat|"
    fi
    
    
    if [[ -z "$noSubmission"  && -z "$submissionGraded" ]]; then
	echo -n " submitted"
	
	if [ "$OVERRIDE" -eq "1" ]; then
	    echo " (forced push, already graded)."
	else
	    echo "."
	fi
	
	FEEDBACK=0
	GRADE=-1
	if [ -e "$location/$studFolderName/feedback.txt" ]; then
	    #	    echo -e "\tFeedback present."
	    GRADE=$(grep 'GRADE:'  "$location/$studFolderName/feedback.txt" |  awk -F: '{print $2}' )
	    FEEDBACK=1
	    feedback_string=$(cat "$location/$studFolderName/feedback.txt" )
	fi
	
	upload=""
	findFiles=$(grep FILE "$location/$studFolderName/META.txt" | awk -F: '{print $2}' | awk '{print $1}' )
	for file in $findFiles; do
	    
	    storeTime=$(grep $file "$location/$studFolderName/META.txt" | awk -F: '{print $2}' | awk '{print $2}' )
	    fileSystemTime=$(date -r "$location/$studFolderName/$file" "+%s" )

	    diffTime=$(echo "scale=1;$fileSystemTime-$storeTime"|bc)
	    echo -e "\tfile =$file  >  $fileSystemTime - $storeTime = $diffTime "
	    if [ "$diffTime" -gt "60" ]; then
		upload+="$file "
	    fi
	done


	if [[ "$OVERRIDE" == "1" ]]; then
	    if [[ "$GRADE" == "-1" ]]; then
		echo -e "\tGRADE: $OLDgrade (Keeping $OLDgrade as no new was set). "
		GRADE=$OLDgrade
	    else
		echo -e "\tGRADE: $GRADE (Updating grade from $OLDgrade to $GRADE). "
		
	    fi
	else
	    if [[ "$GRADE" == "-1" ]]; then
		echo -e "\tGrade: NOGRADE (set in feedback file)"
	    else
		echo -e "\tGrade: $GRADE "
	    fi	    
	fi


#	echo -e "\tUpload: $upload"

	if [ "$FEEDBACK" -eq "1" ]; then
	    echo -en "\tPush feedback to Canvas."
	    ##Send feedback
#	    sendFeedback=$(curl -s -H "Authorization: Bearer $TOKEN" -X PUT  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID" -d "comment[text_comment]=$feedback_string" -d "submission[posted_grade]=$GRADE" | jq )
	    sendFeedback=$(curl -s -H "Authorization: Bearer $TOKEN" -X PUT  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID" -d "comment[text_comment]=$feedback_string" | jq | grep comment | grep "$feedback_string" | wc -l )
	    if [ "$sendFeedback" -eq 0 ]; then
		echo "Problems sending feedback (as comment)"
	    else
		echo " OK."
	    fi
	fi

	if [ "$upload" ]; then
	    echo -e "\tPush files ($upload) to Canvas."
	    for fname in $upload; do
		echo -en "\t\t$fname "
		#upload, grab id, attach to submission.
#		echo "curl -s -H \"Authorization: Bearer $TOKEN\" \"https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID/comments/files\" -F \"name=$fname\" | jq "
		ulData=$(curl -s -H "Authorization: Bearer $TOKEN" "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID/comments/files" -F "name=$fname" | jq )

		ulParams=$(echo "$ulData" | jq '{upload_params}[]' | tr -d '{} ' | sed 's/\":\"/=/g' | tr -d '",' | sed '/^$/d')

		#grap uploadURL
		upload_url=$(echo "$ulData" | grep 'upload_url' | awk -F'":' '{print $2}' | tr -d ',"')
#		echo "upload_url=$upload_url"
		#upload file
		ULPARAMSTRING=""
		for FORM in $ulParams; do
		    ULPARAMSTRING+="--form $FORM "
		done
		ULPARAMSTRING+="--form file=@$location/$studFolderName/$fname "
		ULPARAMSTRING+="--form key=/courses/$courseID/assignments/$assignmentID/submissions/$ID/comments/files/$fname "
#		echo "curl $ULPARAMSTRING $upload_url "
		uploadFile=$(curl -s $ULPARAMSTRING $upload_url | jq )


		fileID=$(echo "$uploadFile" | jq '{id}|to_entries|map(.value)|@tsv' | tr -d '"')
		##GRAB id, push as comment.

#		echo "fileID=$fileID"

#		echo "curl -s -H \"Authorization: Bearer $TOKEN\" -X PUT  \"https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID\" -d \"comment[text_comment]=Uploaded File:$fname\" -d \"comment[file_ids]=$fileID\" "
		sendFeedback=$(curl -s -H "Authorization: Bearer $TOKEN" -X PUT  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID" -d "comment[text_comment]=Uploaded File:$fname" -d "comment[file_ids]=$fileID" | jq | grep comment | grep "Uploaded File:$fname" | wc -l)
#		echo "sendFeedback=|$sendFeedback|"
		if [ "$sendFeedback" -eq 0 ]; then
		    echo "Problems sending feedback (as comment)"
		else
		    echo " OK."
		fi		
		
#		echo -e "Got;\n-------$uploadFile\n----------\n"

	    done
	    
	fi


	if [[ "$GRADE" -ne "-1" ]]; then
	    ##PUSH GRADE new or update does not matter.
	    echo -en "\tPush Grade."
	    sendGrade=$(curl -s -H "Authorization: Bearer $TOKEN" -X PUT  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID" -d "submission[posted_grade]=$GRADE" | jq | grep '\"grade\":' | tr -d ', ' | wc -l )
	    if [ "$sendGrade" -eq 0 ]; then
		echo "Problems sending grade. "
	    else
		echo " OK."
	    fi
	fi
	
	
    else
	if [ ! -z "$noSubmission" ]; then 
	    echo  " -- Missing Submission -- "
	fi
	if [ ! -z "$submissionGraded" ]; then
	    echo " -- Already Graded -- "
	fi
    fi
    OLDgrade=""
    OLDgradedat=""
    OLDgraderid=""
    OLDlateSeconds=""
    OLDsubmittedat=""
    

done < <(echo "$emStrip" )


#echo "$emStrip"




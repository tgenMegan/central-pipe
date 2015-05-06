#!/bin/bash

### NOTE: This script is used as a BCL conversion QC check for all run folders in your current working directory
###	     followed by moving any runfolder to the archive folder granted all of the QC checks where passed:
###	QC checks:
###       1. That each Flowcell has completed BCL conversion and that coresponding Fastq files have coppied back to isilon
###       2. That there is data for each lane of a flowcell 
###       3. For Greater than 97% demultiplexed for each lane of a flowcell  
###       4. That any single sample lanes on a flowcell are greater than 250 Million reads

# Setting Variables
HOST_NAME=`hostname`
USER=`whoami`
CURDIR=`pwd`

# Making needed directories
if [ ! -d /scratch/${USER}/badDemultiplexed ]
then
	mkdir /scratch/${USER}/badDemultiplexed
fi
if [ ! -d /scratch/${USER}/lowreadcount ]
then
	mkdir /scratch/${USER}/lowreadcount
fi

# Provide user with the opportunity to exit the script
#echo
#echo -n " PREFLIGHT CHECK: Are you sure you want to perform BCL conversion QC and archive all run folders in your present working directory? If a runfolder does not pass all tests it will not be archived. [Yes/No] "
#read PREFLIGHT_CHECK

# Test to see if the response was correct
#if [[ ${PREFLIGHT_CHECK} = "Yes" || ${PREFLIGHT_CHECK} = "No" ]]
#then
#	echo
#else
#	echo
#	echo " Incorrect Response Option, Please use Yes or No (Case-Sensitive) "
#	echo " The Script will now stop... Please try again. "
#	exit 2
#fi

# Test to see if the user wants to stop the script (ie. they entered "No" as a response to the FINAL CHECK)
#if [ ${PREFLIGHT_CHECK} = "Yes" ]
#then
#	echo
#else
#	echo
#	echo You have entered No for the query... The script will now Stop
#	exit 2
#fi

# For all run folders in the users present working directory (will break in 2020)
for line in `ls -1 ${CURDIR} | awk -F'.' '/^[1]/ { print $1 }' | awk -F'_' 'BEGIN {OFS = "_"} { print $1, $2, $3, $4 }' | sort | uniq`
do

	FCID=`echo $line | awk -F'_' '{ print $4 }' |cut -c2-`
	
	echo
	echo -------------------------------------------------------------------------------
	rm /scratch/${USER}/badDemultiplexed/${line}.txt
	touch /scratch/${USER}/badDemultiplexed/${line}.txt
	rm /scratch/${USER}/lowreadcount/${line}.txt
	touch /scratch/${USER}/lowreadcount/${line}.txt
	echo

######################################################################################
#										     #
#										     #
#				Check Number One				     #
#										     #
#										     #
######################################################################################
 
	echo 1. Checking if flowcell $line has copied to Isilon....

	if [ "`ls /scratch/illumina_run_folders/flowcellInfo/ | grep ${FCID}.saveToIsilonPass | wc -l`" = "1" ]

	then
		echo 1. PASS $line has copied successfully.
		echo

# Copy files needed to use Illumina SAV viewer

        	mkdir /scratch/illumina_run_folders/SAV_RunFolder_files/${line}
        	cp ${CURDIR}/${line}/RunInfo.xml /scratch/illumina_run_folders/SAV_RunFolder_files/${line}/
		cp ${CURDIR}/${line}/runParameters.xml /scratch/illumina_run_folders/SAV_RunFolder_files/${line}/
		cp -r ${CURDIR}/${line}/InterOp/ /scratch/illumina_run_folders/SAV_RunFolder_files/${line}/

######################################################################################
#                                                                                    #
#                                                                                    #
#                               Check Number Two                                     #
#                                                                                    #
#                                                                                    #
######################################################################################

		echo 2. Checking each flowcell lane for data....
	
		if [ "`awk '{ print $1 }' /scratch/mrussell/chiaPipe/runFolders/${line}/${line}.demultiplexStats.txt | sort | uniq | awk '{sum+=$1}END{print sum}'`" = "36" ]
		then
			echo 2. PASS Data has been found for all lanes
			echo

######################################################################################
#                                                                                    #
#                                                                                    #
#                               Check Number Three                                   #
#                                                                                    #
#                                                                                    #
######################################################################################

			echo 3. checking if Percent Demultiplexed for each lane is greater than 97%....   	
			
			for row in `grep Undetermined /scratch/mrussell/chiaPipe/runFolders/${line}/${line}.demultiplexStats.txt | sed 's/ /!/g' |tr '\t' '@'`
			do
				var=`echo $row | awk -F'@' '{ print $11 }' | awk -F'.' '{ print $1 }'`		
				if [[ $var -gt 3 ]]
				then
					echo $row >> /scratch/${USER}/badDemultiplexed/${line}.txt
				fi
			done
		
			if [[ "`cat /scratch/${USER}/badDemultiplexed/${line}.txt |wc -l`" =  "0" ]]
			then 
				echo 3. PASS Percent Demultiplexed is greater than 97% for all lanes
				echo
				
######################################################################################
#                                                                                    #
#                                                                                    #
#                               Check Number Four                                    #
#                                                                                    #
#                                                                                    #
######################################################################################

				echo 4. Checking if there are any single sample lanes with less than 250 Million reads

				for row in `awk 'FNR==NR{a[$1]++;next}(a[$1] == 1)' /scratch/mrussell/chiaPipe/runFolders/${line}/${line}.demultiplexStats.txt /scratch/mrussell/chiaPipe/runFolders/${line}/${line}.demultiplexStats.txt | sed 's/ /!/g' |tr '\t' '@'`
                		do
                        		var2=`echo $row | awk -F'@' '{ print $10 }' |sed 's/,//g'`
                        	
					if [[ $var2 -lt 250000000 ]]
                        		then
                                		echo $row >> /scratch/${USER}/lowreadcount/${line}.txt
                        		fi
                		done
			
				if [[ "`cat /scratch/${USER}/lowreadcount/${line}.txt |wc -l`" = "0" ]]
				then
					echo 4. PASS Any single sample lanes have greater than 250 million reads
					echo

					#if [ ${PREFLIGHT_CHECK} = "Yes" ]
					#then
						echo
						echo --------------------
						echo Moving $line to archive folder
						#unecho me after testing
						echo "mv ${line} /scratch/illumina_run_folders/archive/"
						echo moved .... good
						rm /scratch/${USER}/badDemultiplexed/${line}.txt
						rm /scratch/${USER}/lowreadcount/${line}.txt	
					#else
					#	echo WARNING!!! This should never happen
					#fi
				
				else 
					echo 4. FAIL There is at least one single sample lane on flowcell ${line} with less than 250 Million reads
					echo
					echo '####### Auto run folder archive has Failed ######'	
				fi
			
			else
				echo 3. FAIL Percent Demultiplexed for at least one lane on flowcell ${line} is less than 97%
				echo
				echo '###### Auto run folder archive has Failed ######'
			fi
		
		else
			echo 2. FAIL there is at least one lane on flowcell ${line} with missing data.
			echo
			echo '###### Auto run folder archive has Failed ######'
		fi
		
	else
		if [ "`ls /scratch/illumina_run_folders/flowcellInfo/ | grep ${FCID}.saveToIsilonFail | wc -l`" = "1" ]
		then 
			echo 1a. FAIL Copy fail for flowcell ${line}
			echo
			echo '###### Auto run folder archive has Failed ######'
		
		else
			echo 1b. FAIL ${line} has not copied to Isilon yet.
			echo
			echo '###### Auto run folder archive has Failed #######'	

		fi
	fi

done

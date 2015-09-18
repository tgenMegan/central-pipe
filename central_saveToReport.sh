#!/bin/bash
#####################################################################
# Copyright (c) 2011 by The Translational Genomics Research
# Institute. All rights reserved. This License is limited to, and you may
# use the Software solely for, your own internal and non-commercial use
# for academic and research purposes. Without limiting the foregoing, you
# may not use the Software as part of, or in any way in connection with
# the production, marketing, sale or support of any commercial product or
# service or for any governmental purposes. For commercial or governmental
# use, please contact dcraig@tgen.org. By installing this Software you are
# agreeing to the terms of the LICENSE file distributed with this
# software.
#####################################################################

thisStep="central_nextJob_saveToReport.txt"
nxtStep1="central_nextJob_postSaveToReport.txt"
pbsHome="/home/mrussell/central-pipe/jobScripts"
constants="/home/mrussell/central-pipe/constants/constants.txt"
constantsDir="/home/mrussell/central-pipe/constants"
myName=`basename $0`

hn=`hostname`
time=`date +%d-%m-%Y-%H-%M`
echo "Starting $0 at $time on $hn"

runDir=$1
projName=`basename $runDir`
shortName=`basename $runDir | awk -F'_ps20' '{print $1}'`

findCount=`ps -e | awk '$4=="find"' | wc -l`
if [ $findCount -ge 2 ] ; then
    echo "Too many finds on $hn ($findCount) already, quitting for $projName!!!"
    exit
else
    echo "Find count is low on $hn ($findCount)."
fi

cpCount=`ps -e | awk '$4=="rsync"' | wc -l`
if [ $cpCount -ge 6 ] ; then
    echo "Too many copies on $hn ($cpCount) already, quitting for $projName!!!"
    exit
else
    echo "Copy count is low on $hn ($cpCount)."
fi

if [ "$1" == "" ] ; then
	echo "### Please provide runfolder as the only parameter"
	echo "### Exiting!!!"
	exit
fi
configFile=$runDir/$shortName.config
if [ ! -e $configFile ] ; then
	echo "### Config file not found at $configFile!!!"
	echo "### Exiting!!!"
	exit
else
	echo "### Config file found."
fi

results=`cat $configFile | grep REPORT | cut -d= -f2 | head -1 | tr -d [:space:]`
echo "report: $results"
if [ -z "$results" ] ; then
	echo "###save for report not requested for this project"
	echo "### I should remove $thisStep from $runDir."
	rm -f $runDir/$thisStep
	echo "###Exiting###"
	exit
fi
email=`cat $configFile | grep "^EMAIL=" | cut -d= -f2 | head -1 | tr -d [:space:]`
recipe=`cat $configFile | grep "^RECIPE=" | cut -d= -f2 | head -1 | tr -d [:space:]`
debit=`cat $configFile | grep "^DEBIT=" | cut -d= -f2 | head -1 | tr -d [:space:]`
saveRecipe=`cat $configFile | grep "^REPORTRECIPE=" | cut -d= -f2 | head -1 | tr -d [:space:]`

nCores=`grep @@${myName}_CORES= $constantsDir/$recipe | cut -d= -f2`
ref=`grep "@@"$recipe"@@" $constants | grep @@REF= | cut -d= -f2`

echo "### projName: $projName"
echo "### confFile: $configFile"
d=`echo $runDir | cut -c 2-`

###ADDITION FOR VCF1
dnaLine=`cat $configFile | grep "^DNAPAIR=" | cut -d= -f2 | head -1 | tr -d [:space:]`
study=`echo $dnaLine | cut -d'_' -f1` ## | head -1 | tr -d [:space:]`
sample=`echo $dnaLine | cut -d'_' -f2` ## | head -1 | tr -d [:space:]`

rnaLine=`cat $configFile | grep "^RNAPAIR=" | cut -d= -f2 | head -1 | tr -d [:space:]`
echo "rna Line:: $rnaLine"
rnaCase=`echo $rnaLine | cut -d',' -f2`
rnaTag=`echo $rnaLine | cut -d',' -f3 | head -1 | tr -d [:space:]`
echo "#####  $study   $sample ##################"
echo "Rna  Tag $rnaTag"
####ENDOF ADDITION FOR VCF1
if [ -z "$saveRecipe" ] ; then
	echo "There was not a report save recipe listed for this project"
	echo "Will proceed with the default report save recipe"
	saveRecipe="default"
fi
echo "### Save recipe is $saveRecipe"

if [ "$results" = "" ] ; then
	echo "RESULTS in $runDir bad or not there: $results"
	echo "Exiting!!!"	
	exit
fi
targetDir=$results/$study/$sample
if [ -e $targetDir/reportCopying.txt ] ; then
	echo "### Copy already in progress now..."
	echo "### Exiting!!!"
	rm $runDir/$thisStep
	exit
fi
if [ -e $targetDir/reportCopyDone.txt ] ; then
	echo "### Copy already done."
	echo "Exiting!!!"
	rm $runDir/$thisStep
	exit
fi
if [ -e $targetDir/reportCopyFailed.txt ] ; then
	echo "### Copy already failed."
	echo "Exiting!!!"
	exit
fi
mkdir -p $targetDir
if [ $? -eq 0 ] ; then
	echo "### Target directory is: $targetDir"
else
	echo "### Could not create $targetDir"
	echo "### Exiting!!!"	
	exit
fi
#if project.finished is not there do not start copying
if [ ! -e $runDir/project.finished ] ; then
        echo "$runDir/project.finished does not exist yet"
        time=`date +%d-%m-%Y-%H-%M`
        echo "Ending $0 at $time"
        exit
fi
#if saraStats is not done yet do not start copying
if [ ! -e $runDir/summaryStatsPass ] ; then
        echo "$runDir/summaryStatsPass does not exist yet"
        time=`date +%d-%m-%Y-%H-%M`
        echo "Ending $0 at $time"
        exit
fi

echo "### Copy process started at $time" > $targetDir/reportCopying.txt
echo "### Copy process started at $time" > $targetDir/reportCopyStarted.txt

#saveRecipe=default
echo "### Save recipe is $saveRecipe"
extensions=`cat /home/mrussell/central-pipe/constants/saveReports.txt  | grep "^$saveRecipe=" | cut -d= -f2 | head -1 | tr -d [:space:]`
#extensions=`cat /home/snasser/scripts/pipeline/saveReports.txt  | grep "^$saveRecipe=" | cut -d= -f2 | head -1 | tr -d [:space:]`
echo "### Extensions to copy are $extensions"
fails=0

for extToCopy in `echo $extensions | tr "," "\n"`
do
	echo "### Looking for $extToCopy extension"
	for fileToSave in `find $runDir -name "*$extToCopy"`
	do
		###ADDITION FOR VCF2
		fileName=`basename $fileToSave`
		echo "### File to save is $fileToSave"
		base=""
#		if [[ "$fileName" == *"TSMRU"* && "$fileName" == *"_C"* &&  "$fileName" != *"deseq.vcf"*  &&  "$fileName" != *"cuffdif.vcf"* ]]; then	
		echo "$rnaCase"
		if [[ "$fileName" == *"TSMRU"*  && "$fileName" != *"$rnaCase"* && "$fileName" != *"deseq.vcf"* && "$fileName" != *"cuffdiff.vcf"* ]]; then
			echo "Skipping RNA Control"		
		else
			if [[ "$fileName" == *"HC_All.snpEff.vcf"* ]]; then
				file1=`echo $fileName | cut -d'.' -f1` ## | read file1
				echo "**********  $file1"
				file2=`echo $file1 | cut -d'-' -f1`
		#	elif [[ "$fileName" == *"deseq.vcf"* || "$fileName" == *"cuffdiff.vcf"* ]]; then
		#			file1=`echo $fileName | cut -d'.' -f1` ## | read file1
		#			echo "**************** $file1 "
		#			file2=`echo $file1 | awk -F'-VS-' '{print $2}'`
		#			 echo "**************** $file2 "
		#05/04/2015
			elif [[ "$fileName" == *"$rnaTag"* && "$fileName" == *"cuffdiff.vcf"* ]]; then
                        	#file1=`echo $fileName | cut -d'.' -f1` ## | read file1
				file2=$rnaCase #`echo $file1 | awk -F'-VS-' '{print $2}'`
			elif [[ "$fileName" == *"$rnaTag"* && "$fileName" == *"deseq.vcf"* ]]; then
                                #file1=`echo $fileName | cut -d'.' -f1` ## | read file1
                                 file2=$rnaCase #`echo $file1 | awk -F'-VS-' '{print $2}'`
			elif [[ "$fileName" == *"deseq.vcf"* || "$fileName" == *"cuffdiff.vcf"* ]]; then
#                                        file1=`echo $fileName | cut -d'.' -f1` ## | read file1
#                                        echo "**************** $file1 "
#                                        file2=`echo $file1 | awk -F'-VS-' '{print $2}'`
#                                         echo "**************** $file2 "
					 file2=$rnaCase
		#05/04/2015
			else
				if [[ "$fileName" != *"REVseurat.snpEff.vcf"* ]]; then
					file1=`echo $fileName | cut -d'.' -f1` ## | read file1
					file2=`echo $file1 | cut -d'-' -f2`
				fi	
			fi
			echo "********** $file2"
			###skip study and sample
			pr1=`echo $file2 | cut -d'_' -f3`
			pr2=`echo $file2 | cut -d'_' -f6`
			pr3=`echo $file2 | cut -d'_' -f7`

			echo "******* $pr1 $pr2 $pr3 **********"
			#targetPath="$targetDir/$sample/$pr1/$pr2/$pr3/$base/$fileName";
			targetPath="$targetDir/$pr1/$pr2/$pr3/$base/$fileName";	
			###END OF ADDITION FOR VCF2
			targetBase=`dirname $targetPath`
			#echo "file to copy: $line"
			#echo "base is     : $base"
			#echo "target name : $targetPath"
			#echo "target base : $targetBase"
			if [ ! -d $targetBase ] ; then
				mkdir -p $targetBase
			fi
			if [ ! -e $targetPath ] ; then
				echo "### Copying $fileToSave to $targetPath"
				if [[ "$saveRecipe" == *"SU2C"* || "$saveRecipe" == *"PNOC"* ]] && [[ "$fileToSave" == *"merged.canonicalOnly.rna.final.vcf"* ]]; then
                                	file3=`echo $fileName | cut -d'.' -f1`
                                	seuratFromMerged="$file3.merged.canonicalOnly.rna.final.seurat.vcf";
                                	echo "********* Seurat Only File from Merged $seuratFromMerged ****************"
					grep "^#\|SEURAT" $fileToSave > $targetBase/$seuratFromMerged
				else
					rsync -tlu $fileToSave $targetPath
				fi
				if [ $? -ne 0 ] ; then
					echo "### Failed to copy to $targetPath"
					rm -f $targetPath
					fail=1
				fi
			else
				echo "### Already exists: $targetPath/$fileName"
			fi
		fi
	done
done

rm -f $targetDir/reportCopying.txt

if [ $fails -eq 0 ] ; then
	echo "### Copy process finished successfully!"
	echo "### Copy process finished at $time" > $targetDir/reportCopyDone.txt
	if [  -e $runDir/saveReportEmail.sent ] ; then
		echo "Email already sent for $runDir"
	else	
		echo "Your project $projName has been saved to the reports directory" >> ~/mailtmp-$$.txt
		cat ~/mailtmp-$$.txt | mail -s "central pipeline: your project $projName was saved to reports" "$email"
		cat ~/mailtmp-$$.txt | mail -s "central pipeline: your project $projName was saved to reports" "mrussell@tgen.org"
		mv ~/mailtmp-$$.txt $runDir/saveReportEmail.sent
		echo "### Mail sent and saved to $runDir/saveReportEmail.sent"
	fi
	echo "### I should remove $thisStep from $runDir."
	rm $runDir/$thisStep
else
	echo "Copy process failed!"
	echo "Copy process failed at $time" > $targetDir/reportCopyFailed.txt
fi
time=`date +%d-%m-%Y-%H-%M`
echo "Ending $0 at $time on $hn"

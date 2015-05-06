#!/bin/bash
#####################################################################
# Copyright (c) 2011 by The Translational Genomics Research
# Institute Ahmet Kurdoglu. All rights reserved. This License is limited 
# to, and you may use the Software solely for, your own internal and i
# non-commercial use for academic and research purposes. Without limiting 
# the foregoing, you may not use the Software as part of, or in any way 
# in connection with the production, marketing, sale or support of any 
# commercial product or service or for any governmental purposes. For 
# commercial or governmental use, please contact dcraig@tgen.org. By 
# installing this Software you are agreeing to the terms of the LICENSE 
# file distributed with this software.
#####################################################################
source ~/.bashrc
time=`date +%d-%m-%Y-%H-%M`
echo "Starting $0 at $time"
scriptsHome="/home/mrussell/pecan-pipe"
logs="/scratch/mrussell/pecanPipe/logs"
kbaseDropbox="/scratch/illumina_run_folders/pecanPipe/"
pecanDropbox="/scratch/mrussell/pecanPipe/collectFQdropBox/"
centralDropbox="/scratch/mrussell/centralPipe/collectFQdropBox/"
familyDropbox="/scratch/illumina_run_folders/familyPipe/"

for fqList in `find ${kbaseDropbox} -name *FastqList.csv`
do #for all of the files in kbase dropbox area
        runPar=${fqList/FastqList.csv/RunParameters.csv}
        if [ ! -e $runPar ] ; then
                echo "RunParameters.csv file doesn't exist"
                echo "Exiting..."
                exit
        fi
        echo "### fqList file is $fqList"
        echo "### runPar file is $runPar"

	pipeline=`cat $runPar | cut -d, -f14`
	temp=`echo $pipeline | sed "s/\"//g"`
	echo "pipeline is: $temp"
	if [[ $temp == Medusa* ]] ; then
                mv $fqList $centralDropbox
                mv $runPar $centralDropbox
                echo "moved $fqList and $runPar to $centralDropbox"
	elif    [[ $temp == Pegasus* ]] ; then
                mv $fqList $centralDropbox
                mv $runPar $centralDropbox
                echo "moved $fqList and $runPar to $centralDropbox"
        else
		mv $fqList $pecanDropbox
		mv $runPar $pecanDropbox
		echo "moved $fqList and $runPar to $pecanDropbox"
	fi
done
for fqList in `find ${familyDropbox} -name *FastqList.csv`
do #for all of the files in family dropbox area
        runPar=${fqList/FastqList.csv/RunParameters.csv}
        pedFile=${fqList/FastqList.csv/PEDvalues.tsv}
	if [ ! -e $runPar ] ; then
                echo "RunParameters.csv file doesn't exist"
                echo "Exiting..."
                exit
        fi
        if [ ! -e $pedFile ] ; then
                echo "PEDvalues.tsv file doesn't exist"
                echo "Exiting..."
                exit
        fi
        echo "### fqList file is $fqList"
        echo "### runPar file is $runPar"
	echo "### pedFle file is $pedFile"
	mv $fqList $centralDropbox
	mv $runPar $centralDropbox
	mv $pedFile $centralDropbox
	echo "moved $fqList and $runPar and $pedFile to $centralDropbox"
done

#if [ "$(ls -A /scratch/illumina_run_folders/pecanPipe/)" ] ; then
#	
#	echo "The directory contains pipeline files"
#	echo "Moving pipeline files from: /scratch/illumina_run_folders/pecanPipe/ to /scratch/mrussell/pecanPipe/collectFQdropBox/"
	#need to uncomment to start under my username
#	mv /scratch/illumina_run_folders/pecanPipe/* /scratch/mrussell/pecanPipe/collectFQdropBox/

#else
#	echo "The directory was empty"
#fi
echo "**********DONE************"

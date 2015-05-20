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
scriptsHome="/home/mrussell/central-pipe"
logs="/scratch/mrussell/centralPipe/logs"
topProjDir="/scratch/mrussell/centralPipe/projects"
myhostname=`hostname`
CA="/scratch/mrussell/centralPipe/conversionArea"
FCA="/scratch/mrussell/centralPipe/familyConversionArea"
        
echo "### ~~Running on $myhostname~~"

echo "### Sending validate config into dropBox..."
$scriptsHome/central_validateConfig.sh >> $logs/central_validateConfigLOG.txt 2>&1
echo "### End of validate config checking out dropBox..."

echo "### Sending validate config into dropBox..."
$scriptsHome/central_validateConfigPegFamily.sh >> $logs/central_validateFamilyConfigLOG.txt 2>&1
echo "### End of validate config checking out dropBox..."

echo "### Sending prepDirs into dbGood..."
$scriptsHome/central_prepDirs.sh >> $logs/central_prepDirsLOG.txt 2>&1
echo "### End of prepDir checking out dbGood..."

echo "### Sending makeConfig into conversion area..."

#$scriptsHome/central_makeConfigPegasus.sh >> $logs/central_makeConfigLOG.txt 2>&1

for fqList in `find ${FCA} -name *FastqList.csv`
do
	runPar=${fqList/FastqList.csv/RunParameters.csv}
        if [ ! -e $runPar ] ; then
                echo "RunParameters.csv file doesn't exist"
                continue
        else
		$scriptsHome/central_makeConfigPegFamily.sh >> $logs/central_makeConfigFAMLOG.txt 2>&1
	fi
	

done

for fqList in `find ${CA} -name *FastqList.csv`
do #for all of the files in conversion area
	runPar=${fqList/FastqList.csv/RunParameters.csv}
        if [ ! -e $runPar ] ; then
                echo "RunParameters.csv file doesn't exist"
                continue
        fi
	pipeline=`cat $runPar | cut -d, -f14`
	temp=`echo $pipeline | sed "s/\"//g"`
	echo "pipeline is: $temp"

	if [[ $temp == Medusa* ]] ; then
		$scriptsHome/central_makeConfigMedusa.sh >> $logs/central_makeConfigLOG.txt 2>&1
	elif [[ $temp == Pegasus* ]] ; then
		$scriptsHome/central_makeConfigPegasus.sh >> $logs/central_makeConfigLOG.txt 2>&1
	else
		echo "The pipeline was not Medusa or Pegasus it was: $temp in $runPar"
	fi

	echo "### End of makeConfig checking conversion area..."
done

echo "**********DONE************"

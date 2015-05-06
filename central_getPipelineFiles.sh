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

if [ "$(ls -A /scratch/illumina_run_folders/pecanPipe/)" ] ; then
	echo "The directory contains pipeline files"
	echo "Moving pipeline files from: /scratch/illumina_run_folders/pecanPipe/ to /scratch/mrussell/centralPipe/collectFQdropBox/"
	#need to uncomment to start under my username
	mv /scratch/illumina_run_folders/pecanPipe/* /scratch/mrussell/centralPipe/collectFQdropBox/

else
	echo "The directory was empty"
fi
echo "**********DONE************"

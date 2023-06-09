#!/bin/bash

function get_dsi_result()
{
	starttime=$(date +%s)
	while true
	do
		endtime=$(date +%s)
		runtime=$(($endtime-$starttime))
		if [ $runtime -gt 6 ]
		then
			echo -ne "\n"
			break
		fi
	done
}

echo "******************4-lane MIPI testing..."

echo "get_dsi_result | modetest -M starfive -D 0 -a -s 118@35:800x1280 -P 74@35:800x1280@RG16 -Ftiles"
get_dsi_result | modetest -M starfive -D 0 -a -s 118@35:800x1280 -P 74@35:800x1280@RG16 -Ftiles

read -ep "please enter 4-lane MIPI TEST OK(y/n?): " test_result

if [[ "$test_result" == "y" ]]
then
	echo "4-lane MIPI   PASS"
	echo "4-lane MIPI:    PASS" >> test_result.log
else
	echo "4-lane MIPI   FAIL"
	echo "4-lane MIPI:    FAIL" >> test_result.log
fi


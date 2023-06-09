#!/bin/bash

function readINI()
{
 FILENAME=$1; SECTION=$2; KEY=$3
 RESULT=`awk -F '=' '/\['$SECTION'\]/{a=1}a==1&&$1~/'$KEY'/{print $2;exit}' $FILENAME`
 echo $RESULT
}

cfg_name=cfg.ini
cfg_section=GMAC1
failcnt=0
log_suffix=".log"
log_file=$cfg_section$log_suffix
#echo $log_file
if [ -f $log_file ]
then
	rm $log_file
fi

starttime=$(date +%s)

str_boardip=$(readINI $cfg_name $cfg_section boardip)
board_ip=$(echo $str_boardip | sed 's/\r//')
#echo $board_ip

str_vmip=$(readINI $cfg_name $cfg_section vmip)
vm_ip=$(echo $str_vmip | sed 's/\r//')
#echo $vm_ip

str_baud=$(readINI $cfg_name $cfg_section baud)
sbaud=$(echo $str_baud | sed 's/\r//')
#echo $sbaud

str_expectbaudtcp=$(readINI $cfg_name $cfg_section expectbaudtcp)
expect_baudtcp=$(echo $str_expectbaudtcp | sed 's/\r//')
#echo $expect_baudtcp

echo "******************ETH1 PING testing..."
#ifconfig eth0 down
ifconfig eth1 $board_ip netmask 255.255.255.0
ping_over=0
echo "ping $vm_ip -w 5 -I eth1"
ping $vm_ip -w 5 -I eth1 2>&1 | tee $log_file

while read line
do
	result=$(echo $line | grep "time=")
	if [[ "$result" != "" ]]
	then
		ping_over=1
		echo "ping_over: $ping_over"
		break
	fi
done < $log_file

pss_reg=$(phytool read eth1/0/0x11)
echo "PHY1 Specific Status: $pss_reg"
let "speedmode=pss_reg&0xc000"
let "speedmode=speedmode>>14"
echo "PHY1 speedmode: $speedmode"
if [[ $speedmode == 0 ]]
then
	speed_mode=10M
elif [[ $speedmode == 1 ]]
then
	speed_mode=100M
elif [[ $speedmode == 2 ]]
then
	speed_mode=1000M
else
	speed_mode=reserved
fi
echo "PHY1 speed_mode: $speed_mode"

let "linkstatus=pss_reg&0x0400"
let "linkstatus=linkstatus>>10"
echo "PHY1 linkstatus: $linkstatus"

pcb_version=$(sed -n '1p' PCB.log)
if [[ $pcb_version == "A" ]]
then
	exp_speedmode=1
else
	exp_speedmode=2
fi
echo "exp_speedmode: $exp_speedmode"

if [[ $ping_over != 0 ]] && [[ $speedmode == $exp_speedmode ]] && [[ $linkstatus == 1 ]]
then
	echo "ETH1 PING PASS"
	echo "ETH1 PING:      PASS $speed_mode" >> test_result.log
	echo "PASS $speed_mode" > $log_file
else
	echo "ETH1 PING FAIL"
	echo "ETH1 PING:      FAIL $speed_mode" >> test_result.log
	echo "PING FAIL $speed_mode" > $log_file
fi

endtime=$(date +%s)
runtime=$(($endtime-$starttime))
runtime=$(echo "$runtime*1000" | bc)
echo "$cfg_section running time: $runtime ms"
echo $runtime >> $log_file


if false
then
	echo "******************ETH1 TCP TX testing..."
	iperf3 -c $vm_ip -b $sbaud -t 5 -B $board_ip 2>&1 | tee ethernet_test.log

	str=$(sed -n '11p' ethernet_test.log)
	#echo "string: $str"
	index=`expr index "$str" /`
	#echo "index: $index"
	txspeed=${str:$index-12:6}
	#echo "txspeed: $txspeed"
	tx_speed=${str:$index-12:17}
	echo "tx speed: $tx_speed"

	result=$(echo $txspeed $expect_baudtcp | awk '{if($1>$2) {printf 1} else {printf 0}}')
	Mbits=`expr index "$str" M`
	if [[ $result = 1 ]] && [[ $index != 0 ]] && [ $Mbits -gt 0 ]
	then
		echo "ETH1 TCP TX SPEED PASS"
		echo "ETH1 TX:        PASS  tx speed: $tx_speed" >> test_result.log
	else
		echo "ETH1 TCP TX SPEED FAIL"
		echo "ETH1 TX:        FAIL  tx speed: $tx_speed" >> test_result.log
	fi

	echo "******************ETH1 TCP RX testing..."
	iperf3 -c $vm_ip -b $sbaud -t 5 -R -B $board_ip 2>&1 | tee ethernet_test.log

	str=$(sed -n '13p' ethernet_test.log)
	#echo "string: $str"
	index=`expr index "$str" /`
	#echo "index: $index"
	rxspeed=${str:$index-12:6}
	#echo "rxspeed: $rxspeed"
	rx_speed=${str:$index-12:17}
	echo "rx speed: $rx_speed"

	result=$(echo $rxspeed $expect_baudtcp | awk '{if($1>$2) {printf 1} else {printf 0}}')
	#echo "result=$result"
	Mbits=`expr index "$str" M`
	if [[ $result = 1 ]] && [[ $index != 0 ]] && [ $Mbits -gt 0 ]
	then
		echo "ETH1 TCP RX SPEED PASS"
		echo "ETH1 RX:        PASS  rx speed: $rx_speed" >> test_result.log
	else
		echo "ETH1 TCP RX SPEED FAIL"
		echo "ETH1 RX:        FAIL  rx speed: $rx_speed" >> test_result.log
	fi
fi


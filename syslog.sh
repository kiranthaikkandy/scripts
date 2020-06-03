#!/bin/bash
#########Function Definitions & Variable ##########
#TARGET="/home/$(whoami)/$(hostname)"
TARGET="/tmp/patchlogs/$(hostname)"
PRELOG="$TARGET/`hostname`-precheck"
POSTLOG="$TARGET/`hostname`-postcheck"
PATH=$PATH:/bin:/usr:/usr/bin:/sbin:/usr/sbin
if [ ! -d $TARGET ]
then
mkdir -p $TARGET
#else
#exit 1
fi

function PreCheck_log () {
if [ -f $PRELOG ]
then
mv $PRELOG $PRELOG.old
fi
}
function PostCheck_log () {
if [ -f $POSTLOG ]
then
mv $POSTLOG $POSTLOG.old
fi
}

function CheckOS () {
OS=`uname -a | cut -d " " -f 1`
if [ $OS != Linux ]
then
echo " Not Linux Os"
exit 1
fi
}
function CleanUP () {
echo "-------------------------------------------------------------------------------"
echo "                          File system Clean up needed                             "
echo "-------------------------------------------------------------------------------"
CLEANUP=`df -hlP |column -t | egrep "[7-9][0-9]%|[00]%" | wc -l`
if [ $CLEANUP -ne 0 ]
then
echo "Below Listed File system Clean Up Needed "
df -hlP |column -t | grep --color [7-9][0-9]%
fi
}
function Log () {
#PRELOG="$TARGET/`hostname`-precheck-`date +%Y%m%d`"
tee -a $PRELOG
}

function PostLog () {
#POSTLOG="$TARGET/`hostname`-postcheck-`date +%Y%m%d`"
tee -a $POSTLOG
}

function SrvInfo () {
echo "--------------------------System Info-----------------------------------------"
printf '%s\n' "DATE                   : `date`"
echo -e "HOSTNAME               : `hostname`"
echo "OS Version                : `cat /etc/redhat-release | cut -d " " -f1-5,7`"
echo "KERNEL Release            : `uname -r`"
echo "Hardware Platform         : `uname -i`"
echo "Memory (KB)               : `cat /proc/meminfo  | grep -i MemTotal | awk  '{print $2}'`"
echo "CPU (Count)               : `grep processor /proc/cpuinfo | wc -l`"
echo "------------------------------------------------------------------------------"
echo "                          File system Detail                                  "
echo "------------------------------------------------------------------------------"
df -hP | column -t
df -hP | wc -l
echo "----------------------------------------------------------------------------------"
mount
mount | column -t |wc -l
echo "----------------------------------------------------------------------------------"
echo "                          Storage Information                                     "
echo "----------------------------------------------------------------------------------"
pvs
echo "----------------------------------------------------------------------------------"
vgs -a -o +devices
echo "----------------------------------------------------------------------------------"
lvs -a -o +devices
echo "----------------------------------------------------------------------------------"
echo "                          `hostname` Network Detail                               "
echo "----------------------------------------------------------------------------------"
NICSINFO=`ifconfig -a | egrep "HWaddr"`
echo "`hostname` NIC information"
printf '%s\n' "$NICSINFO"
#${NICSINFO}
echo "-------------------------------------------------------------------------------"
echo "IP address detail"
ip addr show
echo "-------------------------------------------------------------------------------"
echo "`hostname` Routing Information "
netstat -rn
echo "-------------------------------------------------------------------------------"
INTERFACE=`ifconfig -a | grep -i hw | grep -v ^b | cut -d " " -f1`
ETHTOOL=`for i in $INTERFACE; do ethtool $i | awk /Settings/{'print $3'}/Speed/{'print $1 $2'}/Duplex/{'print $1 $2'}/Link/{'print $1 "\t" $3'}| paste -s; done`
echo "Ethtool Setting for "${INTERFACE}""
echo "${ETHTOOL}"
echo "--------------------------------------------------------------------------------"
echo "Network Bonding detail"
if [ ! -d /proc/net/bonding ]
then
echo "Network bonding is not configured on `hostname` "
else
/sbin/ifconfig -a | grep -w inet
cd /proc/net/bonding
for i in `ls`; do  echo $i; cat $i |grep -E "Bonding Mode|Currently|Slave"; done
fi
}

function Check_Cluster () {
echo "------------------------------------------------------------------------------"
echo "                          Cluster Status                                          "
echo "------------------------------------------------------------------------------"
CLUSTER="/usr/sbin/clustat"
CLUSFILE="/etc/cluster/cluster.conf"
if [ ! -f $CLUSTER ] || [ ! -f $CLUSFILE ]
then
echo "Cluster service is not running on `hostname`"
else
clustat
fi
}

function Check_Asm () {
echo "------------------------------------------------------------------------------"
echo "                          OracleASM disk Detail                                   "
echo "------------------------------------------------------------------------------"
ASM=/etc/init.d/oracleasm
ASMDISK=`ls /dev/oracleasm/disks 2>&1`
if [ -f $ASM ]
then
echo "List of oracleasm Disks"
/etc/init.d/oracleasm listdisks
for i in $ASMDISK
do
sudo /opt/marrtools/bin/pseudo2mpath /dev/oracleasm/disks/$i
done
else
echo "Oracle ASM is not configured on `hostname`"
fi
}

function Check_Hba () {
echo "------------------------------------------------------------------------------"
echo "                          HBA card Detail                                         "
echo "------------------------------------------------------------------------------"
if [ -f /usr/sbin/hbanyware/hbacmd ]
then
/usr/sbin/hbanyware/hbacmd listhbas
echo "------------------------------------------------------------------------------"
echo "                          HBA Serial and FW Version                               "
echo "------------------------------------------------------------------------------"
for i in `sudo /usr/sbin/hbanyware/hbacmd listhbas | grep "Port WWN" | awk '{print $4}'`; do echo $i;sudo /usr/sbin/hbanyware/hbacmd hbaattribute $i| awk '/Serial Numbe
r/{print $1 $2 "\t"$3 $4}/FW Version/{print $1 $2 "\t" $3 $4 $5}';done
echo "------------------------------------------------------------------------------"
echo "                          HBA Status                                              "
echo "------------------------------------------------------------------------------"
cat /sys/class/fc_host/*/port_state
fi
}

function Check_Mcelog () {
MCELOG="/var/log/mcelog"
if [ -e $MCELOG ] && [ -s $MCELOG ];
then
echo "------------------------------------------------------------------------------"
echo "                          Checking MCE Log                                        "
echo "------------------------------------------------------------------------------"
echo "Please clear the mcelog before processing with patching                           "
fi
}
function Conf_backup () {
#cp /etc/multipath_bindings $TARGET/multipath_bindings.`date +%F`
#cp /etc/mtab $TARGET/mtab-precheck
#cp /etc/fstab $TAREGT/fstab-precheck
tar -czvf $TARGET/`hostname`-`date +%F`.tar.gz /etc/ --exclude=/etc/selinux >/dev/null 2>&1
#FILELIST="/etc/multipath_bindings /etc/mtab  /etc/fstab /etc/cluster.conf /etc/multipath/wwid /etc/multipath/bindings"
#for i in $FILELIST; do sudo cp -np $i $TARGET 2>/dev/null;done
}

function XML_backup () {
if [ -e /usr/bin/virsh ]
then
SRV_LIST=`sudo virsh list | egrep "ln|lx" | awk '{print $2}'`
echo "--------------------------------------------------------------------------------------"
echo "                          Genrating Xml Backup                                            "
echo "--------------------------------------------------------------------------------------"
for i in $SRV_LIST; do echo "$i Xml Ganrated"; virsh dumpxml $i >$TARGET/$i-prepatch;done
fi
}
######################################################################################################################################
if [ $# -lt 1 ]
then
echo "Usage :$0 {precheck|postcheck|compare|backup} "
fi
CheckOS
case "$1" in
'precheck' )
PreCheck_log
SrvInfo | Log
Check_Cluster | Log
Check_Asm | Log
Check_Hba | Log
CleanUP
Check_Mcelog | Log
XML_backup
Conf_backup
echo "Logs are written to "${PRELOG}" "
cat ${PRELOG}| mailx -s "`hostname` precheck on `date +%F`"  IO.NADC.TechServices.Unix.Bangalore@accenture.com
;;
'postcheck' )
PostCheck_log
SrvInfo | PostLog
Check_Cluster | PostLog
Check_Asm | PostLog
Check_Hba |PostLog
#CleanUP | PostLog
Check_Mcelog |PostLog
echo "Log are writen to ${POSTLOG} "
;;
'compare' )
sdiff -s ${PRELOG} ${POSTLOG}
;;

'backup' )
Conf_backup
;;
*) echo "Invalid Input"
;;
esac

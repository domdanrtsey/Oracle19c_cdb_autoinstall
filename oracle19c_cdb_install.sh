#!/bin/bash
#script_name: oracle19c_cdb_install.sh
#Author: Danrtsey.Shun
#Email:mydefiniteaim@126.com
#auto_install_oracle19c version=12.2.0.3
####################  Steup 1 Install oracle software ####################
# attentions1:
# 1.上传19c软件安装包至随意路径下,脚本提示路径是 /opt
#
# LINUX.X64_193000_db_home.zip
#
# 2.预设oracle用户的密码为 Danrtsey.com 请根据需要修改
#####################################
#ORACLE_OS_PWD=                     #
#if [ "$ORACLE_OS_PWD" = "" ]; then #
#    ORACLE_OS_PWD="Danrtsey.com"   #
#fi                                 #
#####################################
# 3.选择数据库字符集与国家字符集
# CharacterSet: ZHS16GBK or AL32UTF8
# NationalCharacterSet: AL16UTF16 or UTF8
# 4.执行
# chmod + oracle19c_cdb_install.sh
# sh -x oracle19c_cdb_install.sh
#
#################### Steup 2 Install oracle listener & dbca  ####################
# attentions2:
########################################
# 1.according to the different environment to set the processes && sessions value
# alter system set processes=1000 scope=spfile;
# alter system set sessions=1522 scope=spfile;
########################################

export PATH=$PATH
#Source function library.
. /etc/init.d/functions

#Require root to run this script.
uid=`id | cut -d\( -f1 | cut -d= -f2`
if [ $uid -ne 0 ];then
  action "Please run this script as root." /bin/false
  exit 1
fi

##set oracle password
ORACLE_OS_PWD=
if [ "$ORACLE_OS_PWD" = "" ]; then
    ORACLE_OS_PWD="Danrtsey.com"
fi

###install require packages
echo -e "\033[34mInstallNotice >>\033[0m \033[32moracle install dependency \033[05m...\033[0m"
yum -y install epel-release
cp /etc/yum.repos.d/epel.repo /etc/yum.repos.d/epel.repo.bak
cp /etc/yum.repos.d/epel-testing.repo /etc/yum.repos.d/epel-testing.repo.bak
sed -e 's!^metalink=!#metalink=!g' \
    -e 's!^#baseurl=!baseurl=!g' \
    -e 's!//download\.fedoraproject\.org/pub!//mirrors.tuna.tsinghua.edu.cn!g' \
    -e 's!http://mirrors\.tuna!https://mirrors.tuna!g' \
    -i /etc/yum.repos.d/epel.repo /etc/yum.repos.d/epel-testing.repo
yum makecache fast

yum -y install gcc gcc-c++ make binutils compat-libstdc++-33 elfutils-libelf elfutils-libelf-devel glibc glibc-common \
  glibc-devel libaio libaio-devel libgcc libstdc++ libstdc++-devel unixODBC unixODBC-devel elfutils-libelf-devel-static \
  numactl-devel sysstat pcre-devel readline compat-libcap1 libXi libXtst libxcb ksh \
  zip unzip tree vim lrzsz net-tools wget ntpdate ntp
if [[ $? == 0 ]];then
  echo -e "\033[34mInstallNotice >>\033[0m \033[32myum install dependency successed\033[0m"
else
  echo -e "\033[34mInstallNotice >>\033[0m \033[32myum install dependency faild, pls check your network\033[0m"
  exit
fi

###set firewalld & optimize the os system & set selinux
echo "################# Optimize system parameters  ##########################"
firewall_status=`systemctl status firewalld | grep Active |awk '{print $3}'`
if [ ${firewall_status} == "(running)" ];then
  firewall-cmd --permanent --zone=public --add-port=1521/tcp && firewall-cmd --reload
else
  systemctl start firewalld
  firewall-cmd --permanent --zone=public --add-port=1521/tcp && firewall-cmd --reload
fi

SELINUX=`cat /etc/selinux/config |grep ^SELINUX=|awk -F '=' '{print $2}'`
if [ ${SELINUX} == "enforcing" ];then
  sed -i "s@SELINUX=enforcing@SELINUX=disabled@g" /etc/selinux/config
else
  if [ ${SELINUX} == "permissive" ];then
    sed -i "s@SELINUX=permissive@SELINUX=disabled@g" /etc/selinux/config
  fi
fi
setenforce 0

echo "================更改为中文字符集================="
  \cp /etc/locale.conf  /etc/locale.conf.$(date +%F)
cat >>/etc/locale.conf<<EOF
LANG="zh_CN.UTF-8"
#LANG="en_US.UTF-8"
EOF
source /etc/locale.conf
grep LANG /etc/locale.conf
action "更改字符集zh_CN.UTF-8完成" /bin/true
echo "================================================="
echo ""

###set the ip in hosts
echo "############################   Ip&Hosts Configuration  #######################################"
hostname=`hostname`
HostIP=`ip a|grep 'inet '|grep -v '127.0.0.1'|awk '{print $2}'|awk -F '/' '{print $1}'`
for i in ${HostIP}
do
    A=`grep "${i}" /etc/hosts`
    if [ ! -n "${A}" ];then
        echo "${i} ${hostname}" >> /etc/hosts 
    else
        break
    fi
done

###create group&user
echo "############################   Create Group&User  #######################################"
ora_user=oracle
ora_group=('oinstall' 'dba' 'oper')
for i in ${ora_group[@]}
do
    B=`grep '${i}' /etc/group`
    if [ ! -n ${B} ];then
        groupdel ${i} && groupadd ${i}
    else    
        groupadd ${i}
    fi
done
C=`grep 'oracle' /etc/passwd`
if [ ! -n ${C} ];then
    userdel -r ${ora_user} && useradd -u 501 -g ${ora_group[0]} -G ${ora_group[1]},${ora_group[2]} ${ora_user}
else
    useradd -u 501 -g ${ora_group[0]} -G ${ora_group[1]},${ora_group[2]} ${ora_user}
fi
echo "${ORACLE_OS_PWD}" | passwd --stdin ${ora_user}

###create directory and grant priv
echo "############################ Create DIR & set privileges & set OracleSid ##################"
echo "############################   Create OracleBaseDi #######################################"
echo "############################   Create OracleHomeDir #######################################"
count=0
while [ $count -lt 3 ]
do
    read -p "Please input the ORACLE_SID(e.g:orcl):" S1
    read -p "Please input the ORACLE_SID again(orcl):" S2
    if [ "${S1}" == "${S2}" ];then
        export ORACLE_SID=${S1}
        break
    else
        echo "You input ORACLE_SID not same."
        count=$[${count}+1]
    fi
done
count=0
while [ $count -lt 3 ]
do
        read -p "Please input the ORACLE_BASE(e.g:/u01/oracle):" S1
        read -p "Please input the ORACLE_BASE again(/u01/oracle):" S2
        if [ "${S1}" == "${S2}" ];then
                export ORACLE_BASE=${S1}
                break
        else    
                echo "You input ORACLE_BASE not same."
                count=$[${count}+1]
        fi 
done
count=0
while [ $count -lt 3 ]
do
        read -p "Please input the ORACLE_HOME(e.g:/u01/oracle/product/19c/dbhome_1):" S1
        read -p "Please input the ORACLE_HOME again(/u01/oracle/product/19c/dbhome_1):" S2
        if [ "${S1}" == "${S2}" ];then
                export ORACLE_HOME=${S1}
                break
        else        
                echo "You input ORACLE_HOME not same."
                count=$[${count}+1]
        fi      
done
if [ ! -d ${ORACLE_HOME} ];then
    mkdir -p ${ORACLE_HOME}
fi
if [ ! -d ${ORACLE_BASE}/data ];then
    mkdir -p ${ORACLE_BASE}/data
fi
if [ ! -d ${ORACLE_BASE}/recovery ];then
    mkdir -p ${ORACLE_BASE}/recovery
fi
ora_dir=`echo ${ORACLE_BASE}|awk -F '/' '{print $2}'`
if [ ! -d /${ora_dir}/install ];then
    mkdir -p /${ora_dir}/install
fi
if [ ! -d /${ora_dir}/assistants ];then
    mkdir -p /${ora_dir}/assistants
fi

###set the sysctl,limits and profile
echo "############################   Configure environment variables #######################################"
D=`grep 'fs.aio-max-nr' /etc/sysctl.conf`
if [ ! -n "${D}" ];then
cat << EOF >> /etc/sysctl.conf
kernel.shmmax = 68719476736
kernel.shmmni = 4096
kernel.shmall = 16777216
kernel.sem = 1010 129280 1010 128
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 4194304
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576
fs.aio-max-nr = 1048576
fs.file-max = 6815744
EOF
/sbin/sysctl -p
fi
E=`grep 'oracle' /etc/security/limits.conf`
if [ ! -n "${E}" ];then
cat << EOF >> /etc/security/limits.conf
oracle soft nproc 16384
oracle hard nproc 16384
oracle soft nofile 65536
oracle hard nofile 65536
oracle soft memlock 4000000
oracle hard memlock 4000000
EOF
fi
F=`grep 'ORACLE_SID' /home/${ora_user}/.bash_profile`
if [ ! -n "${F}" ];then
cat << EOF >> /home/${ora_user}/.bash_profile
export ORACLE_SID=${ORACLE_SID}
export ORACLE_BASE=${ORACLE_BASE}
export ORACLE_HOME=${ORACLE_HOME}
export PATH=\$PATH:\$ORACLE_HOME/bin
export NLS_LANG="AMERICAN_CHINA.ZHS16GBK"
EOF
fi
sed -i "/pam_namespace.so/a\session    required     pam_limits.so" /etc/pam.d/login
G=`grep 'oracle' /etc/profile`
if [ ! -n "${G}" ];then
cat << EOF >> /etc/profile
if [ \$USER = "oracle" ];then
    if [ \$SHELL = "/bin/ksh" ];then
        ulimit -p 16384
        ulimit -n 65536
    else
        ulimit -u 16384 -n 65536
    fi
fi
EOF
fi

###unzip the install package and set response file
echo "############################   unzip the install package  #######################################"
count=0
while [ $count -lt 3 ]
do
    read -p "Please input the zip file location(e.g:/opt/LINUX.X64_193000_db_home.zip):" zfile
    if [ ! -f ${zfile} ];then
        echo "You input location not found zip file."
        count=$[${count}+1]
    else
        export zfile=${zfile}
        break
    fi
done

unzip ${zfile} -d $ORACLE_HOME && chown -R ${ora_user}:${ora_group[0]}  /${ora_dir}

###set Oracle characterSet
echo "############################   set characterSet  #######################################"
count=0
while [ $count -lt 3 ]
do
        read -p "Please input the CharacterSet(e.g:ZHS16GBK or AL32UTF8):" C1
        read -p "Please input the CharacterSet again(ZHS16GBK or AL32UTF8):" C2
        if [ "${C1}" == "${C2}" ];then
                export CharacterSet=${C1}
                break
        else        
                echo "You input characterSet not same."
                count=$[${count}+1]
        fi      
done

###set Oracle nationalCharacterSet
echo "############################   set nationalCharacterSet  #######################################"
count=0
while [ $count -lt 3 ]
do
        read -p "Please input the NationalCharacterSet(e.g:AL16UTF16 or UTF8):" N1
        read -p "Please input the NationalCharacterSet again(AL16UTF16 or UTF8):" N2
        if [ "${N1}" == "${N2}" ];then
                export NationalCharacterSet=${N1}
                break
        else        
                echo "You input nationalCharacterSet not same."
                count=$[${count}+1]
        fi      
done

###set Oracle install.db.starterdb installSysPassword
echo "############################   set installSysPassword  #######################################"
count=0
while [ $count -lt 3 ]
do
        read -p "Please input the installSysPassword(e.g:SysOracle2021):" S1
        read -p "Please input the installSysPassword again(SysOracle2021):" S2
        if [ "${S1}" == "${S2}" ];then
                export installSysPassword=${S1}
                break
        else        
                echo "You input installSysPassword not same."
                count=$[${count}+1]
        fi      
done

###set Response File
echo "############################   set ResponseFile  #######################################"
db_response_file=`find ${ORACLE_HOME}/install -type f -name db_install.rsp`
cd `find ${ORACLE_HOME}/install -type f -name db_install.rsp | sed -n 's:/[^/]*$::p'` && cd ../../
install_dir=`pwd`
sed -i "s!oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v19.0.0!oracle.install.responseFileVersion=/${ora_dir}/install/rspfmt_dbinstall_response_schema_v19.0.0!g" ${db_response_file}
sed -i "s!oracle.install.option=!oracle.install.option=INSTALL_DB_SWONLY!g" ${db_response_file}
sed -i "s!UNIX_GROUP_NAME=!UNIX_GROUP_NAME=${ora_group[0]}!g" ${db_response_file}
sed -i "s!INVENTORY_LOCATION=!INVENTORY_LOCATION=/${ora_dir}/oraInventory!g" ${db_response_file}
sed -i "s!ORACLE_HOME=!ORACLE_HOME=${ORACLE_HOME}!g" ${db_response_file}
sed -i "s!ORACLE_BASE=!ORACLE_BASE=${ORACLE_BASE}!g" ${db_response_file}
sed -i "s!oracle.install.db.InstallEdition=!oracle.install.db.InstallEdition=EE!g" ${db_response_file}
sed -i "s!oracle.install.db.OSDBA_GROUP=!oracle.install.db.OSDBA_GROUP=${ora_group[1]}!g" ${db_response_file}
sed -i "s!oracle.install.db.OSOPER_GROUP=!oracle.install.db.OSOPER_GROUP=${ora_group[2]}!g" ${db_response_file}
sed -i "s!oracle.install.db.OSBACKUPDBA_GROUP=!oracle.install.db.OSBACKUPDBA_GROUP=${ora_group[1]}!g" ${db_response_file}
sed -i "s!oracle.install.db.OSDGDBA_GROUP=!oracle.install.db.OSDGDBA_GROUP=${ora_group[1]}!g" ${db_response_file}
sed -i "s!oracle.install.db.OSKMDBA_GROUP=!oracle.install.db.OSKMDBA_GROUP=${ora_group[1]}!g" ${db_response_file}
sed -i "s!oracle.install.db.OSRACDBA_GROUP=!oracle.install.db.OSRACDBA_GROUP=${ora_group[1]}!g" ${db_response_file}
sed -i "s!oracle.install.db.config.starterdb.type=!oracle.install.db.config.starterdb.type=GENERAL_PURPOSE!g" ${db_response_file}
sed -i "s!oracle.install.db.config.starterdb.globalDBName=!oracle.install.db.config.starterdb.globalDBName=${ORACLE_SID}!g" ${db_response_file}
sed -i "s!oracle.install.db.config.starterdb.SID=!oracle.install.db.config.starterdb.SID=${ORACLE_SID}!g" ${db_response_file}
sed -i "s!oracle.install.db.config.starterdb.characterSet=!oracle.install.db.config.starterdb.characterSet=${CharacterSet}!g" ${db_response_file}
sed -i "s!oracle.install.db.config.starterdb.memoryOption=!oracle.install.db.config.starterdb.memoryOption=true!g" ${db_response_file}
sed -i "s!oracle.install.db.rootconfig.executeRootScript=!oracle.install.db.rootconfig.executeRootScript=false!g" ${db_response_file}
sed -i "s!oracle.install.db.config.starterdb.password.ALL=!oracle.install.db.config.starterdb.password.ALL=${installSysPassword}!g" ${db_response_file}
sed -i "s!oracle.install.db.rootconfig.configMethod=!oracle.install.db.rootconfig.configMethod=ROOT!g" ${db_response_file}
sed -i "s!oracle.install.db.ConfigureAsContainerDB=!oracle.install.db.ConfigureAsContainerDB=false!g" ${db_response_file}
sed -i "s!oracle.install.db.config.starterdb.installExampleSchemas=!oracle.install.db.config.starterdb.installExampleSchemas=false!g" ${db_response_file}
sed -i "s!oracle.install.db.config.starterdb.storageType=!oracle.install.db.config.starterdb.storageType=FILE_SYSTEM_STORAGE!g" ${db_response_file}

###starting to install oracle software
echo "############################   Oracle Installing  #######################################"
oracle_out='/tmp/oracle.out'
touch ${oracle_out}
chown ${ora_user}:${ora_group[0]} ${oracle_out}
su - oracle -c "${install_dir}/runInstaller -silent -responseFile ${db_response_file}" > ${oracle_out} 2>&1
echo -e "\033[34mInstallNotice >>\033[0m \033[32moracle install starting \033[05m...\033[0m"
sleep 60
installActionslog=`find /${ora_dir}/oraInventory -name installActions*.log`
echo "You can check the oracle install log command: tail -100f ${installActionslog}"
while true; do
  grep '[FATAL] [INS-10101]' ${oracle_out} &> /dev/null
  if [[ $? == 0 ]];then
    echo -e "\033[34mInstallNotice >>\033[0m \033[31moracle start install has [ERROR]\033[0m"
    cat ${oracle_out}
    exit
  fi
  sleep 120
  cat /tmp/oracle.out  | grep sh
  if [[ $? == 0 ]];then
    `cat /tmp/oracle.out  | grep sh | awk -F ' ' '{print $2}' |grep Root.sh`
    if [[ $? == 0 ]]; then
      echo -e "\033[34mInstallNotice >>\033[0m \033[32mScript orainstRoot.sh run successed\033[0m"
	  `cat /tmp/oracle.out  | grep sh | awk -F ' ' '{print $2}' |grep root.sh`
        if [[ $? == 0 ]];then
          echo -e "\033[34mInstallNotice >>\033[0m \033[32mScript root.sh  run successed\033[0m"
	      break
        else
          echo -e "\033[34mInstallNotice >>\033[0m \033[31mScript root.sh  run faild\033[0m"
        fi
    else
      echo -e "\033[34mInstallNotice >>\033[0m \033[31mScript orainstRoot.sh run faild\033[0m"
    fi
  fi
done

echo "#######################   Oracle software 安装完成      ##############################"

# install listener && dbca
echo "############################   install oracle listener && dbca  #######################################"
echo "############################   set oracle schema sysPassword  #######################################"
count=0
while [ $count -lt 3 ]
do
        read -p "Please input the SYSPASSWORD(e.g:SysOracle2021):" S1
        read -p "Please input the SYSPASSWORD again(SysOracle2021):" S2
        if [ "${S1}" == "${S2}" ];then
                export SYSPASSWORD=${S1}
                break
        else        
                echo "You input SYSPASSWORD not same."
                count=$[${count}+1]
        fi      
done
echo "############################   set oracle app_user  #######################################"
count=0
while [ $count -lt 3 ]
do
        read -p "Please input the USER_NAME(e.g:orcl):" S1
        read -p "Please input the USER_NAME again(orcl):" S2
        if [ "${S1}" == "${S2}" ];then
                export USER_NAME=${S1}
                break
        else        
                echo "You input USER_NAME not same."
                count=$[${count}+1]
        fi      
done
echo "############################   set oracle app_passwd  #######################################"
count=0
while [ $count -lt 3 ]
do
        read -p "Please input the USER_PASSWD(e.g:Orcl2021):" S1
        read -p "Please input the USER_PASSWD again(Orcl2021):" S2
        if [ "${S1}" == "${S2}" ];then
                export USER_PASSWD=${S1}
                break
        else        
                echo "You input USER_PASSWD not same."
                count=$[${count}+1]
        fi      
done
echo "############################   set app_user tmp_dbf  #######################################"
count=0
while [ $count -lt 3 ]
do
        read -p "Please input the TMP_DBF(e.g:orcl_temp):" S1
        read -p "Please input the TMP_DBF again(orcl_temp):" S2
        if [ "${S1}" == "${S2}" ];then
                export TMP_DBF=${S1}
                break
        else        
                echo "You input TMP_DBF not same."
                count=$[${count}+1]
        fi      
done
echo "############################   set app_user data_dbf  #######################################"
count=0
while [ $count -lt 3 ]
do
        read -p "Please input the DATA_DBF(e.g:orcl_data):" S1
        read -p "Please input the DATA_DBF again(orcl_data):" S2
        if [ "${S1}" == "${S2}" ];then
                export DATA_DBF=${S1}
                break
        else        
                echo "You input DATA_DBF not same."
                count=$[${count}+1]
        fi      
done
echo "############################   set instances tablespace_dir  #######################################"
count=0
while [ $count -lt 3 ]
do
        read -p "Please input the DATA_DIR(e.g:/u01/oracle/data):" S1
        read -p "Please input the DATA_DIR again(/u01/oracle/data):" S2
        if [ "${S1}" == "${S2}" ];then
                export DATA_DIR=${S1}
                break
        else        
                echo "You input tablespace_dir not same."
                count=$[${count}+1]
        fi      
done
if [ ! -d ${DATA_DIR}/${ORACLE_SID} ];then
    mkdir -p ${DATA_DIR}/${ORACLE_SID}
    data_dir=`echo ${DATA_DIR}|awk -F '/' '{print $2}'`
    chown -R ${ora_user}:${ora_group[0]}  /${data_dir}
fi
ORACLE_SID=`su - oracle -c 'source ~/.bash_profile && echo $ORACLE_SID'`
ORACLE_BASE=`su - oracle -c 'source ~/.bash_profile && echo $ORACLE_BASE'`
ORACLE_HOME=`su - oracle -c 'source ~/.bash_profile && echo $ORACLE_HOME'`
ora_dir=`echo ${ORACLE_BASE}|awk -F '/' '{print $2}'`
DB_SHUT=${ORACLE_HOME}/bin/dbshut
DB_START=${ORACLE_HOME}/bin/dbstart
BACKUP_DIR=${ORACLE_BASE}/backup
[ ! -f $BACKUP_DIR ] && mkdir $BACKUP_DIR
backup_dir=`echo ${BACKUP_DIR}|awk -F '/' '{print $2}'`
chown -R ${ora_user}:${ora_group[0]}  /${backup_dir}
MEM=`free -m|grep 'Mem:'|awk '{print $2}'`
TOTAL=$[MEM*8/10]

CDB_SQL="
sqlplus / as sysdba << EOF
create temporary tablespace $TMP_DBF tempfile '$DATA_DIR/$ORACLE_SID/${TMP_DBF}.dbf' size 64m autoextend on next 64m maxsize unlimited extent management local;
create tablespace $DATA_DBF logging datafile '$DATA_DIR/$ORACLE_SID/${DATA_DBF}.dbf' size 64m autoextend on next 64m maxsize unlimited extent management local;
create user $USER_NAME identified by $USER_PASSWD default tablespace $DATA_DBF temporary tablespace $TMP_DBF;
grant connect,resource to $USER_NAME;
grant create view to $USER_NAME;
grant create public synonym to $USER_NAME;
grant drop public synonym to $USER_NAME;
grant unlimited tablespace to $USER_NAME;
create or replace directory dir_dump as '$BACKUP_DIR';
grant read,write on directory dir_dump to $USER_NAME;
ALTER PROFILE DEFAULT LIMIT PASSWORD_LIFE_TIME UNLIMITED;
alter system set processes=1000 scope=spfile;
alter system set sessions=1522 scope=spfile;
shutdown immediate;
startup;
exit
EOF
"

temp=`ls ${ORACLE_BASE}|grep 'data'`
if [ ! -n ${temp} ];then
        mkdir ${ORACLE_BASE}/data
        export DATAFILE=${ORACLE_BASE}/data
else
        export DATAFILE=${ORACLE_BASE}/data
fi
temp=`ls ${ORACLE_BASE}|grep 'area'`
if [ ! -n ${temp} ];then
        mkdir ${ORACLE_BASE}/flash_recovery_area
        export RECOVERY=${ORACLE_BASE}/flash_recovery_area
else
        export RECOVERY=${ORACLE_BASE}/flash_recovery_area
fi
NETCA=`find /${ORACLE_HOME}/assistants -type f -name netca.rsp`

###set listener&tnsnames
echo "############################   Oracle listener&dbca  #######################################"
###start listen
echo -e "\033[34mInstallNotice >>\033[0m \033[32mOracle start listen \033[05m...\033[0m"
su - oracle -c "${ORACLE_HOME}/bin/netca /silent /responsefile ${NETCA}"
netstat -anptu | grep 1521
if [[ $? == 0 ]]; then
  echo -e "\033[34mInstallNotice >>\033[0m \033[32mOracle listen is running\033[0m"
  break
else
  echo -e "\033[34mInstallNotice >>\033[0m \033[31mOracle listen is not running\033[0m"
  exit 5
fi

###start install oracle instance
dbca_response_file=`find ${ORACLE_HOME}/assistants -type f -name dbca.rsp`
sed -i "s!responseFileVersion=/oracle/assistants/rspfmt_dbca_response_schema_v19.0.0=!responseFileVersion=/${ora_dir}/assistants/rspfmt_dbca_response_schema_v19.0.0!g" ${dbca_response_file}
sed -i "s!gdbName=!gdbName=${ORACLE_SID}!g" ${dbca_response_file}
sed -i "s!sid=!sid=${ORACLE_SID}!g" ${dbca_response_file}
sed -i "s!databaseConfigType=!databaseConfigType=SI!g" ${dbca_response_file}
sed -i "s!templateName=!templateName=General_Purpose.dbc!g" ${dbca_response_file}
sed -i "s!sysPassword=!sysPassword=${SYSPASSWORD}!g" ${dbca_response_file}
sed -i "s!systemPassword=!systemPassword=${SYSPASSWORD}!g" ${dbca_response_file}
sed -i "s!characterSet=!characterSet=${CharacterSet}!g" ${dbca_response_file}
sed -i "s!nationalCharacterSet=!nationalCharacterSet=${NationalCharacterSet}!g" ${dbca_response_file}
sed -i "s!createAsContainerDatabase=!createAsContainerDatabase=false!g" ${dbca_response_file}
sed -i "s!totalMemory=!totalMemory=${TOTAL}!g" ${dbca_response_file}

su - oracle -c "${ORACLE_HOME}/bin/dbca -silent -createDatabase -responseFile ${dbca_response_file}"

grep "${ORACLE_SID}" /etc/oratab
if [[ $? == 0 ]];then
  echo -e "\033[34mInstallNotice >>\033[0m \033[32mOracle instances installed successful\033[0m"
else
  echo -e "\033[34mInstallNotice >>\033[0m \033[31mOracle instances init failed\033[0m"
  exit 6
fi

sed -i "s!${ORACLE_SID}:${ORACLE_HOME}:N!${ORACLE_SID}:${ORACLE_HOME}:Y!g" /etc/oratab

AUTO_START_CONFIG=`cat /etc/oratab|grep ${ORACLE_SID} |awk -F ':' '{print $NF}'`
AUTO_START_CONFIG_expected='Y'

if [ ${AUTO_START_CONFIG} = ${AUTO_START_CONFIG_expected} ];then
    echo "AUTO_START_CONFIG successed!"
else
    echo "AUTO_START_CONFIG failed!"
	exit 1
fi

#deal with ORA-28040
sqlnet=$ORACLE_HOME/network/admin/sqlnet.ora
sed -i '4aSQLNET.ALLOWED_LOGON_VERSION_SERVER=11' $sqlnet
sed -i '4aSQLNET.ALLOWED_LOGON_VERSION_CLIENT=11' $sqlnet

#set oracle start&stop sys_service
echo "############################   Oracle sys_service  #######################################"
su - oracle -c "touch /home/oracle/oracle"
cat >/etc/init.d/oracle <<EOF
#!/bin/sh
# chkconfig: 35 80 10
# description: Oracle auto start-stop script.
# Set ORACLE_HOME to be equivalent to the \$ORACLE_HOME
# Oracle database in ORACLE_HOME.
LOGFILE=/home/oracle/oracle
ORACLE_HOME=$ORACLE_HOME
ORACLE_OWNER=oracle
LOCK_FILE=/var/lock/subsys/oracle
if [ ! -f $ORACLE_HOME/bin/dbstart ]
then
    echo "Oracle startup: cannot start"
    exit
fi
case "\$1" in
'start')
# Start the Oracle databases:
echo "Starting Oracle Databases ... "
echo "-------------------------------------------------" >> \${LOGFILE}
date +" %T %a %D : Starting Oracle Databases as part of system up." >> \${LOGFILE}
echo "-------------------------------------------------" >> \${LOGFILE}
su - \$ORACLE_OWNER -c "\$ORACLE_HOME/bin/dbstart $ORACLE_HOME" >> \${LOGFILE}
echo "Done"

# Start the Listener:
echo "Starting Oracle Listeners ... "
echo "-------------------------------------------------" >> \${LOGFILE}
date +" %T %a %D : Starting Oracle Listeners as part of system up." >> \${LOGFILE}
echo "-------------------------------------------------" >> \${LOGFILE}
su - \$ORACLE_OWNER -c "\$ORACLE_HOME/bin/lsnrctl start" >> \${LOGFILE}
echo "Done."
echo "-------------------------------------------------" >> \${LOGFILE}
date +" %T %a %D : Finished." >> \${LOGFILE}
echo "-------------------------------------------------" >> \${LOGFILE}
touch \$LOCK_FILE
;;

'stop')
# Stop the Oracle Listener:
echo "Stoping Oracle Listeners ... "
echo "-------------------------------------------------" >> \${LOGFILE}
date +" %T %a %D : Stoping Oracle Listener as part of system down." >> \${LOGFILE}
echo "-------------------------------------------------" >> \${LOGFILE}
su - \$ORACLE_OWNER -c "\$ORACLE_HOME/bin/lsnrctl stop" >> \${LOGFILE}
echo "Done."
rm -f \$LOCK_FILE

# Stop the Oracle Database:
echo "Stoping Oracle Databases ... "
echo "-------------------------------------------------" >> \${LOGFILE}
date +" %T %a %D : Stoping Oracle Databases as part of system down." >> \${LOGFILE}
echo "-------------------------------------------------" >> \${LOGFILE}
su - \$ORACLE_OWNER -c "\$ORACLE_HOME/bin/dbshut $ORACLE_HOME" >> \${LOGFILE}
echo "Done."
echo ""
echo "-------------------------------------------------" >> \${LOGFILE}
date +" %T %a %D : Finished." >> \${LOGFILE}
echo "-------------------------------------------------" >> \${LOGFILE}
;;

'restart')
\$0 stop
\$0 start
;;
esac
EOF
#set privileges
chmod +x /etc/init.d/oracle
chkconfig oracle on
# check oracle service
service oracle start
if [ $? -ne 0 ];then
  action "oracle service start failed." /bin/false
  exit 2
fi

service oracle stop
if [ $? -ne 0 ];then
  action "oracle service stop failed." /bin/false
  exit 3
fi

service oracle restart
if [ $? -ne 0 ];then
  action "oracle service restart failed." /bin/false
  exit 4
fi

#set create app_user & app_passwd
echo "############################   Oracle sys_service  #######################################"
su - oracle -c "${CDB_SQL}"
if [ $? -eq 0 ];then
  echo -e "\e[30 CDB_SQL execute successed & restart the oracle_service \e[0m"
  service oracle restart
else
  action "oracle create app_user && app_passwd failed." /bin/false
  exit 5
fi

echo "####################### oracle listener && dbca  安装完成 请记录数据库信息      ##############################"

echo "#####   oracle用户系统登录密码:      #####"
echo -e "\e[31;47;5m $ORACLE_OS_PWD \e[0m"

echo "#####   数据库实例名:      #####"
echo -e "\e[30;47;5m $ORACLE_SID \e[0m"

echo "#####   数据库install.db.starterdb密码:      #####"
echo -e "\e[31;47;5m $installSysPassword \e[0m"

echo "#####   数据库实例的sys管理用户密码:      #####"
echo -e "\e[30;47;5m $SYSPASSWORD \e[0m"

echo "#####   数据库应用连接用户名:      #####"
echo -e "\e[31;47;5m $USER_NAME \e[0m"

echo "#####   数据库应用连接用户名对应的密码:      #####"
echo -e "\e[30;47;5m $USER_PASSWD \e[0m"

echo "#####   数据库临时表空间名:      #####"
echo -e "\e[31;47;5m $TMP_DBF \e[0m"

echo "#####   数据库数据表空间名:      #####"
echo -e "\e[30;47;5m $DATA_DBF \e[0m"

echo "#####   数据库表空间存储路径:      #####"
echo -e "\e[31;47;5m ${DATA_DIR} \e[0m"
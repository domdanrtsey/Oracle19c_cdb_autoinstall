### oracle 19C（12.2.0.3） 自动化静默安装脚本

#### 脚本使用安装前配置

> 需要使用root用户执行(尽量安装纯净的OS环境)
> 下载脚本：https://github.com/domdanrtsey/Oracle19c_cdb_autoinstall

1. **请注意：**本脚本是`cdb`容器数据库的安装部署脚本，下面是`plsql`客户端工具的连接事例

   ```shell
   普通用户登录：
   用户名：orcl
   口令：Orcl2021
   数据库：ipaddress:1521/pdbname
   连接为：Normal
   
   sys用户登录：
   用户名：sys
   口令：SysOracle2021
   数据库：ipaddress:1521/ORACLE_SID
   连接为：SYSDBA
   
   system用户登录：
   用户名：system
   口令：SysOracle2021
   数据库：ipaddress:1521/ORACLE_SID
   连接为：Normal
   ```
   
   下面是`navicat`客户端工具的连接事例
   
   ```shell
   普通用户登录(高级中角色选择Default)：
   连接类型：Basic
   主机：ipaddress
   端口：1521
   服务名(选择服务名)：ORACLE_SID
   用户名:orcl
   密码:Orcl2021
   
   sys用户登录(高级中角色选择SYSDBA)：
   连接类型：Basic
   主机：ipaddress
   端口：1521
   服务名(选择服务名)：ORACLE_SID
   用户名:sys
密码:SysOracle2021
   
   system用户登录(高级中角色选择Default)：
      连接类型：Basic
      主机：ipaddress
      端口：1521
      服务名(选择服务名)：ORACLE_SID
      用户名:system
      密码:SysOracle2021
   ```

  问题：`sys/system/orcl`用户登录提示：ORA-01017：用户名/口令无效；登录被拒绝

   重置`sys/system/orcl`用户密码  

```
   $ sqlplus / as sysdba
   alter user sys identified by "SysOracle2021";
   alter user system identified by "SysOracle2021";
   alter user orcl identified by "Orcl2021";
```



2. 安装前请将Oracle 19C安装包（LINUX.X64_193000_db_home.zip ）放置在 /opt/ 目录下（脚本提示是/opt,实际可随意存放）

   系统需要具备512MB的swap交换分区

3. OS可连通互联网(如果不通外网，可以使用如下方法，将依赖包下载下来，再上传到目标服务器安装，以解决依赖问题)

   ```shell
   检查缺少哪些依赖：
   rpm --query --queryformat "%{NAME}-%{VERSION}.%{RELEASE} (%{ARCH})\n" gcc gcc-c++ make binutils compat-libstdc++-33 elfutils-libelf elfutils-libelf-devel glibc glibc-common  glibc-devel libaio libaio-devel libgcc libstdc++ libstdc++-devel unixODBC unixODBC-devel elfutils-libelf-devel-static numactl-devel sysstat pcre-devel readline compat-libcap1 libXi libXtst libxcb ksh zip unzip tree vim lrzsz net-tools wget ntpdate ntp
   安装插件
   #　yum -y install yum-plugin-downloadonly
   创建目录
   # mkdir /root/mypackages/
   下载依赖
   # yum install --downloadonly --downloaddir=/root/mypackages/ gcc gcc-c++ make binutils compat-libstdc++-33 elfutils-libelf elfutils-libelf-devel glibc glibc-common glibc-devel libaio libaio-devel libgcc libstdc++ libstdc++-devel unixODBC unixODBC-devel elfutils-libelf-devel-static numactl-devel sysstat pcre-devel readline compat-libcap1 libXi libXtst libxcb ksh zip unzip tree vim lrzsz net-tools wget ntpdate ntp
   将mypackages文件夹下载下来，上传到目标服务器，在目标环境执行安装
   # cd /root/mypackages/
   安装依赖
   # yum -y localinstall *.rpm --skip-broken
   ```



4. OS提前配置以下信息(根据实际情况，配置如下信息)

   - 配置本机静态IP地址 `HostIP`与 `hostname`（主机名不允许包含下划线）

   - 脚本中Oracle用户密码 `ORACLE_OS_PWD`默认为`Danrtsey.com` 请根据需要在脚本中修改

   - 脚本默认的`processes`与`sessions`值 如下，请根据实际直接在脚本中修改

     ```shell
     配置processes与sessions值：
     alter system set processes=1000 scope=spfile;
     alter system set sessions=1522 scope=spfile;
     ```

     

5. 预先将需要修改的配置信息记录下来，安装时根据脚本提示直接粘贴即可，涉及的信息如下

   **数据库的SID名称：**

   ```shell
   ORACLE_SID=orcl
   脚本执行提示如下：
   read -p 'Please input the ORACLE_SID(e.g:orcl):' S1
   Please input the ORACLE_SID(orcl):
   ```

   **ORACLE_BASE路径：**

   ```shell
   ORACLE_BASE=/u01/oracle
   脚本执行提示如下：
   read -p 'Please input the ORACLE_BASE(e.g:/u01/oracle):' S1
   Please input the ORACLE_BASE(/u01/oracle):
   ```

   **ORACLE_HOM路径：**

   ```shell
   ORACLE_HOME=/u01/oracle/product/19c/dbhome_1
   脚本执行提示如下:
   read -p 'Please input the ORACLE_HOME(e.g:/u01/oracle/product/19c/dbhome_1):' S1
   Please input the ORACLE_HOME(/u01/oracle/product/19c/dbhome_1):
   ```

   **数据库安装包的存放路径：**

   ```shel
   脚本执行提示如下:
   read -p 'Please input the zip file location(e.g:/opt/LINUX.X64_193000_db_home.zip):' zfile
   Please input the zip file location(/opt/LINUX.X64_193000_db_home.zip):
   ```

   **选择数据库字符集与国家字符集：**

   ```shell
   脚本执行提示如下:
   数据库字符集：
   read -p 'Please input the CharacterSet(e.g:ZHS16GBK or AL32UTF8):' C1
   Please input the CharacterSet(ZHS16GBK or AL32UTF8):
   国家字符集：
   read -p "Please input the NationalCharacterSet(e.g:AL16UTF16 or UTF8):" N1
   Please input the NationalCharacterSet(AL16UTF16 or UTF8):
   ```

   **数据库安装sys密码：**

   ```shell
   installSysPassword=SysOracle2021
   脚本执行提示如下:
   read -p 'Please input the installSysPassword(e.g:SysOracle2021):' S1
   Please input the installSysPassword(SysOracle2021):
   ```

   **数据库sysPassword/systemPassword用户密码相同：**

   ```shell
   SYSPASSWORD=SysOracle2021
   脚本执行提示如下:
   read -p "Please input the SYSPASSWORD(e.g:SysOracle2021):" S1
   Please input the SYSPASSWORD(SysOracle2021):
   ```

   **数据库连接用户名：**

   ```shell
   USER_NAME=orcl
   脚本执行提示如下:
   read -p "Please input the USER_NAME(e.g:orcl):" S1
   Please input the USER_NAME(orcl):
   ```

   **数据库连接用户名密码：**

   ```shell
   USER_PASSWD=Orcl2021
   脚本执行提示如下:
   read -p "Please input the USER_PASSWD(e.g:Orcl2021):" S1
   Please input the USER_PASSWD(Orcl2021):
   ```

   **数据库临时表空间名称：**

   ```shell
   TMP_DBF=orcl_temp
   脚本执行提示如下:
   read -p "Please input the TMP_DBF(e.g:orcl_temp):" S1
   Please input the TMP_DBF(orcl_temp):
   ```

   **数据库数据表空间名称：**

   ```shell
   DATA_DBF=orcl_data
   脚本执行提示如下:
   read -p "Please input the DATA_DBF(e.g:orcl_data):" S1
   Please input the DATA_DBF(orcl_data):
   ```

   **数据库数据表空间存储路径：**

   ```shell
   DATA_DIR=/u01/oracle/data
   脚本执行提示如下:
   read -p "Please input the DATA_DIRDATA_DIR(e.g:/u01/oracle/data):" S1
   Please input the DATA_DIR(/u01/oracle/data):
   ```

#### 支持系统

- CentOS 7.4 64

> 说明：linux环境19c(12.2.0.3)安装系统要求如下
>
> The following Linux x86-64 kernels are supported: 
> Oracle Linux 7.4 with the Unbreakable Enterprise Kernel 4: 4.1.12-112.16.7.el7uek.x86_64 or later 
> Oracle Linux 7.4 with the Unbreakable Enterprise Kernel 5: 4.14.35-1818.1.6.el7uek.x86_64 or later 
> Oracle Linux 7.4 with the Red Hat Compatible kernel: 3.10.0-693.5.2.0.1.el7.x86_64 or later 
> Red Hat Enterprise Linux 7.4: 3.10.0-693.5.2.0.1.el7.x86_64 or later 
>
> SUSE Linux Enterprise Server 12 SP3: 4.4.103-92.56-default or later
>
> 脚本已经配置oracle服务自启动，并配置为系统服务，启动与停止时使用root用户操作
```shell
停止
#service oracle stop
启动
#service oracle start
```
> 熟知以上说明之后，开始操作安装部署

```shell
# chmod +x oracle19c_pdb_install.sh
# sh -x oracle19c_pdb_install.sh
```


#!/bin/bash -ue
# A bash script for downloading NCEP GFS 2.5*2.5 files
# need external program: wget wgrib2
# Author: Andy Tian
# Date: Mar 20, 2015

# gfs downloading function
function dl_gfs()
{
  # $1: YYYYMMDD, the Year, Month and Day
  # $2: HH, the model cycle runtime (i.e. 00, 06, 12, 18)
  # $3: FFF, the forecast hour of product from 000 - 384
  # $4: local gfs data path
  local yyyymmdd=$1
  local hh=$2
  local fff=$3
  local finalpath=$4

  local ftp_path="ftp://ftpprd.ncep.noaa.gov/pub/data/nccf/com/gfs/prod"
  local file_name="gfs.t${hh}z.pgrb2.0p50.f${fff}"
  local file_url="${ftp_path}/gfs.${yyyymmdd}${hh}/${file_name}"

  # check if file exists on the ftp server, or wait 10s and recheck
  until wget --spider $file_url 2>&1 | grep exist; do
    echo "$file_url does not exist. Wait 10s!"
    date
    sleep 10
  done

  # test file with wgrib2, or download with wget
  until wgrib2 $file_name > ${file_name}.idx 2>&1; do
    rm -rf $file_name
    wget -T30 -t7200 -w30 -4 -c -v --limit-rate=1m -O $file_name -o dl_${file_name}.log $file_url
  done

  # make a marker when completed
  touch ${file_name}.ok
  cp $file_name $finalpath && rm -rf $file_name
  cp ${file_name}.idx $finalpath && rm -rf ${file_name}.idx
}

# get and set args
rundate=`date +%Y%m%d`
if [[ $# -ge 1 ]]; then
  hh=$1
else
  echo "Usage: $0 00/12 <yyyymmdd>"
  exit 1
fi

if [[ $hh == 00 ]]; then
  gdate=`date +%Y%m%d -d "$rundate"`
  dtlist=(`seq -f %03g 12 6 84`)
elif [[ $hh == 12 ]]; then
  gdate=`date +%Y%m%d -d "$rundate 1 days ago"`
  dtlist=(`seq -f %03g 12 6 180`)
else
  echo "usage: $0 00/12 <yyyymmdd>"
  exit 1
fi

[[ $# -ge 2 ]] && gdate=$2

tmppath=/tmp/gfs/${gdate}${hh}
finalpath=/home/data/gfs/${gdate}${hh}

[[ -d $finalpath ]] || mkdir -p $finalpath
# check if local gfs file exists
if [[ -d $finalpath ]]; then
  cd $finalpath
  for i in `seq 0 $((${#dtlist[@]}-1))`; do
    file_name=gfs.t${hh}z.pgrb2.0p50.f${dtlist[$i]}
    if wgrib2 $file_name > ${file_name}.idx 2>&1; then
      echo "FILE: $file_name allready exists. Skip it!"
      sleep 0.5
      unset dtlist[$i]
    fi
  done
fi

if [[ ${#dtlist[@]} -eq 0 ]]; then
  echo "All GFS files are ready. Exiting..."
  date
  exit 0
fi

#----------------------------------------------------------------------
echo "GFS FILE: $gdate$hh download started!"
date

# download gfs files to tmp dir
[[ -d $tmppath ]] || mkdir -p $tmppath
cd $tmppath
for fff in ${dtlist[@]}; do
  until [[ `pgrep -x wget | wc -l` -lt 5 ]]; do
    sleep 10
  done
  dl_gfs $gdate $hh $fff $finalpath &
  sleep 1
done
wait    # wait all bg jobs

echo "GFS FILE: $gdate$hh download completed!"
date
#----------------------------------------------------------------------

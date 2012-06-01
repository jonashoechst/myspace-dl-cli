#!/bin/bash --
# Myspace music downloader v6.0
# Author of Myspace music downloader <= 5.4: Luka Pusic <luka@pusic.si>
# Author of modifications for a working v6.0 version: Basile Bruneau <basilebruneau@gmail.com>
#
version='6.0'

echo "MySpace music downloader by http://360percents.com & http://ntag.fr"

#Updater - begining
lversionFile=`wget -L "http://projets.ntag.fr/dlmyspace/script/lastversion" --quiet --user-agent="Mozilla" -O -`
lversion=`echo "$lversionFile" | grep 'version' | sed -e 's/version://' | head -n 1`
lversionChangelog=`echo "$lversionFile" | grep 'changelog' | sed -e 's/changelog://' | head -n 1`
lversionUrl=`echo "$lversionFile" | grep 'url' | sed -e 's/url://' | head -n 1`
if [ "$version" != "$lversion" ]; then
 echo "[-] An update is available (v$lversion>v$version)"
 echo "[-] Fast changelog: $lversionChangelog"
 read -n1 -p "[-] Do you want to download it? (y/n) " wantupdate
 echo ""
 if [ "$wantupdate" = "y" ] || [ "$wantupdate" = "Y" ]; then
  echo "[.] Update"
  nameScript="${0##*/}"
  directory1=`dirname "$0"`
  directory2=`pwd`
  directory="$directory2/$directory1"
  echo "$directory"
  echo "[.] Download..."
  wget -L "$lversionUrl" --quiet -O "$directory/$nameScript"
  echo "[.] Launch of the new version!"
  echo ""
  "$directory/$nameScript" $1
  exit;
 else
  echo "[-] As you want!"
 fi
 echo ""
fi
#Updater - end

if [ -z "$1" ]; then
 echo "";echo "Usage: `basename $0` [USER (eg. eminem)]";echo "";exit
fi

type -P rtmpdump &>/dev/null || {
read -n1 -p "I need a program called rtmpdump, do you wan to install it now? (y/n) "
echo [[ $REPLY = [yY] ]] && sudo apt-get -qq -y install rtmpdump || { echo "You didn't answer yes, or installation failed. Install it manualy. Exiting...";}  >&2; exit 1; }

echo "[+] Requesting $1"
page=`wget -L "http://myspace.com/$1" --quiet --user-agent="Mozilla" -O -`
userid=`echo "$page" | grep '?userId' | sed -e 's/.*userId=//' -e 's/".*//' | head -n 1`
artistid=`echo "$page" | grep '&artid' | sed -e 's/.*artid=//' -e 's/&.*//' | head -n 1`
artistname=`echo "$page" | grep 'og:title' | sed -e 's/.*property="og:title" content="//' -e 's/".*//' | head -n 1`
if [ ! "$userid" ]; then
 echo "[-] Trying second method for userID"
 userid=`echo "$page" | grep 'UserId' | sed -e 's/.*UserId=//' | sed -e 's/&.*//g' | head -n 1`
fi
if [ ! "$userid" ]; then
 echo "[+] ERROR: userid is empty!";
 echo '[-] This is common when a change in MySpace occurs, or if this artists page is configured in a non usual way.';
 echo '[-] See http://360percents.com/posts/linux-myspace-music-downloader/ or http://projets.ntag.fr/dlmyspace/ for more info.';
 exit 1;
fi
echo "[-] User ID:$userid"
echo "[-] Artist Name: $artistname"
echo "[+] Requesting XML playlist"

 link="http://www.myspace.com/music/services/player?action=getArtistPlaylist&artistUserId=$userid&artistId=$userid"
 xml=`wget --quiet -L $link --user-agent="Mozilla" -O -`
 songs=`echo "$xml" | tr ">" "\n" | grep 'songId' | tr ' ' "\n" | grep 'songId' | cut -d '"' -f 2`
if [ ! "$songs" ]; then
 echo "[-] Trying second method for playlist xml."
 link="http://www.myspace.com/music/services/player?artistid=$userid&scssb=2&action=getSortedSongs"
xml=`wget --quiet -L $link --user-agent="Mozilla" -O -`
songs=`echo "$xml" | tr ">" "\n" | grep 'songId' | tr ' ' "\n" | grep 'songId' | cut -d '"' -f 2`
fi
songcount=$((`echo "$songs" | wc -l`))
if [ $((`echo "$songs" | wc -c`)) -lt "2" ]; then
 echo "[+] ERROR: no songs found at this url."
 echo "[-] Please submit bugs to: http://360percents.com/posts/linux-myspace-music-downloader/ and http://projets.ntag.fr/dlmyspace/";exit
fi
echo "[+] Found $songcount songs."

for i in `seq 1 $songcount`
do
 songid=`echo "$songs" | sed -n "$i"p`
 link="http://www.myspace.com/music/player?sid=$songid"
 songpage=`wget -L "$link" --quiet --user-agent="Mozilla" -O -`
 title=`echo "$songpage" | grep 'class="song"' | sed -e 's/.*class="song" title="//' -e 's/".*//' -e 's/\\//-/g' | head -n 1`
 rtmp=`echo "$songpage" | grep "rtmpte://" | tr "," "\n" | grep 'rtmpte://' | cut -d '"' -f 4 | head -n 1`
 rtmpr=`echo "$rtmp" | sed -e 's/\.com.*$//' | head -n 1`
 file=`echo "$rtmp" | sed -e 's/.*\.com\///' | head -n 1`
 extension=`echo "$file" | sed -e 's/^.*\.//' | head -n 1`
 rtmpfile=`echo "$file" | sed -e 's/\..*$//' | head -n 1`
 
 if [ "$extension" = "mp3" ]; then
  urlfile="mp3:$rtmpfile"
 elif [ "$extension" = "m4a" ]; then
  urlfile="mp4:$file"
 fi
 
 player=`echo "$songpage" | grep 'PixelPlayerUrl' | sed -e 's/^.*{"PixelPlayerUrl":"//' -e 's/".*//' | head -n 1`
 if [ ! "$title" ]; then
  title="$i"  #use number if no title found
 fi
 echo "Downloading $title..."
 rtmpdump -r "$rtmpr.com/" -a "" -f "LNX 11,2,202,235" -o "$artistname - $title.flv" -q -W "$player" -p "http://www.myspace.com" -y "$urlfile"
 artistname=$(echo "$artistname" | sed -e 's%/%_%g')
 #rtmpdump -l 2 -r "$rtmp" -o "$artistname - $title.flv" -q -W "http://lads.myspacecdn.com/videos/MSMusicPlayer.swf" 
 
 if which ffmpeg >/dev/null; then
  echo "Converting $title to mp3..."
  ffmpeg -y -i "$artistname - $title.flv" -metadata TITLE="$title" -metadata ARTIST="$artistname" -acodec libmp3lame -ab 192000 -ar 44100 -f mp3 "$artistname - $title.mp3" > /dev/null 2>&1 && rm "$artistname - $title.flv"
 fi
done

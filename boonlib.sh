#!/bin/bash

##########################################################
#
#  BOONLIB - Boonleng's BASH library
#  This is a collection of shell script functions for
#  convenient / lazy coding.
#
#  Boon Leng Cheong
#
##########################################################

##########################################################
#
#  l o g
#
#     appends the message in LOGFILE
#
#       o  log MESSAGE
#
##########################################################
function log() {
	if [ -z "$LOGFILE" ]; then
		LOGFILE="$HOME/boonlib.log"
		log $1
		log "LOGFILE undefined. Using LOGFILE=$LOGFILE"
		return
	fi
	log_dir=${LOGFILE%/*}
	if [[ $log_dir != $LOGFILE && ! -z "$log_dir" &&  ! -d "$log_dir" ]]; then
		mkdir -p $log_dir;
	fi
	if [[ ! -z "$DEBUG" && "$DEBUG" == "1" ]]; then
		echo "`date '+%m/%d %r'` : $@"
	fi
	echo "`date '+%m/%d %r'` : $@" >> $LOGFILE
}


##########################################################
#
#  s l o g
#
#     appends the message in LOGFILE, short timestamp
#
#       o  log MESSAGE
#
##########################################################
function slog() {
	if [ -z "$LOGFILE" ]; then
		LOGFILE="$HOME/boonlib.log"
		log $1
		log "LOGFILE undefined. Using LOGFILE=$LOGFILE"
		return
	fi
	log_dir=${LOGFILE%/*}
	if [[ $log_dir != $LOGFILE && ! -z "$log_dir" &&  ! -d "$log_dir" ]]; then
		mkdir -p $log_dir;
	fi
	if [[ ! -z "$DEBUG" && "$DEBUG" == "1" ]]; then
		echo "`date '+%T'` : $@"
	fi
	echo "`date '+%T'` : $@" >> $LOGFILE
}


##########################################################
#
#  n u m 2 s t r 3
#
#     converts a string to a 3-digit groups with comma
#
#       o  num2str3 1234567890
#
##########################################################
function num2str3() {
	len=${#1}
	str3=""
	dig=0
	while [ "$len" -gt 0 ]; do
		len=$((len-1))
		str3="${1:$len:1}$str3"
		dig=$((dig+1))
		if [[ "$dig" -eq "3" && "$len" -gt 0 ]]; then
			dig=0
			str3=",$str3"
		fi
	done
	echo "$str3"
}


##########################################################
#
#  f i l e _ m a n a g e r
#
#     frees up space or limits the the usage until the targeted
#     number is achieved
#
#       o  file_manager FREE/LIMIT PATH TARGET_BYTE [TOLERANCE]
#
##########################################################
function file_manager() {
	log "BOONLIB FILE_MANAGER -- initiated by $USER"
	if [ "$#" -lt "3" ]; then
		log "Need at least three arguments: Method, path, target space, (tolerance) [$#]"
		return
	fi
	method="$1"
	if [[ "$method" != "FREE" && "$method" != "LIMIT" ]]; then
		log "Method can only be FREE or LIMIT"
		return
	fi
	target_path="$2"
	if [ -z "$target_path" ]; then
		log "Target folder not specified."
		return
	fi		
	if [ ! -d "$target_path" ]; then
		log "Target folder does not exist."
		return
	fi
	target_space="$3"
	if [ -z "$target_space" ]; then
		log "Target space empty?"
		return
	fi
	tolerance="$4"
	if [ -z "$tolerance" ]; then tolerance=$((target_space/100)); fi
	log "Target folder: $target_path"
	if [ "$method" == "FREE" ]; then
		log "Target free > `num2str3 $((target_space/1024/1024))` MB"
		# NOTE: df returns free space in 1K blocks
		# Example, 1TB = 1024 GB = 1024*1024*1024 K-blocks
		current=`df $target_path | tail -1 | awk {'print $4'}`
	elif [ "$method" == "LIMIT" ]; then
		log "Target limit < `num2str3 $((target_space/1024/1024))` MB"
		# NOTE: du returns free space in 1K blocks
		# Example, 1TB = 1024 GB = 1024*1024*1024 K-blocks
		current=`du -ks $target_path/ | awk {'print $1'}`
	else
		log "This should not happened."
		return
	fi
	# Size in 1-K blocks
	target_space=$((target_space/1024))
	if [ "$current" -eq "$target_space" ]; then
		ineq="="
		echo "You hit the equal sign" | mail -s "Jackpot! from free_or_limit()" boonleng@ou.edu
	elif [ "$current" -gt "$target_space" ]; then
		ineq=">"
	elif [ "$current" -lt "$target_space" ]; then
		ineq="<"
	else
		ineq="?"
	fi
	log "Current: `num2str3 $((current/1024))` MB $ineq `num2str3 $((target_space/1024))` MB"
	num=0;
	# Get size to be in 1K-block
	find $target_path -maxdepth 3 -type f -print | sort | while read line; do
		# file=${line%%,*}
		# size=${line##*,}
		file=$line
		# file size in 512 block
		size=`ls -s $file | awk {'print $1'}`
		# file size in 1K-block
		size=$((size/2))
		if [[ "$method" == "FREE" && "$current" -gt "$target_space" ]] || 
		   [[ "$method" == "LIMIT" && "$current" -lt "$target_space" ]]; then
			if [ "$num" -gt 0 ]; then
				log "Erased $num file(s)"
				if [ "$method" == "FREE" ]; then
					log "Estimated free space: `num2str3 $((current/1024))` MB"
					current=`df $target_path | tail -1 | awk {'print $4'}`
					log "Actual free space: `num2str3 $((current/1024))` MB"
				else
					log "Estimated usage: `num2str3 $((current/1024))` MB"
					current=`du -ks $target_path | awk {'print $1'}`
					log "Actual usage: `num2str3 $((current/1024))` MB"
				fi
				if [[ "$method" == "FREE" && "$current" -lt "$((target_space-tolerance))" ]] || 
				   [[ "$method" == "LIMIT" && "$current" -gt "$((target_space+tolerance))" ]]; then
					log "Warning! Beyond tolerance. (`num2str3 $((tolerance/1024))` MB)"
					# Find the line with ----. That's where the log last started.
					n=`tail -n 300 $LOGFILE | grep -n -e "----" | tail -n 1`
					n=${n%%:*}
					tail -n $((300-n+1)) $LOGFILE
				fi
			else
				log "Nothing to erase"
			fi
			break
		else
			num=$((num+1))
			cmd="nice -n 10 rm -f $file"
			if [ "$method" == "$FREE" ]; then
				current=$((current+size))
			else
				current=$((current-size))
			fi
			eval $cmd
			log $cmd
		fi
	done
}

##########################################################
#
#  r e m o v e _ f i l e s
#
#     removes files in a specific folder until a targeted free space is achieved
#
#       o  remove_files PATH TARGET_FREE_SPACE TOLERANCE
#
##########################################################
function remove_files() {
	if [ "$#" -lt 2 ]; then
		log "Need at least two arguments: Target path and target free space."
		return;
	fi
	log "remove_files() -- depreciating --> file_manager() -- $USER"
	file_manager "FREE" "$1" "$2" "$((10*1024*1024))"
}

##########################################################
#
#  l i m i t _ u s a g e
#
#     removes files in a specific folder until a targeted usage
#
#       o  limit_usage PATH TARGETED_USAGE
#
##########################################################
function limit_usage() {
	if [ "$#" -lt 2 ]; then
		log "Need at least two arguments: Target path and target free space."
		return;
	fi
	log "limit_usage() -- depreciating --> file_manager() -- $USER"
	file_manager "LIMIT" "$1" "$2" "$((10*1024*1024))"
}


##########################################################
#
#  g e n f i l e l i s t 
#
#     generates a filelist for java applet AniS
#
#       o  genfilelist LIST PATTERN NUM_FILES HOME_PATH CANVAS OVERLAY
#
##########################################################
function genfilelist() {
	FILELIST=$1; if [ -z "$FILELIST" ]; then FILELIST='filelist'; fi
	PATTERN=$2; if [ -z "$PATTERN" ]; then PATTERN='*20[0-9][0-9][01][0-9]*.png'; fi
	NUM=$3; if [ -z "$NUM" ]; then NUM=30; fi
	HOME_PATH=$4; if [ -z "$HOME_PATH" ]; then HOME_PATH='./'; fi
	CANVAS=$5; if [ -z "$CANVAS" ]; then CANVAS='canvas.png'; fi
	OVERLAY=$6; if [ -z "$OVERLAY" ]; then OVERLAY="overlay.png"; fi

	HOME_PATH="${HOME_PATH%/}"
	if [[ -e $DEBUG && "$DEBUG" -eq 1 ]]; then
		log "L:$FILELIST P:$PATTERN  N:$NUM"
		log "H:$HOME_PATH  C:$CANVAS  O:$OVERLAY"
	fi
	tmplist=".genfilelist_`date +%s`"
	echo "# Authomatically generated by genfilelist -- $USER" > $tmplist
	echo "# File created on `date`" >> $tmplist
	find -H $HOME_PATH -maxdepth 3 -type f -name $PATTERN | grep -v "trash" |
	sort | tail -n $NUM | while read line; do
		line="${line#${HOME_PATH}/}"
		line="${line#./}"
		echo "$CANVAS overlay=$line, $OVERLAY" >> $tmplist
	done
	cat $tmplist > $HOME_PATH/$FILELIST
	rm $tmplist
}


##########################################################
#
#  e r a s e _ b u t _ k e e p
#
#     erases files in a folder but keep the last N files (sorted alphabetically)
#
#       o   erase_but_keep DIR NUM PATTERN
#
##########################################################
function erase_but_keep() {
	DIR=$1; if [ -z "$DIR" ]; then DIR="./"; fi
	NUM=$2; if [ -z "$NUM" ]; then NUM=1000; fi
	PAT=$3; if [ -z "$PAT" ]; then PAT='*'; fi
  	log "erase_but_keep() -- $USER"
	log "D:$DIR  N:$NUM  P:$PAT"
#	tra="${DIR%/}/.trash"
#	if [ ! -d "$tra" ]; then mkdir "$tra"; fi
	find -H "$DIR" -maxdepth 1 -type f -name "$PAT" | sort | 
		sed -n -e :a -e "1,${NUM}!{P;N;D;};N;ba" |
		while read f; do
			log "Erase $f"
			# mv "$f" "$tra"
			rm -f $f
		done
}

##########################################################
#
#  r e m o v e _ e m p t y _ d i r
#
#     removes empty directories as the name suggested
#
#       o    remove_empty_dir DIR
#
##########################################################
function remove_empty_dir() {
	log "remove_empty_dir -- $1 -- $USER"
	log "`find $1 -depth -type d -empty`"
	find $1 -depth -type d -empty -exec rmdir '{}' \;
}


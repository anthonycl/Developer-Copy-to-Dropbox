#!/bin/bash

## Developer Copy to Dropbox aka. DCTD
## Version 1.0
##
## Copyright (c) 2011, Anthony Fulginiti - https://github.com/anthonycl/Developer-Copy-to-Dropbox
## Any questions, concerns, or suggestions please email me at Anthony[@]Cliklabs[dot]com
## 
## Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is 
## hereby granted, provided that the above copyright notice and this permission notice appear in all copies.
## 
## THE SOFTWARE IS PROVIDED “AS IS” AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE 
## INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE 
## FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM 
## LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, 
## ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
##
## Credits:
## Ask Function - http://snippets.davejamesmiller.com
## Bash General Knowledge - http://tldp.org/HOWTO/Bash-Prog-Intro-HOWTO.html & http://tldp.org/LDP/abs/html
## irc.freenode.net #bash - Thanks to e36freak, greybot, and geirha for answering many questions.
##
## Dedicated to Steve Jobs RIP

## Settings ( ** Indicates no need to modify, as you will be asked each time to confirm. )
check_run_as_root=true; 									## Do you want to check that you are running this as root? (Required for Moving Applications, permissions, etc.) Functionality WILL break if this script does not run under root or sudo.
make_backups="Y"; 											## ** Make backups before moving [Y/N]

## -- DO NOT MODIFY BELOW THIS LINE, UNLESS YOU KNOW WHAT YOU ARE DOING --

# Supported Applications
declare -a apps=('Coda' 'Tower' 'FileZilla' 'Sequel Pro' 'MAMP/MAMP Pro' 'Linkinus' 'Firefox' 'Google Chrome' 'Growl (Ticket Preferences)');

# Text color variables
txtinfo=$(tput bold; tput setaf 4);
txtwarn=$(tput bold; tput setaf 1; tput setab 0);
txtreset=$(tput sgr0);

echo $txtreset; ## Reset terminal to your preferred text.

# Functions -- Start --

## Ask function for questions and answers.
## Usage - ask {question} {default}
## Returns REPLY
function ask {
    while true; do
 
        default=$2
 
        # Ask the question
        read -p "$1 [$default] " REPLY
 
        # Default?
        if [ -z "$REPLY" ]; then
            REPLY=$default
        fi
 
        askyn "You chose '$REPLY'. Are you sure?" Y && return 1;
 
    done

}

## Ask function for basic yes/no questions.
## Usage - ask {question} {default Y/N}
## Returns REPLYYN
function askyn {
    while true; do
 
        if [ "${2:-}" = "Y" ]; then
            prompt="Y/n"
            default=Y
        elif [ "${2:-}" = "N" ]; then
            prompt="y/N"
            default=N
        else
            prompt="y/n"
            default=
        fi
 
        # Ask the question
        read -p "$1 [$prompt] " REPLYYN
 
        # Default?
        if [ -z "$REPLYYN" ]; then
            REPLYYN=$default
        fi
 		
 		REPLYYN="`echo $REPLYYN|tr [:lower:] [:upper:]`"
 		
        # Check if the reply is valid
        case "$REPLYYN" in
            Y|y) return 0 ;;
            N|n) return 1 ;;
        esac
 
    done
}

function find_version {
	from=$1
	search=$2
	APPVERSION=();

	while IFS= read -r -d '' file;
		do APPVERSION+=( "${file##*/}" );
	done < <(find "${from}" -name "${search}" -print0)

	APPVERSION=${APPVERSION[0]}
	return 1;
}

function newline {
	echo -e "\n";
	
	return 1;
}

function makedir {
	from=$1
	
	if [ ! -e "$from" ]; then
		mkdir "$from"
		chown "${running_user}:staff" "$from"
	fi
	
	return 1;
}

function makelink {
	to=$1
	from=$2

	if [ ! -e "$from" ]; then
	    ln -s "$to" "$from"
	    /usr/local/bin/chmod -ha +a "everyone deny delete" "$from"

	    echo "L++ $to to $from"
	else
		echo "!! $from already exist.";
	fi
	
	return 1;
}

function removefile {
	from=$1

	if [ -e "$from" ]; then
	    rm -rf "$from"
	    echo "-- $from";
	fi
	
	return 1;
}

function movefile {
	from=$1
	to=$2
	linkback=$3
	first_time=$4

	if [ "$first_time" == "Y" ];
	then
		if [ ! -h "$from" ];
		then
			if [ -e "$to" ];
			then
				echo "When trying to move ${from}, it appears ${to} already exist. It appears that you have already ran DCTD for this application.";
				if askyn "Are you sure you want to proceed and overwrite?"; ## Ask question to proceed.
				then
					if [ "$makebackups" == "Y" ];
					then
						cp -pPR "$to" "${to}.backup"
						removefile "$to";
					else
						removefile "$to";
					fi
				else
					echo "!! $to already exist.";
					return 0;
				fi
			fi
	
			if [ "$makebackups" == "Y" ];
			then
				cp -pPR "$from" "${from}.backup"
				mv "$from" "$to"
			else
				mv "$from" "$to"
			fi
		
			echo "-+ $from to $to";
			[ "$linkback" == "Y" ] && makelink "$to" "$from";
			return 1;
		else
			echo "!! $from is a symlink.";
			return 0;
		fi
	else
		[ "$linkback" == "Y" ] && makelink "$to" "$from";
		return 1;
	fi
}

function first_time_check {
	this_app=$1

	echo $txtwarn; ## Set text to warning
	echo "WARNING!!!"; ## Warning and Enable Blink
	newline
	echo "Y) First Time Mode: If this is the first time you are running DCTD for ${this_app} on this computer your files will be moved to Dropbox, deleting anything in your Dropbox's DCTD directory, then symbolic links will be created."
	newline
	echo "N) Restore/Sync Mode: If this is not your first time, we will remove your files on this machine and restore your symbolic links. This option should also be used on other machines you want to connect with Dropbox sync, after you have already used DCTD to sync your main machine..";
	newline
	
	echo $txtreset; ## Reset text back to normal.
	if askyn "Proceed in first time mode?"; ## Ask question to proceed.
	then
		echo "- Entering First Time Mode";
		first_time="Y";
	else
		echo "- Entering Restore/Sync Mode";
		first_time="N";
	fi
	
	echo "... Please Wait as we process your move request."
	
	return 1;
}

## Move Functions
function move_coda {
	## Coda Copy
	echo "- Coda Move to Dropbox -- Start";
	first_time_check "Coda";
	killall "Coda" ## Kill app before processing

	## remove files
	[ "$first_time" == "N" ] && removefile "${user_dir}Library/Preferences/com.panic.Coda.plist";
	[ "$first_time" == "N" ] && removefile "${user_dir}Library/Preferences/com.panic.LSSharedFileList.plist";
	[ "$first_time" == "N" ] && removefile "${user_dir}Library/Application Support/Coda";
	[ "$first_time" == "N" ] && removefile "/Applications/Coda.app";
	
	## move files
	movefile "${user_dir}Library/Preferences/com.panic.Coda.plist" "${dropbox_dir}Library/Preferences/com.panic.Coda.plist" Y $first_time;
	movefile "${user_dir}Library/Preferences/com.panic.LSSharedFileList.plist" "${dropbox_dir}Library/Preferences/com.panic.LSSharedFileList.plist" Y $first_time;
	movefile "${user_dir}Library/Application Support/Coda" "${dropbox_dir}Library/Application Support/Coda" Y $first_time;
	movefile "/Applications/Coda.app" "${dropbox_dir}Applications/Coda.app" Y $first_time;

	echo "- Coda Move to Dropbox -- Complete";
	return 1;
}

function move_tower {
	## Tower Copy
	echo "- Tower Move to Dropbox -- Start";
	first_time_check "Tower";
	killall "Tower" ## Kill app before processing

	## remove files
	[ "$first_time" == "N" ] && removefile "${user_dir}Library/Preferences/com.fournova.Tower.plist";
	[ "$first_time" == "N" ] && removefile "${user_dir}Library/Application Support/Tower";
	[ "$first_time" == "N" ] && removefile "/Applications/Tower.app";
	
	## move files
	movefile "${user_dir}Library/Preferences/com.fournova.Tower.plist" "${dropbox_dir}Library/Preferences/com.fournova.Tower.plist" Y $first_time;
	movefile "${user_dir}Library/Application Support/Tower" "${dropbox_dir}Library/Application Support/Tower" Y $first_time;
	movefile "/Applications/Tower.app" "${dropbox_dir}Applications/Tower.app" Y $first_time;

	echo "If your git repositories are in your sites/htdocs directory when you move MAMP, be sure to update them in Tower on the update repository screen."
	echo "- Tower Move to Dropbox -- Complete";
	return 1;
}

function move_filezilla {
	## Filezilla Copy
	echo "- Filezilla Move to Dropbox -- Start";
	first_time_check "Filezilla";
	killall "filezilla" ## Kill app before processing

	## remove files
	[ "$first_time" == "N" ] && removefile "${user_dir}Library/Preferences/de.filezilla.plist";
	[ "$first_time" == "N" ] && removefile "/Applications/Filezilla.app";
	
	## move files
	movefile "${user_dir}Library/Preferences/de.filezilla.plist" "${dropbox_dir}Library/Preferences/de.filezilla.plist" Y $first_time;
	movefile "/Applications/Filezilla.app" "${dropbox_dir}Applications/Filezilla.app" Y $first_time;

	echo "- Filezilla Move to Dropbox -- Complete";
	return 1;
}

function move_sequelpro {
	## Sequel Pro Copy
	echo "- Sequel Pro Move to Dropbox -- Start";
	first_time_check "Sequel Pro";
	killall "Sequel Pro" ## Kill app before processing

	## remove files
	[ "$first_time" == "N" ] && removefile "${user_dir}Library/Preferences/com.google.code.sequel-pro.plist";
	[ "$first_time" == "N" ] && removefile "${user_dir}Library/Preferences/com.google.code.sequel-pro.LSSharedFileList.plist";
	[ "$first_time" == "N" ] && removefile "${user_dir}Library/Application Support/Sequel Pro";
	[ "$first_time" == "N" ] && removefile "/Applications/Sequel Pro.app";
	
	## move files
	movefile "${user_dir}Library/Preferences/com.google.code.sequel-pro.plist" "${dropbox_dir}Library/Preferences/com.google.code.sequel-pro.plist" Y $first_time;
	movefile "${user_dir}Library/Preferences/com.google.code.sequel-pro.LSSharedFileList.plist" "${dropbox_dir}Library/Preferences/com.google.code.sequel-pro.LSSharedFileList.plist" Y $first_time;
	movefile "${user_dir}Library/Application Support/Sequel Pro" "${dropbox_dir}Library/Application Support/Sequel Pro" Y $first_time;
	movefile "/Applications/Sequel Pro.app" "${dropbox_dir}Applications/Sequel Pro.app" Y $first_time;

	echo "- Sequel Pro Move to Dropbox -- Complete";
	return 1;
}

function move_mamp {
	## MAMP/MAMP Pro Copy
	echo "- MAMP/MAMP Pro Move to Dropbox -- Start";
	first_time_check "MAMP/MAMP Pro";
	find_version "/Applications" "MAMP PRO *";
	killall "MAMP" ## Kill app before processing
	killall "MAMP PRO" ## Kill app before processing

	## modify mysql config
	if [ "$first_time" == "Y" ]; then
		## modify backup
		cd "${user_dir}Library/Application Support/appsolute/MAMP PRO/templates/"
		cp -pPR "my.cnf.temp" "my.cnf.temp.backup";

		sed '/bind-address/a \
		user=root\
		innodb_file_per_table' my.cnf.temp.backup > my.cnf.temp
		
		echo "√ - Modified MySQL Config"
	fi

	## remove files
	[ "$first_time" == "N" ] && removefile "${user_dir}Library/Preferences/de.appsolute.MAMP.plist";
	[ "$first_time" == "N" ] && removefile "${user_dir}Library/Preferences/de.appsolute.mamppro.plist";
	[ "$first_time" == "N" ] && removefile "${user_dir}Library/Preferences/de.living-e_to_appsolute.mampro.plist";
	[ "$first_time" == "N" ] && removefile "${user_dir}Library/Application Support/appsolute";
	[ "$first_time" == "N" ] && removefile "/Library/Application Support/appsolute";
	[ "$first_time" == "N" ] && removefile "/Applications/MAMP";
	[ "$first_time" == "N" ] && removefile "/Applications/${APPVERSION}";
	
	## move files
	movefile "${user_dir}Library/Preferences/de.appsolute.MAMP.plist" "${dropbox_dir}Library/Preferences/de.appsolute.MAMP.plist" Y $first_time;
	movefile "${user_dir}Library/Preferences/de.appsolute.mamppro.plist" "${dropbox_dir}Library/Preferences/de.appsolute.mamppro.plist" Y $first_time;
	movefile "${user_dir}Library/Preferences/de.living-e_to_appsolute.mampro.plist" "${dropbox_dir}Library/Preferences/de.living-e_to_appsolute.mampro.plist" Y $first_time;
	movefile "${user_dir}Library/Application Support/appsolute" "${dropbox_dir}Library/Application Support/MAMP" Y $first_time;
	movefile "/Library/Application Support/appsolute" "${dropbox_dir}Library/Application Support/MAMP PRO" Y $first_time;
	movefile "/Applications/${APPVERSION}" "${dropbox_dir}Applications/${APPVERSION}" Y $first_time;
	movefile "/Applications/MAMP" "${dropbox_dir}Applications/MAMP" Y $first_time;

	echo "- MAMP/MAMP Pro Move to Dropbox -- Complete";
	return 1;
}

function move_linkinus {
	## Linkinus Copy
	echo "- Linkinus Move to Dropbox -- Start";
	first_time_check "Linkinus";
	killall "Linkinus" ## Kill app before processing
	killall "Linkinus Agent" ## Kill app before processing

	## remove files
	[ "$first_time" == "N" ] && removefile "${user_dir}Library/Preferences/net.conceited.Linkinus.plist";
	[ "$first_time" == "N" ] && removefile "${user_dir}Library/Preferences/net.conceited.Linkinus.SysInfoPlugInPane.plist";
	[ "$first_time" == "N" ] && removefile "${user_dir}Library/Preferences/net.conceited.LinkinusAgent.plist";
	[ "$first_time" == "N" ] && removefile "${user_dir}Library/Preferences/net.conceited.LinkinusSysInfoPlugIn.plist";
	[ "$first_time" == "N" ] && removefile "${user_dir}Library/Application Support/Linkinus 2";
	[ "$first_time" == "N" ] && removefile "/Applications/Linkinus.app";
	
	## move files
	movefile "${user_dir}Library/Preferences/net.conceited.Linkinus.plist" "${dropbox_dir}Library/Preferences/net.conceited.Linkinus.plist" Y $first_time;
	movefile "${user_dir}Library/Preferences/net.conceited.Linkinus.SysInfoPlugInPane.plist" "${dropbox_dir}Library/Preferences/net.conceited.Linkinus.SysInfoPlugInPane.plist" Y $first_time;
	movefile "${user_dir}Library/Preferences/net.conceited.LinkinusAgent.plist" "${dropbox_dir}Library/Preferences/net.conceited.LinkinusAgent.plist" Y $first_time;
	movefile "${user_dir}Library/Preferences/net.conceited.LinkinusSysInfoPlugIn.plist" "${dropbox_dir}Library/Preferences/net.conceited.LinkinusSysInfoPlugIn.plist" Y $first_time;
	movefile "${user_dir}Library/Application Support/Linkinus 2" "${dropbox_dir}Library/Application Support/Linkinus 2" Y $first_time;
	movefile "/Applications/Linkinus.app" "${dropbox_dir}Applications/Linkinus.app" Y $first_time;

	echo "- Linkinus Move to Dropbox -- Complete";
	return 1;
}

function move_firefox {
	## Firefox Copy
	echo "- Firefox Move to Dropbox -- Start";
	first_time_check "Firefox";
	killall "firefox" ## Kill app before processing

	## remove files
	[ "$first_time" == "N" ] && removefile "${user_dir}Library/Preferences/org.mozilla.firefox.plist";
	[ "$first_time" == "N" ] && removefile "${user_dir}Library/Application Support/Firefox";
	[ "$first_time" == "N" ] && removefile "/Applications/Firefox.app";
	
	## move files
	movefile "${user_dir}Library/Preferences/org.mozilla.firefox.plist" "${dropbox_dir}Library/Preferences/org.mozilla.firefox.plist" Y $first_time;
	movefile "${user_dir}Library/Application Support/Firefox" "${dropbox_dir}Library/Application Support/Firefox" Y $first_time;
	movefile "/Applications/Firefox.app" "${dropbox_dir}Applications/Firefox.app" Y $first_time;

	echo "- Firefox Move to Dropbox -- Complete";
	return 1;
}

function move_chrome {
	## Google Chrome Copy
	echo "- Google Chrome Move to Dropbox -- Start";
	first_time_check "Google Chrome";
	killall "Google Chrome" ## Kill app before processing

	## remove files
	[ "$first_time" == "N" ] && removefile "${user_dir}Library/Preferences/com.google.Chrome.plist";
	[ "$first_time" == "N" ] && removefile "${user_dir}Library/Application Support/Google";
	[ "$first_time" == "N" ] && removefile "/Applications/Google Chrome.app";
	
	## move files
	movefile "${user_dir}Library/Preferences/com.google.Chrome.plist" "${dropbox_dir}Library/Preferences/com.google.Chrome.plist" Y $first_time;
	movefile "${user_dir}Library/Application Support/Google/Chrome" "${dropbox_dir}Library/Application Support/Google/Chrome" Y $first_time;
	movefile "/Applications/Google Chrome.app" "${dropbox_dir}Applications/Google Chrome.app" Y $first_time;

	echo "- Firefox Move to Dropbox -- Complete";
	return 1;
}

function move_growl {
	## Growl (Ticket Preferences) Copy
	echo "- Growl (Ticket Preferences) Move to Dropbox -- Start";
	first_time_check "Growl (Ticket Preferences)";

	makedir "${dropbox_dir}Library/Application Support/Growl"
	makedir "${dropbox_dir}Library/Application Support/Growl/Tickets"

	## Coda Growl
	askyn "Do you want to move Coda's Growl Ticket Prefences?" Y;
	if [ "$REPLYYN" == "Y" ]; then
		[ "$first_time" == "N" ] && removefile "${user_dir}Library/Application Support/Growl/Tickets/Coda.growlTicket";
		movefile "${user_dir}Library/Application Support/Growl/Tickets/Coda.growlTicket" "${dropbox_dir}Library/Application Support/Growl/Tickets/Coda.growlTicket" Y $first_time;
	fi

	## Firefox Growl
	askyn "Do you want to move Firefox's Growl Ticket Prefences?" Y;
	if [ "$REPLYYN" == "Y" ]; then
		[ "$first_time" == "N" ] && removefile "${user_dir}Library/Application Support/Growl/Tickets/Firefox.growlTicket";
		movefile "${user_dir}Library/Application Support/Growl/Tickets/Firefox.growlTicket" "${dropbox_dir}Library/Application Support/Growl/Tickets/Firefox.growlTicket" Y $first_time;
	fi

	## Linkinus Growl
	askyn "Do you want to move Linkinus's Growl Ticket Prefences?" Y;
	if [ "$REPLYYN" == "Y" ]; then
		[ "$first_time" == "N" ] && removefile "${user_dir}Library/Application Support/Growl/Tickets/Linkinus.growlTicket";
		movefile "${user_dir}Library/Application Support/Growl/Tickets/Linkinus.growlTicket" "${dropbox_dir}Library/Application Support/Growl/Tickets/Linkinus.growlTicket" Y $first_time;
	fi

	## Sequel Pro Growl
	askyn "Do you want to move Sequel Pro's Growl Ticket Prefences?" Y;
	if [ "$REPLYYN" == "Y" ]; then
		[ "$first_time" == "N" ] && removefile "${user_dir}Library/Application Support/Growl/Tickets/Sequel Pro.growlTicket";
		movefile "${user_dir}Library/Application Support/Growl/Tickets/Sequel Pro.growlTicket" "${dropbox_dir}Library/Application Support/Growl/Tickets/Sequel Pro.growlTicket" Y $first_time;
	fi

	echo "- Growl (Ticket Preferences) Move to Dropbox -- Complete";
	return 1;
}

# Functions -- End --

clear

## Check running as root!
if $check_run_as_root; then
	if [[ $EUID -ne 0 ]]; then
		echo $txtwarn; ## Set text to warning
		echo "DCTD must be run as root or sudo." 1>&2
		echo $txtreset; ## Reset text
		exit 1
	fi
fi

echo $txtinfo; ## Set text to info
# Check for ACL Compatible Chmod -- Start
if [ ! -e "/usr/local/bin/chmod" ]
then
	echo "In order to move forward you must have a ACL compatible chmod, I can do this for you and place the new one in /usr/local/bin/. Don't worry this will not touch your current chmod in /bin/chmod. This is required to move forward.";
	newline
	if ! askyn "Do you want to proceed?"; ## Ask question to proceed.
	then
		exit;
	fi

	## If no exit, keep on!
	chmod_url="http://opensource.apple.com/source/file_cmds/file_cmds-202.2/chmod/" ## Directory to get the chmod. This should never change.
	chmod_temp_dir="/usr/local/bin/chmodcomp"										## Directory to temp compile chmod
	mkdir "${chmod_temp_dir}"
	cp "./chmod.patch" "${chmod_temp_dir}"
	cd "${chmod_temp_dir}"
	
	## Download it
	wget --output-document=Makefile "${chmod_url}Makefile?txt"
	wget --output-document=chmod.1 "${chmod_url}chmod.1?txt"
	wget --output-document=chmod.c "${chmod_url}chmod.c?txt"
	wget --output-document=chmod_acl.c "${chmod_url}chmod_acl.c?txt"
	wget --output-document=chmod_acl.h "${chmod_url}chmod_acl.h?txt"

	## Patch it
	patch -p1 -i chmod.patch

	## Compile it
	make
	make install
	
	## Put it in its place
	mv /tmp/chmod/Release//usr/local/bin/chmod /usr/local/bin/chmod

	rm -rf "${chmod_temp_dir}"
	
	clear
	echo "√ - ACL Compatible Chmod Installed"
else
	echo "√ - ACL Compatible Chmod Found"
fi

# Check for ACL Compatible Chmod -- End

## Welcome Text
echo "Hello! My name is Siri and I am here to help move your applications, preferences, sites to Dropbox. I am only compatible with Mac OS X 10.6 or later, please exit now if that is not you. You must have the applications you want me to help you move already installed AND working on this machine. Right now I support the following Applications: ";

echo $txtreset; ## Reset text

## Loop Through Supported Apps
for i in "${apps[@]}"
do
	echo $i
done

echo $txtwarn; ## Set text to warning
echo "WARNING!!! MOVE FORWARD AT YOUR OWN RISK!"; ## Warning and Enable Blink
echo "Moving forward could create, modify, and or delete certain application or preferences. You are at your own risk! The applications you decide to process with DCDT will be forcibly shut down, please make sure to save first before continuing.";

echo $txtreset; ## Reset text back to normal.
if ! askyn "Are you sure you want to proceed?"; ## Ask question to proceed.
then
	exit;
fi

clear

## Ask some general questions.
running_user=$SUDO_USER;										## User the script will run as
ask "What is the username of the account where everything is located?" $running_user;
running_user=$REPLY

newline

dropbox_dir="/Users/${running_user}/Dropbox/DCTD/";	## Dropbox location, with trailing slash
ask "Where is your Dropbox directory?" $dropbox_dir;
dropbox_dir=$REPLY

user_dir="/Users/${running_user}/";				## Library location, with trailing slash

newline

askyn "Do you want to make backups?" $make_backups;
make_backups=$REPLYYN

clear

# Move Sites - Start
askyn "Do you want to move your sites over to Dropbox?";
if [ "$REPLYYN" == "Y" ]; then
	makedir "${dropbox_dir}Sites"
	sites_dir="${user_dir}Sites";	## Sites/htdocs location
	
	ask "Where are your current web files stored?" $sites_dir;
	sites_dir=$REPLY

	if [ -d "$sites_dir" ]; then
		cd "$sites_dir"
		
		echo "... Please wait, moving all ${sites_dir}'s contents to ${dropbox_dir}Sites."

		while IFS= read -r -d '' file; do
			if [ "${file:0:3}" != "./." ] && [ "${file}" != "." ];
			then
				movefile "${sites_dir}/${file:2}" "${dropbox_dir}Sites/${file:2}" Y Y;
			fi
		done < <(find . -maxdepth 1 -print0)
		
		echo "√ - Your sites have been moved."
	else
		echo "!! - Your sites directory you specified does not exist!"
	fi
fi
# Move Sites - End

## Create folders in Dropbox Dir ( If Not Already )
chmod 755 "${dropbox_dir}"
makedir "${dropbox_dir}"
makedir "${dropbox_dir}Library"
makedir "${dropbox_dir}Library/Preferences"
makedir "${dropbox_dir}Library/Application Support"
makedir "${dropbox_dir}Applications"

## Loop Through Supported Apps
## ('Coda' 'Tower' 'FileZilla' 'Sequel Pro' 'MAMP/MAMP Pro' 'Linkinus' 'Firefox' 'Google Chrome' 'Growl (Ticket Preferences)')
while true; do
	
	newline

	index=1;
	for i in "${apps[@]}"
	do
		echo "$index) $i";
		((index++))
	done
	echo "10) All Apps"; ## All
	echo "11) Exit"; ## Exit

	read -p "Please select the number next to the app you want to move to Dropbox: " REPLYAPP

	case $REPLYAPP in
		1)
			move_coda
			;;
		2)
			move_tower
			;;
		3)
			move_filezilla
			;;
		4)
			move_sequelpro
			;;
		5)
			move_mamp
			;;
		6)
			move_linkinus
			;;
		7)
			move_firefox
			;;
		8)
			move_chrome
			;;
		9)
			move_growl
			;;
		10)
			move_coda
			move_tower
			move_filezilla
			move_sequelpro
			move_mamp
			move_linkinus
			move_firefox
			move_chrome
			move_growl
			;;
		11)
			clear
			echo "You chose to exit. Thanks, Goodbye!"
			break
			;;
		*)
			clear
			echo "You must choose a valid numeric option."
			;;
	esac
done

exit;
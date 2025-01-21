#!/bin/bash
#-------------------------------------------------------------------------------------------------
# This script performs the workflow to create a new release or hotfix on a git-flow project
# EXECUTE: ./<script_name> <flow-type> <flow-mode> <version/name>
#-------------------------------------------------------------------------------------------------

# Constants
COLOR_LIGHT_RED='\033[0;91m'
COLOR_RED='\033[0;31m'
COLOR_LIGHT_GREEN='\033[0;92m'
COLOR_GREEN='\033[0;32m'
COLOR_LIGHT_BLUE='\033[0;94m'
COLOR_BLUE='\033[0;34m'
COLOR_LIGHT_YELLOW='\033[0;93m'
COLOR_YELLOW='\033[0;33m'
COLOR_MAGENTA='\033[0;35m'
COLOR_CYAN='\033[0;36m'
COLOR_WHITE='\033[0;37m'
COLOR_GRAY='\033[0;90m'
COLOR_END='\033[0m'

SEPARATOR0="##########################################################################################"
SEPARATOR1="******************************************************************************************"
SEPARATOR2="------------------------------------------------------------------------------------------"
SEPARATOR3=".........................................................................................."

NEW_LINE=$'\n'
TAB=$'\t'

REDMINE_URL=https://redmine.wdna.com

# Move to the script dir to be sure al the scripts working
cd "$(dirname "$0")" || exit 1

trap ctrl_c INT

# FUNCTIONS *****************************************************************

ctrl_c() {
    rm -f *.tmp
    echo -e "- [${RED}INTERRUPTED${NOT}]: by keyboard please check repository status before continue !!" > /dev/stderr
    exit 1
}

is_clean() {
    if [ -n "$(git status --porcelain)" ]
    then
        echo -e "- [${COLOR_RED}ERROR${COLOR_END}]: You have uncommitted changes, please commit or stash them before continue" > /dev/stderr
        exit 1
    fi
}


# check if the required packages are installed
SET_PKG="git git-flow xmlstarlet curl fzf"
CHK_PKG=$(dpkg-query --show ${SET_PKG} &> /dev/null ; echo $?)
if [ "${CHK_PKG}" == "1" ]
then
    echo -e "$0" "${LINENO}" "- ERROR: must install packages [ ${COLOR_RED}${SET_PKG}${COLOR_END} ] to this script can work" > /dev/stderr
    exit 1
fi
# Check if git is initialized
if [ ! -d .git ]
then
    echo -e "- [${COLOR_RED}ERROR${COLOR_END}]: This is not a git repository" > /dev/stderr
    exit 1
fi
# Check if master or main is a branch
if [ -f .git/refs/heads/master ]  || [ -f .git/refs/remotes/origin/master ]
then
    BRANCH_MAIN="master"
elif [ -f .git/refs/heads/main ] || [ -f .git/refs/remotes/origin/main ]
then
    BRANCH_MAIN="main"
else
    echo -e "- [${COLOR_RED}ERROR${COLOR_END}]: This repository does not have a [${COLOR_YELLOW}master${COLOR_END}] or [${COLOR_YELLOW}main${COLOR_END}] branch. Please create one '${COLOR_YELLOW}git checkout -b master${COLOR_END}' or '${COLOR_YELLOW}git checkout -b main${COLOR_END}'" > /dev/stderr
    exit 1
fi
# Check if develop is a branch
if [ -f .git/refs/heads/develop ] || [ -f .git/refs/remotes/origin/develop ]
then
    BRANCH_DEVELOP="develop"
else
    echo -e "- [${COLOR_RED}ERROR${COLOR_END}]: This repository does not have a [${COLOR_YELLOW}develop${COLOR_END}] branch. Please create '${COLOR_YELLOW}git checkout -b develop${COLOR_END}'" > /dev/stderr
    exit 1
fi
# Check is clean
is_clean
# Check if git-flow is initialized
if ! grep -q "\[gitflow" .git/config
then
    echo -e "- [${COLOR_RED}ERROR${COLOR_END}]: git-flow is not initialized in this repository. Please run '${COLOR_YELLOW}git flow init${COLOR_END}'" > /dev/stderr
    exit 1
fi



ACTION=$(printf "feature\nrelease\nhotfix\nQUIT" | fzf --multi --height=90% --header="Select a flow type" --prompt="Select: ")
echo -e "- [${COLOR_LIGHT_BLUE}ACTION${COLOR_END}]: ${ACTION}"
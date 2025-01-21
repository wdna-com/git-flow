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

make_feature() {
    # Check if the user wants to start a new feature
    read -n 1 -r -s -p "Do you want to create a new feature? [y/N]: " CREATE
    echo ""
    if [ "${CREATE}" == "y" ] || [ "${CREATE}" == "Y" ]
    then
        if [ "${BRANCH_CURRENT}" != "${BRANCH_DEVELOP}" ]
        then
            echo -e "- [${COLOR_YELLOW}INFO${COLOR_END}]: Switching to [${COLOR_YELLOW}develop${COLOR_END}] branch" > /dev/stdout
            git checkout develop
        fi
        echo -e "- [${COLOR_YELLOW}INFO${COLOR_END}]: Pulling changes from remote [${COLOR_YELLOW}develop${COLOR_END}] branch" > /dev/stdout
        git pull -q
        echo -e "- [${COLOR_YELLOW}INFO${COLOR_END}]: Creating a new feature branch..." > /dev/stdout
        read -rp "Enter feature number: " FEATURE_NUMBER
        echo ""
        if [ -z "${FEATURE_NUMBER}" ]
        then
            echo -e "- [${COLOR_RED}ERROR${COLOR_END}]: Feature number cannot be empty" > /dev/stderr
            exit 1
        elif  [ ! "${FEATURE_NUMBER}" =~ ^[0-9]+$ ]
        then
            echo -e "- [${COLOR_RED}ERROR${COLOR_END}]: Feature number must be a number" > /dev/stderr
            exit 1
        else
            echo -e "- [${COLOR_YELLOW}INFO${COLOR_END}]: Creating a new feature branch  [${COLOR_YELLOW}feature/#${FEATURE_NUMBER}${COLOR_END}]" > /dev/stdout
            git flow feature start "#${FEATURE_NUMBER}" > /dev/null
            echo -e "- [${COLOR_YELLOW}INFO${COLOR_END}]: Pushing the new feature branch [${COLOR_YELLOW}feature/#${FEATURE_NUMBER}${COLOR_END}] to remote" > /dev/stdout
            git flow feature publish "#${FEATURE_NUMBER}" > /dev/null
            exit 0
        fi
    fi

    # Check if the user wants to finish a feature
    read -n 1 -r -s -p "Do you want to finish a feature? [y/N]: " FINISH
    echo ""
    if [ "${FINISH}" == "y" ] || [ "${FINISH}" == "Y" ]
    then
        local branch_feature=$(git branch --list "feature/#*" | fzf --height=90% --header="Select a feature branch to finish" --prompt="Select: ")
        if [[ "${branch_feature}" == "feature/#*" ]]
        then
            echo -e "- [${COLOR_RED}ERROR${COLOR_END}]: You must select a feature branch to finish" > /dev/stderr
            exit 1
        fi
        echo -e "- [${COLOR_YELLOW}INFO${COLOR_END}]: Finishing feature branch [${COLOR_YELLOW}${branch_feature}${COLOR_END}]" > /dev/stdout
        local feature_number=$(echo "${branch_feature}" | sed -e "s/feature\/#//")
        git flow feature finish "${feature_number}" > /dev/null

        echo -e "- [${COLOR_YELLOW}INFO${COLOR_END}]: Pushing changes to remote" > /dev/stdout
        git push -q
        exit 0
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

BRANCH_CURRENT=$(git rev-parse --abbrev-ref HEAD)



ACTION=$(printf "feature\nrelease\nhotfix\nQUIT" | fzf --multi --height=90% --header="Select a flow type" --prompt="Select: ")

case "${ACTION}" in
    "feature")
        make_feature || exit 1
        ;;
    "release")
        echo "Release"
        ;;
    "hotfix")
        echo "Hotfix"
        ;;
    "QUIT")
        echo "Quit"
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac
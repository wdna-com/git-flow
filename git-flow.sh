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
write_changelog() {
    echo -e "$1" >> CHANGELOG.tmp
}

make_feature() {
    # Check if the user wants to start a new feature
    read -n 1 -r -s -p "Do you want to create a new feature? [y/N]: " CREATE
    echo ""
    if [ "${CREATE}" == "y" ] || [ "${CREATE}" == "Y" ]
    then
        local BRANCH_CURRENT
        BRANCH_CURRENT=$(git rev-parse --abbrev-ref HEAD)
        if [ "${BRANCH_CURRENT}" != "${BRANCH_DEVELOP}" ]
        then
            echo -e "- [${COLOR_YELLOW}INFO${COLOR_END}]: Switching to [${COLOR_YELLOW}develop${COLOR_END}] branch" > /dev/stdout
            git checkout -q develop
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
        elif  [[ ! "${FEATURE_NUMBER}" =~ ^[0-9]+$ ]]
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
        local branch_feature=$(git for-each-ref --format='%(refname:short)' refs/heads/ | grep '^feature' | fzf --height=90% --header="Select a feature branch to finish")
        if [[ "${branch_feature}" != feature/#* ]]
        then
            echo -e "- [${COLOR_RED}ERROR${COLOR_END}]: You must select a feature branch to finish" > /dev/stderr
            exit 1
        fi
        local BRANCH_CURRENT
        BRANCH_CURRENT=$(git rev-parse --abbrev-ref HEAD)
        if [ "${BRANCH_CURRENT}" != "${branch_feature}" ]
        then
            echo -e "- [${COLOR_YELLOW}INFO${COLOR_END}]: Switching to [${COLOR_YELLOW}${branch_feature}${COLOR_END}] branch" > /dev/stdout
            git checkout -q "${branch_feature}"
        fi
        echo -e "- [${COLOR_YELLOW}INFO${COLOR_END}]: Finishing feature branch [${COLOR_YELLOW}${branch_feature}${COLOR_END}]" > /dev/stdout
        local feature_number=$(echo "${branch_feature}" | grep -oP '#\K\d+')
        git flow feature finish "#${feature_number}" > /dev/null

        echo -e "- [${COLOR_YELLOW}INFO${COLOR_END}]: Pushing changes to remote" > /dev/stdout
        git push -q
        exit 0
    fi

    # Check if the user wants to update a feature
    read -n 1 -r -s -p "Do you want to update a feature? [y/N]: " UPDATE
    echo ""
    if [ "${UPDATE}" == "y" ] || [ "${UPDATE}" == "Y" ]
    then
        local branch_feature=$(git for-each-ref --format='%(refname:short)' refs/heads/ | grep '^feature' | fzf --height=90% --header="Select a feature branch to update")
        if [[ "${branch_feature}" == "feature/#*" ]]
        then
            echo -e "- [${COLOR_RED}ERROR${COLOR_END}]: You must select a feature branch to update" > /dev/stderr
            exit 1
        fi
        echo -e "- [${COLOR_YELLOW}INFO${COLOR_END}]: Updating feature branch [${COLOR_YELLOW}${branch_feature}${COLOR_END}]" > /dev/stdout
        git checkout -q "${branch_feature}"
        git pull -q
        # [GIT_MERGE_AUTOEDIT=no] for non interative release operation
        GIT_MERGE_AUTOEDIT=no git merge -q develop
        exit 0
    fi
}

make_release() {
    read -n 1 -r -s -p "Do you want to create a new release? [y/N]: " CREATE
    echo ""
    if [ "${CREATE}" == "y" ] || [ "${CREATE}" == "Y" ]
    then
        # Check if the user wants to start a new release
        read -r -p "$(echo -e "- ${COLOR_YELLOW}Redmine API KEY${COLOR_END} (url: ${COLOR_YELLOW}https://redmine.wdna.com/my/account${COLOR_END}): ")" REDMINE_API_KEY
        if [ -z "${REDMINE_API_KEY}" ]
        then
            echo -e "- [${COLOR_RED}ERROR${COLOR_END}]: Redmine API KEY is mandatory to continue" > /dev/stderr
            exit 1
        fi
        RESPONSE=$(curl -sb -H "Content-Type: application/xml" -H "X-Redmine-API-Key: ${REDMINE_APIKEY}" "${REDMINE_URL}/issues.xml?limit=1")
        if [ -n "${RESPONSE}" ]
        then
            echo -e "- [${COLOR_RED}ERROR${COLOR_END}]: Redmine API KEY is invalid" > /dev/stderr
            exit 1
        else
            echo -e "- [${COLOR_YELLOW}INFO${COLOR_END}]: Redmine API KEY is valid" > /dev/stdout
        fi
        local BRANCH_CURRENT
        BRANCH_CURRENT=$(git rev-parse --abbrev-ref HEAD)
        if [ "${BRANCH_CURRENT}" != "${BRANCH_DEVELOP}" ]
        then
            echo -e "- [${COLOR_YELLOW}INFO${COLOR_END}]: Switching to [${COLOR_YELLOW}develop${COLOR_END}] branch" > /dev/stdout
            git checkout -q develop
        fi

        local version_old
        version_old=$(git tag --sort=v:refname | tail -1)
        if [ -z "${version_old}" ]
        then
            version_old="0.0.0"
        fi
        read -rp "$(echo -e "- ${COLOR_YELLOW}Current version${COLOR_END}: ${COLOR_YELLOW}${version_old}${COLOR_END}\n- ${COLOR_YELLOW}Enter release version${COLOR_END}: ")" RELEASE_VERSION
        if [ -z "${RELEASE_VERSION}" ]
        then
            echo -e "- [${COLOR_RED}ERROR${COLOR_END}]: Release version cannot be empty" > /dev/stderr
            exit 1
        elif [[ ! "${RELEASE_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
        then
            echo -e "- [${COLOR_RED}ERROR${COLOR_END}]: Release version must be in the format [${COLOR_YELLOW}x.x.x${COLOR_END}]" > /dev/stderr
            exit 1
        fi
        echo "${SEPARATOR1}"

        echo -e "- [${COLOR_YELLOW}INFO${COLOR_END}]: Pulling changes from remote [${COLOR_YELLOW}${BRANCH_MAIN}${COLOR_END}] branch" > /dev/stdout
        git checkout -q "${BRANCH_MAIN}"
        git pull -q
        echo -e "- [${COLOR_YELLOW}INFO${COLOR_END}]: Pulling changes from remote [${COLOR_YELLOW}develop${COLOR_END}] branch" > /dev/stdout
        git checkout -q develop
        git pull -q
        echo -e "- [${COLOR_YELLOW}INFO${COLOR_END}]: Pushing changes to remote [${COLOR_YELLOW}develop${COLOR_END}] branch" > /dev/stdout
        git push -q origin develop

        echo "${SEPARATOR1}"
        echo -e "- [${COLOR_YELLOW}INFO${COLOR_END}]: Creating a new release branch  [${COLOR_YELLOW}release/${RELEASE_VERSION}${COLOR_END}]" > /dev/stdout
        git flow release start "${RELEASE_VERSION}" > /dev/null

        if [ $? -ne 0 ]
        then
            echo -e "- [${COLOR_RED}ERROR${COLOR_END}]: Failed to create a new release branch" > /dev/stderr
            exit 1
        fi
        # Extract git feature codes (sorted and unique only)
        local feature_list
        feature_list=$(git log --pretty=oneline ${BRANCH_MAIN}..HEAD | grep "Merge branch 'feature/#" | awk '{print $4}' | sed 's/feature\/#//')
        # Remove quotes 
        feature_list=$(echo "${feature_list}" | tr -d '"' | tr -d "'")
        # Sort feature codes by number
        feature_list=$(echo "${feature_list}" | sort -n | uniq)

        # Generating temporary changelog ************************
        local changelog_head changelog_tail
        changelog_head=$(head -8 CHANGELOG.md)
        changelog_tail=$(tail --lines=+10 CHANGELOG.md)
        echo -e "- [${COLOR_YELLOW}INFO${COLOR_END}]: Generating temporary changelog" > /dev/stdout
        rm -f CHANGELOG.tmp
        write_changelog "${changelog_head}"
        write_changelog ""

        # Add release version
        write_changelog "## [${RELEASE_VERSION}] - $(date +'%Y-%m-%d')"
        OLD_IFS=$IFS
        export IFS="#"
        for feature in ${feature_list}
        do
            if [ -n "${feature}" ]
            then
                local XML
                XML=$(curl -sb -H "Content-Type: application/xml" -H "X-Redmine-API-Key: ${REDMINE_API_KEY}" "${REDMINE_URL}/issues/${feature}.xml")
                if [ -n "$XML" ]
                then
                    local subject
                    subject=$(xmlstarlet select -t -v "//issue/subject/text()" <<< "$XML" )
                    write_changelog "- ${feature}: ${subject}"
                else
                    echo -e "- [${COLOR_RED}ERROR${COLOR_END}]: cannot retrieve redmine information of the feature: [${COLOR_YELLOW}${feature}${COLOR_END}]" > /dev/stderr
                fi 
            fi
        done
        export IFS=$OLD_IFS
        write_changelog ""
        write_changelog "${changelog_tail}"
        # Replace main changelog with tmp
        mv CHANGELOG.tmp CHANGELOG.md
        # Store version number in VERSION text file
        echo "${RELEASE_VERSION}" > VERSION

        # Commit changes
        echo -e "- [${COLOR_YELLOW}INFO${COLOR_END}]: Committing changes" > /dev/stdout
        git commit -q -am "Release version ${RELEASE_VERSION}" > /dev/null
        if [ $? -ne 0 ]
        then
            echo -e "- [${COLOR_RED}ERROR${COLOR_END}]: Failed to commit changes" > /dev/stderr
            exit 1
        fi

        # Publish release branch
        echo -e "- [${COLOR_YELLOW}INFO${COLOR_END}]: Pushing the new release branch [${COLOR_YELLOW}release/${RELEASE_VERSION}${COLOR_END}] to remote" > /dev/stdout
        git flow release publish "${RELEASE_VERSION}" > /dev/null

    fi

    read -n 1 -r -s -p "Do you want to finish a release? [y/N]: " FINISH
    echo ""
    if [ "${FINISH}" == "y" ] || [ "${FINISH}" == "Y" ]
    then
        local BRANCH_CURRENT
        BRANCH_CURRENT=$(git rev-parse --abbrev-ref HEAD)
        if [[ "${BRANCH_CURRENT}" != release/*.*.* ]]
        then
            echo -e "- [${COLOR_RED}ERROR${COLOR_END}]: You must be in a release branch to finish" > /dev/stderr
            exit 1
        fi
        local RELEASE_VERSION
        RELEASE_VERSION="${BRANCH_CURRENT/release\//}"
        # Finish the new release version with git-flow ***********
        # [GIT_MERGE_AUTOEDIT=no] for non interative release operation
        echo -e "- [${COLOR_YELLOW}INFO${COLOR_END}]: Finishing release branch [${COLOR_YELLOW}${BRANCH_CURRENT}${COLOR_END}]" > /dev/stdout
        GIT_MERGE_AUTOEDIT=no git flow release finish -m "Release version ${VERSION_NEW}" "${VERSION_NEW}" > /dev/null

        echo -e "- [${COLOR_YELLOW}INFO${COLOR_END}]: Pushing changes to remote [${COLOR_YELLOW}$BRANCH_MAIN${COLOR_END}] branch" > /dev/stdout
        git checkout -q "$BRANCH_MAIN"
        git push -q
        echo -e "- [${COLOR_YELLOW}INFO${COLOR_END}]: Pushing changes to remote [${COLOR_YELLOW}develop${COLOR_END}] branch" > /dev/stdout
        git checkout -q develop
        git push -q
        echo -e "- [${COLOR_YELLOW}INFO${COLOR_END}]: Pushing new tag [${COLOR_YELLOW}${RELEASE_VERSION}${COLOR_END}] to remote" > /dev/stdout
        git checkout -q develop
        git push -q origin "${RELEASE_VERSION}"
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



ACTION=$(printf "feature\nrelease\nhotfix\nQUIT" | fzf --multi --height=90% --header="Select a flow type")

case "${ACTION}" in
    "feature")
        make_feature || exit 1
        ;;
    "release")
        make_release || exit 1
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
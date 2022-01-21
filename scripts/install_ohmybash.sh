#!/usr/bin/env bash

# https://github.com/ohmybash/oh-my-bash
echo 
echo "##### Download and install oh-my-bash..."
pushd /tmp
# Check if git is installed, since it is a prerequisite. `^` to only list lines
# that start with git (git and git-man).
if ! [[  $(sudo dpkg -l | cut -d " " -f 3 | grep "^git" | wc -l) -gt 0 ]] 
then
	echo
	echo ">>> git not found, installing ..."
	sudo apt-get update && sudo apt-get -y install git
fi 
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)"

echo
echo "## Configure using garo theme..."
sed -i 's/OSH_THEME.*/OSH_THEME="garo"/1' ${HOME}/.bashrc

source ${HOME}/.bashrc

popd


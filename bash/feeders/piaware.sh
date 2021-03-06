#!/bin/bash

#####################################################################################
#                                   ADS-B FEEDER                                    #
#####################################################################################
#                                                                                   #
# This script is not meant to be executed directly.                                 #
# Instead execute install.sh to begin the installation process.                     #
#                                                                                   #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                                                                   #
# Copyright (c) 2015 Joseph A. Prochazka                                            #
#                                                                                   #
# Permission is hereby granted, free of charge, to any person obtaining a copy      #
# of this software and associated documentation files (the "Software"), to deal     #
# in the Software without restriction, including without limitation the rights      #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell         #
# copies of the Software, and to permit persons to whom the Software is             #
# furnished to do so, subject to the following conditions:                          #
#                                                                                   #
# The above copyright notice and this permission notice shall be included in all    #
# copies or substantial portions of the Software.                                   #
#                                                                                   #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR        #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,          #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE       #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER            #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,     #
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE     #
# SOFTWARE.                                                                         #
#                                                                                   #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

## VAARIABLES

BUILDDIR=$PWD
PIAWAREDIR="$PWD/piaware_builder"

source ../bash/variables.sh
source ../bash/functions.sh

## INFORMATIVE MESSAGE ABOUT THIS SOFTWARE

clear

echo -e "\033[31m"
echo "-------------------------------"
echo " Now ready to install PiAware."
echo "-------------------------------"
echo -e "\033[33mPiAware is a package used to forward data read from an ADS-B receiver to FlightAware."
echo "It does this using a program, piaware, aided by some support programs."
echo ""
echo "piaware        - establishes an encrypted session to FlightAware and forwards data"
echo "piaware-config - used to configure piaware like with a FlightAware username and password"
echo "piaware-status - used to check the status of piaware"
echo "faup1090       - run by piaware to connect to dump1090 or some other program producing beast-style ADS-B data and translate between its format and FlightAware's"
echo "fa-mlat-client - run by piaware to gather data for multilateration"
echo ""
echo "https://github.com/flightaware/piaware"
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\033[33m"
echo "Installing packages needed to build and fulfill dependencies..."
echo -e "\033[37m"
CheckPackage git
CheckPackage build-essential
CheckPackage debhelper
CheckPackage tcl8.5-dev
CheckPackage autoconf
CheckPackage python3-dev
CheckPackage python-virtualenv

# libz-dev appears to have been replaced by zlib1g-dev at least in Ubuntu Vivid Vervet...
# Will need to check if this is the case with Raspbian and Debian as well.
#CheckPackage libz-dev
CheckPackage zlib1g-dev

CheckPackage tclx8.4
CheckPackage tcllib
CheckPackage tcl-tls
CheckPackage itcl3

## DOWNLOAD OR UPDATE THE PIAWARE_BUILDER SOURCE

# Check if the git repository already exists locally.
if [ -d $PIAWAREDIR ] && [ -d $PIAWAREDIR/.git ]; then
    # A directory with a git repository containing the source code exists.
    echo -e "\033[33m"
    echo "Updating the local piaware_builder git repository..."
    echo -e "\033[37m"
    cd $PIAWAREDIR
    git pull origin master
else
    # A directory containing the source code does not exist in the build directory.
    echo -e "\033[33m"
    echo "Cloning the piaware_builder git repository locally..."
    echo -e "\033[37m"
    git clone https://github.com/flightaware/piaware_builder.git
    cd $PIAWAREDIR
    git checkout ${PIAWAREBRANCH}
fi

## BUILD THE PIAWARE PACKAGE

echo -e "\033[33m"
echo "Building the PiAware package..."
echo -e "\033[37m"
./sensible-build.sh
cd $PIAWAREDIR/package
dpkg-buildpackage -b

## INSTALL THE PIAWARE PACKAGE

echo -e "\033[33m"
echo "Installing the PiAware package..."
echo -e "\033[37m"
sudo dpkg -i $PIAWAREDIR/piaware_${PIAWAREVERSION}_*.deb

## CHECK THAT THE PACKAGE INSTALLED

if [ $(dpkg-query -W -f='${STATUS}' piaware 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    echo "\033[31m"
    echo "The piaware package did not install properly!"
    echo -e "\033[33m"
    echo "This script has exited due to the error encountered."
    echo "Please read over the above output in order to determine what went wrong."
    echo ""
    exit 1
fi

## CONFIGURE FLIGHTAWARE

echo -e "\033[31m"
echo "CLAIM YOUR PIAWARE DEVICE"
echo -e "\033[33m"
echo "Please supply your FlightAware login in order to claim this device."
echo "After supplying your login PiAware will ask you to enter your password for verification."
echo "If you decide not to supply a login and password you should still be able to claim your"
echo "feeder by visting the page http://flightaware.com/adsb/piaware/claim."
echo -e "\033[37m"
read -p "Your FlightAware Login: " FALOGIN
sudo piaware-config -user $FALOGIN -password

echo -e "\033[33m"
printf "Setting PiAware to send MLAT results on port 30104..."
ORIGINALFORMAT=`sudo piaware-config -show | grep mlatResultsFormat | sed 's/mlatResultsFormat //g'`
MLATRESULTS=`sed 's/[{}]//g' <<< $ORIGINALFORMAT`
CLEANFORMAT=`sed 's/beast,connect,localhost:30104//g' <<< $MLATRESULTS`
FINALFORMAT="${CLEANFORMAT} beast,connect,localhost:30104" | sed -e 's/^[ \t]*//'
# Make sure that the mlatResultsFormat setting is not left blank if no other settings exist..
if [ -n "$FINALFORMAT" ]; then
    sudo piaware-config -mlatResultsFormat "${FINALFORMAT}"
else
    sudo piaware-config -mlatResultsFormat "beast,connect,localhost:30104"
fi
echo -e "\033[32m [OK]"

echo -e "\e[33m"
echo "Restarting PiAware to ensure all changes are applied..."
echo -e "\033[37m"
sudo /etc/init.d/piaware restart

echo -e "\033[33m"
echo "Installation and configuration of PiAware is now complete."
echo "Please look over the output generated to be sure no errors were encountered."
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

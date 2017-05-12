#!/bin/sh

while getopts ":b:" opt; do
  case $opt in
    b)
      echo "Branch has been defined as: $OPTARG" >&2
      BRANCH_NAME=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      echo "Valid usage is \"-b \$BRANCH_NAME\""
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires the branch be specified as an argument." >&2
      exit 1
      ;;
  esac
done

#Checking if $BRANCH_NAME was defined in input, if not setting it based on $USERNAME
if [ -z $BRANCH_NAME ]
  then
    echo "Branch has not been defined, switching to default branch based on environment"

    #Determine which environment we are in and set branch default accordingly
    #Should evaluate $NODE_ENV but this is currently 'production' on all nodes...
    #uses $USERNAME to determine environment instead.
    case  $USERNAME  in
      oshdev)
        BRANCH_NAME="develop"
        echo "Setting branch to: $BRANCH_NAME"
        ;;
      oshuat)
        BRANCH_NAME="develop"
        echo "Setting branch to: $BRANCH_NAME"
        ;;
      oshprd)
        BRANCH_NAME="master"
        echo "Setting branch to: $BRANCH_NAME"
        ;;
      *)
        echo "Script is not running as correct user. Exiting"
        exit 1
    esac
  else
    echo "Setting branch to: $BRANCH_NAME"
fi

#Get latest state of origin from git and switch to $BRANCH_NAME then pull the latest code
cd /data/websites/OneShareWeb
git fetch origin
git checkout $BRANCH_NAME
git pull origin
git reset --hard origin/$BRANCH_NAME
#git clean -f
git status

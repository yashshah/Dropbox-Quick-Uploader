#!/usr/bin/env bash
#
# Dropbox Quick Uploader
# This is just a sample script for getting started with Zotonic GSoC project

# Author: Yash Shah
# Email: mail@yashshah.com

# To begin, create a new Dropbox App from here
# https://www2.dropbox.com/developers/apps

# Then authenticate yourself, by running following command and entering Appkey and AppPasskey
# ./dropbox

# To upload a file, use the following command
# ./dropbox upload  [LOCAL_FILE]  <REMOTE_FILE>




#Set to 1 to enable DEBUG mode
DEBUG=0

#Set to 1 to enable VERBOSE mode
VERBOSE=1

# Temporary folder
TMP_DIR="/tmp"

CONFIGURATION_FILE="DropboxConfiguration"
API_REQUEST_TOKEN_URL="https://api.dropbox.com/1/oauth/request_token"
API_USER_AUTH_URL="https://www2.dropbox.com/1/oauth/authorize"
API_ACCESS_TOKEN_URL="https://api.dropbox.com/1/oauth/access_token"
API_UPLOAD_URL="https://api-content.dropbox.com/1/files_put"
APP_CREATE_URL="https://www2.dropbox.com/developers/apps"
RESPONSE_FILE="$TMP_DIR/du_resp_$RANDOM"

umask 077

#Returns unix timestamp
function utime
{
    echo $(date +%s)
}

function remove_temp_files
{
    if [ $DEBUG -eq 0 ]; then
        rm -fr "$RESPONSE_FILE"
        rm -fr "$CHUNK_FILE"
    fi
}


if [ -z "$CURL_BIN" ]; then
    BIN_DEPS="$BIN_DEPS curl"
    CURL_BIN="curl"   
fi


#$1 = Local source file
#$2 = Remote destination file
function db_upload
{
    local FILE_SRC=$1
    local FILE_DST=$2
    
    #Show the progress bar during the file upload
    if [ $VERBOSE -eq 1 ]; then
        CURL_PARAMETERS="--progress-bar"
    else
        CURL_PARAMETERS="-s --show-error"
    fi
 
    echo -ne " > Uploading $FILE_SRC to $2... \n"  
    time=$(utime)
    $CURL_BIN $CURL_ACCEPT_CERTIFICATES $CURL_PARAMETERS -i --globoff -o "$RESPONSE_FILE" --upload-file "$FILE_SRC" "$API_UPLOAD_URL/$ACCESS_LEVEL/$FILE_DST?oauth_consumer_key=$APPKEY&oauth_token=$OAUTH_ACCESS_TOKEN&oauth_signature_method=PLAINTEXT&oauth_signature=$APPSECRET%26$OAUTH_ACCESS_TOKEN_SECRET&oauth_timestamp=$time&oauth_nonce=$RANDOM"
           
    #Check
    grep "HTTP/1.1 200 OK" "$RESPONSE_FILE" > /dev/null
    if [ $? -eq 0 ]; then
        echo -ne " > DONE\n"
    else
        echo -ne " > FAILED\n"
        echo -ne "   An error occurred requesting /upload\n"
        remove_temp_files
        exit 1
    fi   
}

# SETUP
#CHECKING FOR AUTH FILE
if [ -f "$CONFIGURATION_FILE" ]; then
      
    #Loading data...
    APPKEY=$(sed -n 's/APPKEY:\([a-z A-Z 0-9]*\)/\1/p' "$CONFIGURATION_FILE")
    APPSECRET=$(sed -n 's/APPSECRET:\([a-z A-Z 0-9]*\)/\1/p' "$CONFIGURATION_FILE")
    ACCESS_LEVEL=$(sed -n 's/ACCESS_LEVEL:\([A-Z]*\)/\1/p' "$CONFIGURATION_FILE")
    OAUTH_ACCESS_TOKEN_SECRET=$(sed -n 's/OAUTH_ACCESS_TOKEN_SECRET:\([a-z A-Z 0-9]*\)/\1/p' "$CONFIGURATION_FILE")
    OAUTH_ACCESS_TOKEN=$(sed -n 's/OAUTH_ACCESS_TOKEN:\([a-z A-Z 0-9]*\)/\1/p' "$CONFIGURATION_FILE")
    
    #Checking the loaded data
    if [ -z "$APPKEY" -o -z "$APPSECRET" -o -z "$OAUTH_ACCESS_TOKEN_SECRET" -o -z "$OAUTH_ACCESS_TOKEN" ]; then
        echo -ne "Error loading data from $CONFIGURATION_FILE...\n"
        echo -ne "It is recommended to run $0 unlink\n"
        remove_temp_files
        exit 1
    fi
    
    #Back compatibility with previous Dropbox Uploader versions
    if [ -z "$ACCESS_LEVEL" ]; then
        ACCESS_LEVEL="dropbox"
    fi

# NEW SETUP
else

    #Getting the app key and secret from the user

    echo -n " # App key: "
    read APPKEY

    echo -n " # App secret: "
    read APPSECRET

    ACCESS_LEVEL="sandbox"
  
    ACCESS_MSG="App Folder"

    #TOKEN REQUESTS
    echo -ne "\n > Requesting Token... "
    time=$(utime)
    $CURL_BIN $CURL_ACCEPT_CERTIFICATES -s --show-error --globoff -i -o $RESPONSE_FILE --data "oauth_consumer_key=$APPKEY&oauth_signature_method=PLAINTEXT&oauth_signature=$APPSECRET%26&oauth_timestamp=$time&oauth_nonce=$RANDOM" "$API_REQUEST_TOKEN_URL"
    OAUTH_TOKEN_SECRET=$(sed -n 's/oauth_token_secret=\([a-z A-Z 0-9]*\).*/\1/p' "$RESPONSE_FILE")
    OAUTH_TOKEN=$(sed -n 's/.*oauth_token=\([a-z A-Z 0-9]*\)/\1/p' "$RESPONSE_FILE")

    if [ -n "$OAUTH_TOKEN" -a -n "$OAUTH_TOKEN_SECRET" ]; then
        echo -ne "OK\n"
    else
        echo -ne " FAILED\n\n Please, check your App key and secret...\n\n"
        remove_temp_files
        exit 1
    fi

    while (true); do

        #USER AUTH
        echo -ne "\n > Please visit this URL and allow the App to access your DropBox account:\n --> ${API_USER_AUTH_URL}?oauth_token=$OAUTH_TOKEN\n"
        echo -ne " Press Enter when done...\n"
        read

        #API_ACCESS_TOKEN_URL
        echo -ne " > Getting Token request... "
        time=$(utime)
        $CURL_BIN $CURL_ACCEPT_CERTIFICATES -s --show-error --globoff -i -o $RESPONSE_FILE --data "oauth_consumer_key=$APPKEY&oauth_token=$OAUTH_TOKEN&oauth_signature_method=PLAINTEXT&oauth_signature=$APPSECRET%26$OAUTH_TOKEN_SECRET&oauth_timestamp=$time&oauth_nonce=$RANDOM" "$API_ACCESS_TOKEN_URL"
        OAUTH_ACCESS_TOKEN_SECRET=$(sed -n 's/oauth_token_secret=\([a-z A-Z 0-9]*\)&.*/\1/p' "$RESPONSE_FILE")
        OAUTH_ACCESS_TOKEN=$(sed -n 's/.*oauth_token=\([a-z A-Z 0-9]*\)&.*/\1/p' "$RESPONSE_FILE")
        OAUTH_ACCESS_UID=$(sed -n 's/.*uid=\([0-9]*\)/\1/p' "$RESPONSE_FILE")
        
        if [ -n "$OAUTH_ACCESS_TOKEN" -a -n "$OAUTH_ACCESS_TOKEN_SECRET" -a -n "$OAUTH_ACCESS_UID" ]; then
            echo -ne "OK\n"
            
            #Saving data
            echo "APPKEY:$APPKEY" > "$CONFIGURATION_FILE"
            echo "APPSECRET:$APPSECRET" >> "$CONFIGURATION_FILE"
            echo "ACCESS_LEVEL:$ACCESS_LEVEL" >> "$CONFIGURATION_FILE"
            echo "OAUTH_ACCESS_TOKEN:$OAUTH_ACCESS_TOKEN" >> "$CONFIGURATION_FILE"
            echo "OAUTH_ACCESS_TOKEN_SECRET:$OAUTH_ACCESS_TOKEN_SECRET" >> "$CONFIGURATION_FILE"
            
            echo -ne "\n *Setup completed!*\n"
            break
        else
            echo -ne " FAILED\n"
        fi

    done;
    
    remove_temp_files     
    exit 0
fi


#START FROM HERE

COMMAND=$1

#CHECKING PARAMS VALUES
case $COMMAND in

    upload)

        FILE_SRC=$2
        FILE_DST=$3

        #Checking FILE_SRC
        if [ ! -f "$FILE_SRC" ]; then
            echo -e "Error: Please specify a valid source file!"
            remove_temp_files
            exit 1
        fi
        
        #Checking FILE_DST
        if [ -z "$FILE_DST" ]; then
            FILE_DST=/$(basename "$FILE_SRC")
        fi
        
        db_upload "$FILE_SRC" "$FILE_DST"
        
    ;;
    

esac 
   
remove_temp_files
exit 0

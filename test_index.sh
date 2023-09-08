#/bin/bash

function urldecode() {
    : "${*//+/ }"; echo -e "${_//%/\\x}"; 
}

x="http%3A%2F%2Fstackoverflow.com%2Fsearch%3Fq%3Durldecode%2Bbash"
y=$(urldecode "$x")
echo "$y"

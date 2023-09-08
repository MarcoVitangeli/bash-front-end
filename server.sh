#!/bin/bash

## Create the response FIFO
rm -f response
mkfifo response

# helpers

function urldecode() {
    : "${*//+/ }"; echo -e "${_//%/\\x}"; 
}

function get_next_id() {
    MAX_ID=$(cat data/todos.txt | tail -n 1 | cut -d';' -f1 | cut -d'=' -f2)

    let MAX_ID=MAX_ID+1
    NEXT_ID="$MAX_ID"
}

function handle_DELETE_todo() {
    target_id=$(echo "$HTMX_TARGET" | sed "s/l//") 
    echo "ID TO DELETE: $target_id"

    ct=$(grep -v "ID=$target_id" ./data/todos.txt | awk '{print $0}')
    echo "$ct" > ./data/todos.txt
}

function handle_POST_todo() {
    get_next_id
    CURR_TITLE=$(urldecode "$CURR_TITLE")
    CURR_DESC=$(urldecode "$CURR_DESC")
    echo "ID=$MAX_ID;Title=$CURR_TITLE;Content=$CURR_DESC" >> ./data/todos.txt
    RESPONSE="<li id=l$MAX_ID><article><h3>$CURR_TITLE</h3><p>$CURR_DESC</p><footer><span hx-delete="/todo" hx-target="\#l$MAX_ID" hx-swap="delete" role="button">Delete</span></footer></article></li>"
    }

    function handle_GET_index() {
        TODO_REGEX="ID=(.+);Title=(.+);Content=(.+)"
        rendered_list=""
        rep_str="<li id=l\1><article><h3>\2</h3><p>\3</p><footer><span hx-delete="/todo" hx-target="\#l\\1" hx-swap="delete" role="button">Delete</span></footer></article></li>"

            while IFS= read line; do
                rg=$(echo "$line" | sed -E "s|$TODO_REGEX|$rep_str|")

                rendered_list="$rendered_list$rg"
            done < './data/todos.txt'

            ts=$(date '+%Y-%m-%d %H:%M:%S')

            RESPONSE=$(cat ./html/index.html | sed "s|{list}|$rendered_list|g" | sed "s|{timestamp}|$ts|g")
        }

        function handle_not_found() {
            RESPONSE=$(cat ./html/404.html)
        }

        function handleRequest() {
            ## Read request
            while read line; do
                echo $line
                trline=$(echo $line | tr -d '[\r\n]')

                [ -z "$trline" ] && break

                HEADLINE_REGEX='(.*?)\s(.*?)\sHTTP.*?'
                [[ "$trline" =~ $HEADLINE_REGEX ]] &&
                    REQUEST=$(echo $trline | sed -E "s/$HEADLINE_REGEX/\1 \2/")

                CONTENT_LENGTH_REGEX='Content-Length:\s(.*?)'
                [[ "$trline" =~ $CONTENT_LENGTH_REGEX ]] &&
                    CONTENT_LENGTH=$(echo $trline | sed -E "s/$CONTENT_LENGTH_REGEX/\1/")

                HTMX_TARGET_REGEX='HX-Target:\s(.*?)'
                [[ "$trline" =~ $HTMX_TARGET_REGEX ]] &&
                    HTMX_TARGET=$(echo "$trline" | sed -E "s/$HTMX_TARGET_REGEX/\1/")
                done

  ## Read body
  if [ ! -z "$CONTENT_LENGTH" ]; then
      while read -n$CONTENT_LENGTH -t1 line; do
          trline=$(echo "$line" | tr -d '[\r\n]')
          [ -z "$trline" ] && break

          read CURR_TITLE CURR_DESC <<< $(echo "$trline" | sed -E "s|title=(.*)&description=(.*)|\1 \2|")
      done
  fi

  ## Route to the response handlers
  case "$REQUEST" in
      "GET /")   handle_GET_index ;;
      # "GET /")        handle_GET_home ;;
      "POST /todo")  handle_POST_todo ;;
      "DELETE /todo") handle_DELETE_todo ;;
      *)              handle_not_found ;;
  esac

  echo -e "$RESPONSE" > response
}

echo 'Listening on 3000...'

## Keep server running forever
while true; do
    cat response | nc -lN 3000 | handleRequest
done


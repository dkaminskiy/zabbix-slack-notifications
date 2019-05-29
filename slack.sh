#!/bin/bash

# Slack Authentication token and user name
username='Zabbix'
token="xoxp-xxxxxxxxxxxx-xxxxxxxxxxxx-xxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
emoji=":zabbix:"

## Values received by this script:
# Channel = $1 / Slack channel or user to send the message to, specified in the Zabbix web interface; "@username" or "#channel"
# Subject = $2 / subject of the message sent by Zabbix; by default, it is usually something like "(Problem|Resolved): Lack of free swap space on Zabbix server"
# Message = $3 / message body sent by Zabbix; by default, it is usually approximately 4 lines detailing the specific trigger involved
# Proxy = $4 (optional) / proxy host including port (such as "example.com:8080")

# Get the user/channel ($1), subject ($2), and message ($3)

channel="$1"
subject="$2"
message="$3"

# Enable debugging
debug="true"
debuglog="/var/tmp/slack_debug.log"


if [[ "$subject" =~ ^RESOLVED.* ]]; then
    sleep 10
    slack_answer=$(curl -s --data-urlencode "query=eventid=${subject##RESOLVED } in:${channel}" "https://slack.com/api/search.messages?token=${token}" | jq '.')
     [[ "$debug" -eq 'true,' ]] && echo `date` == eventid ${subject##RESOLVED } == slack_answer ${slack_answer} >> ${debuglog}
    if [[ `echo ${slack_answer} | jq -c '.messages.total'` -gt 0 ]]; then
        ts_message=$(echo ${slack_answer} | jq -c '.messages.matches[]' | tail -n1)
         [[ "$debug" -eq 'true' ]] && echo `date` == eventid ${subject##RESOLVED } == ts_message ${ts_message} >> ${debuglog}
        ts=$(echo ${ts_message} | jq -r '.ts')
        thread_ts=${ts}
        channel_id=$(echo ${ts_message} | jq -r '.channel.id')
         [[ "$debug" -eq 'true' ]] && echo `date` == eventid ${subject##RESOLVED } == ts ${ts} >> $debuglog
        attachments=$(echo ${ts_message} | jq '.attachments[]' | jq -c '.color = "good" | .pretext = "PROBLEM RESOLVED"')
         [[ "$debug" -eq 'true' ]] && echo ${attachments} >> /var/tmp/attachments
        update_payload="{\"channel\": \"${channel_id}\", \"ts\": \"${ts}\", \"attachments\": [${attachments}]}"
         [[ "$debug" -eq 'true' ]] && echo `date` == eventid ${subject##RESOLVED } == update_payload ${update_payload} >> ${debuglog}
        update=$(curl -X POST -H "Authorization: Bearer $token" -H "Content-type: application/json; charset=utf-8" --data "$update_payload" https://slack.com/api/chat.update)
         [[ "$debug" -eq 'true' ]] && echo `date` == eventid ${subject##RESOLVED } == update_message_response "$update" >> ${debuglog}
    fi
elif [[ "$subject" =~ ^UPDATED.* ]]; then
    sleep 5
    thread_ts=$(curl -s --data-urlencode "query=eventid=${subject##UPDATED } in:${channel}" "https://slack.com/api/search.messages?token=${token}" | jq -r '.messages.matches[].ts' | tail -n1)
else
    thread_ts=""
fi


# Use optional 4th parameter as proxy server for curl
proxy=${4-""}
if [[ "$proxy" != '' ]]; then
    proxy="-x $proxy"
fi

postMessage_payload="{\"channel\": \"${channel//\"/\\\"}\",  \
\"username\": \"${username//\"/\\\"}\", \
\"thread_ts\": \"${thread_ts}\", \
\"attachments\": [${message}], \
\"icon_emoji\": \"${emoji}\"}"

# Execute the HTTP POST request of the payload to Slack via curl, storing stdout (the response body)
return=$(curl -X POST -H "Authorization: Bearer $token" -H "Content-type: application/json; ; charset=utf-8" --data "$postMessage_payload" https://slack.com/api/chat.postMessage)
 [[ "$debug" -eq 'true' ]] && >&2 echo  `date` == return  "$return" == postMessage_payload `echo $postMessage_payload | jq '.'` >> ${debuglog}


# If the response body was not what was expected from Slack ("ok"), something went wrong so print the Slack error to stderr and exit with non-zero
if [[ ! "$return" =~ '{"ok":true,' ]]; then
    >&2 echo `date` == "$return" == $postMessage_payload
    exit 1
fi

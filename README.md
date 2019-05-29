# zabbix-slack-notifications
Notify alarms from Zabbix 4.x to Slack (previous versions not tested). The script `slack.sh` is based on [Zabbix Slack AlertScript](https://github.com/ericoc/zabbix-slack-alertscript), but almost completely rewritten.

Recovery, acknowledgements and updates from Zabbix will be attached as replies to [Slack message thread](https://slackhq.com/threaded-messaging-comes-to-slack). Recovery message from Zabbix will update initial problem message.

Installation
------------

### The script itself

This [`slack.sh` script](slack.sh) needs to be placed in the `AlertScriptsPath` directory that is specified within the Zabbix servers' configuration file (`zabbix_server.conf`) and must be executable by the user running the zabbix_server binary (usually "zabbix") on the Zabbix server:

    [root@zabbix ~]# grep AlertScriptsPath /etc/zabbix/zabbix_server.conf
    ### Option: AlertScriptsPath
    AlertScriptsPath=/usr/local/share/zabbix/alertscripts

    [root@zabbix ~]# ls -lh /usr/local/share/zabbix/alertscripts/slack.sh
    -rwxr-x--- 1 root zabbix 3811 May 28 12:52 /usr/local/share/zabbix/alertscripts/slack.sh

It also uses [`jq`](https://stedolan.github.io/jq/), so make shure that `jq` is installed.


## Slack Setup

The [Bots app](https://slack.com/apps/A0F7YS25R-bots) or other applocation  must be installed to use it API Token.
Make sure that you specify your correct Slack.com API Token (it starts witn `xoxp-` for application or `xoxb-` for bot) and edit the sender user name and icon at the top of the script:

    # Slack Authentication token and user name
    username='Zabbix'
    token="xoxp-xxxxxxxxxxxx-xxxxxxxxxxxx-xxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    emoji=":zabbix:"


## Zabbix Configuration (Slack)
Now setup new Action and Media Type.

### Media type
First go to **Administration -> Media Types**, press **Create media type**  

Choose:
Name: *Slack*
Type: *Script*
Script name: *slack.sh*

Fill **Script parameters** in the following order:
1. `{ALERT.SENDTO}`
1. `{ALERT.SUBJECT}`
1. `{ALERT.MESSAGE}`

Press *Add* to finish media type creation.

### User creation (For channel notifications)
Next step is create impersonal user:

Go to **Administration->Users**

Click **Create user**:

1. In **User** tab:
    1. **Alias**: Slack
    1. **Groups**: Make sure you add proper Group Membership so this user has the rights to see new Events (and so notify on them).
    1. **Password**: anything complex you like, you will never use it
1. **In Media tab:**

    Create New media:
      1. **Type:** Slack
      1. **Send to:** Place your Slack #channel name here for example #monitoring

### Action creation:

To Create a new action:

1. Go to **Configuration -> Action**
1. Choose **Event source: Triggers**
1. press **Create action**
1. that is to be sent to Slack.

Now place JSON object here that would represent Slack [attachment](https://api.slack.com/docs/attachments). Replace `https://zabbix-server.company.com` with proper Zabbix URL. Note though, that it is required to place all Zabbix MACROS in double brackets [[ ]], so they are properly transformed into JSON String.

Here is the example:
In **Operations** tab:

Default subject:

```
PROBLEM {EVENT.ID}
```

Default message:

```
{
    "fallback": "{HOST.NAME}:{TRIGGER.NAME}:{STATUS}",
    "color": "danger",
    "pretext": "PROBLEM",
    "author_name": "{HOST.NAME}",
    "author_link": "ssh://{HOST.NAME}",
    "title": "{TRIGGER.NAME}",
    "title_link": "https://zabbix-server.company.com/tr_events.php?triggerid={TRIGGER.ID}&eventid={EVENT.ID}",
    "text": "{ITEM.NAME1}: {ITEM.VALUE1}",
    "fields": [
        {
            "title": "Status",
            "value": "{STATUS}",
            "short": true
        },
        {
            "title": "Severity",
            "value": "{TRIGGER.SEVERITY}",
            "short": true
        },
        {
            "title": "Time",
            "value": "{EVENT.DATE} {EVENT.TIME}",
            "short": true
        },
        {
            "title": "EventID",
            "value": " {EVENT.ID}",
            "short": true
        }
    ],
    "actions": [
        {
            "text": "Update problem",
            "type": "button",
            "url": "https://zabbix-server.company.com/zabbix.php?action=acknowledge.edit&eventids[0]={EVENT.ID}"
        }
    ]
}
```

In **Recovery operations** tab:

Default subject:

```
RESOLVED {EVENT.ID}
```

Default message:

```
{
    "fallback": "{HOST.NAME}:{TRIGGER.NAME}:{STATUS}",
    "color": "good",
    "pretext": "RESOLVED",
    "author_name": "{HOST.NAME}",
    "author_link": "ssh://{HOST.NAME}",
    "title": "{TRIGGER.NAME}",
    "title_link": "https://zabbix-server.company.com/tr_events.php?triggerid={TRIGGER.ID}&eventid={EVENT.ID}",
    "text": "{ITEM.NAME1}: {ITEM.VALUE1}",
    "fields": [
        {
            "title": "Status",
            "value": "{STATUS}",
            "short": true
        },
        {
            "title": "Severity",
            "value": "{TRIGGER.SEVERITY}",
            "short": true
        },
        {
            "title": "Time",
            "value": "{EVENT.RECOVERY.DATE} {EVENT.RECOVERY.TIME}",
            "short": true
        },
        {
            "title": "EventID",
            "value": "{EVENT.ID}",
            "short": true
        }
    ]
}
```

In **Update operations** tab:

Default subject:

```
UPDATED {EVENT.ID}
```

Default message:

```
{
    "fallback": "Current problem status is {EVENT.STATUS}, acknowledged: {EVENT.ACK.STATUS}.",
    "color": "warning",
    "pretext": "UPDATED",
    "author_name": "EventID: {EVENT.ID}",
    "text": "{USER.FULLNAME} {EVENT.UPDATE.ACTION} problem at {EVENT.UPDATE.DATE} {EVENT.UPDATE.TIME}",
    "fields": [
        {
            "title": "Update message",
            "value": "{EVENT.UPDATE.MESSAGE}",
            "short": false
        },
        {
            "title": "Status",
            "value": "{EVENT.STATUS}",
            "short": true
        },
        {
            "title": "Acknowledged",
            "value": "{EVENT.ACK.STATUS}",
            "short": true
        }
    ]
}
```

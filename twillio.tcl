package require http
package require tls
package require base64

http::register https 443 [list ::tls::socket -tls1 1]

proc twilio_sms_send {account_sid auth_token from_number to_number message} {
    # Twilio API endpoint
    set url "https://api.twilio.com/2010-04-01/Accounts/$account_sid/Messages.json"

    set auth [base64::encode "$account_sid:$auth_token"]
    set body [http::formatQuery From $from_number To $to_number Body $message]

    set headers [list Authorization "Basic $auth" Content-Type "application/x-www-form-urlencoded"]
    set request [http::geturl $url -query $body -headers $headers -method POST]
    set response [http::data $request]

    http::cleanup $request

    return $response
}

proc twillio_main {argc argv} {
    if {$argc != 2} {
        puts stderr "Usage: $::argv0 <from_number> <to_number>"
        exit 1
    }

    set from_number [lindex $argv 0]
    set to_number [lindex $argv 1]

    set message [read stdin]

    if {![info exists ::env(TWILIO_ACCOUNT_SID)] || ![info exists ::env(TWILIO_AUTH)]} {
        puts stderr "Error: TWILIO_ACCOUNT_SID and TWILIO_AUTH environment variables must be set."
        exit 1
    }
    set account_sid $::env(TWILIO_ACCOUNT_SID)
    set auth_token $::env(TWILIO_AUTH)

    set response [twilio_sms_send $account_sid $auth_token $from_number $to_number $message]
    puts $response
}

if {$::argv0 eq [info script]} {
    twillio_main $::argc $::argv
}

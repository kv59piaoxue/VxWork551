# SMTP.TCL - sent mail routine
#
# Copyright 1996 Wind River Systems, Inc.
#
# modification history
# -----------------------
# 02b,05mar02,bwd  Modified SETUP to be non-tornado centric
# 02a,12jun01,j_w  Added for Tornado 2.2
# 01a,19apr96,sks  written.
#

#########
#
# smtpMailSend - Using the Tclized socket interface provided in the
# "GensockTcl.dll", this routine sends e-mail via the SMTP protocol.
# Arguments include:
#
#    sender - "From:" name of the SMTP sender
#    toList - "To:" a list containing SMTP recipent addresses
#    ccList - "Cc:" a list containing SMTP "Cc:" recipent addresses
#    bccList - "Bcc" a list containing SMTP "Bcc:" (blind) recipent addresses
#    subject - the subject line for the message
#    msgContents - the name of the file containing the message to be sent
#    server - the SMTP server name
#    attachmentList - a list of files to be attached
#

proc smtpMailSend {mailDate sender toList ccList bccList subject    \
                   msgContents server attachmentList} {
    global setupVals

    set error ""
    set msgFile ""
    set smtpSocket ""

    if {$error == ""} {
        # Connect to the SMTP server

        if {[catch {gensockConnect $server "smtp"} smtpSocket] && \
            [catch {gensockConnect $server "25"} smtpSocket]} {

            set error "unable to connect to SMTP server '$server'"
            puts "Error: $smtpSocket"
            set smtpSocket ""
        }
    }

    if {$error == ""} {
        # The first line from the SMTP server should be "220".

        if {[catch "gensockGetLine $smtpSocket" response] || \
            ![string match "220*" $response]} {

            set error "SMTP server error: $response"
        }
    }

    if {$error == ""} {
        # Fetch the name of this host to be provided to the SMTP server.

        set thisHostName [gensockGetHostname]

        # "Login" to the SMTP server and response should be "250".

        set message "HELO $thisHostName\r\n"

        if {[catch {gensockPutData $smtpSocket $message [string length $message]} \
             response] || [catch {gensockGetLine $smtpSocket} response] || \
            ![string match "250*" $response]} {

            set error "SMTP server error: $response"
         }
    }

    if {$error == ""} {
        # Announce the sender and the response should be "250".

        set message "MAIL From:<$sender>\r\n"

        if {[catch {gensockPutData $smtpSocket $message [string length $message]} \
             response] || [catch {gensockGetLine $smtpSocket} response] || \
            ![string match "250*" $response]} {

            set error "SMTP server does not recognize '$sender': $response"
        }
    }

    if {$error == ""} {
        set recipients [concat $toList $ccList $bccList]

        # Send each recipient name in 'recipients'; for each the response should be "250".

        for {set i 0} {$i < [llength $recipients]} {incr i} {
            if {$error == ""} {
                set recipient [lindex $recipients $i]
                set message "RCPT To: <$recipient>\r\n"

                if {[catch {gensockPutData $smtpSocket $message [string length $message]}\
                    response] || [catch {gensockGetLine $smtpSocket} response] || \
                    ![string match "250*" $response]} {

                    set error "SMTP server does not like '$recipient': $response"
                }
            }
        }
    }

    if {$error == ""} {
        # Announce the sender and the response should be "354".

        set message "DATA\r\n"

        if {[catch {gensockPutData $smtpSocket $message [string length $message]} \
             response] || [catch {gensockGetLine $smtpSocket} response] || \
            ![string match "354*" $response]} {

            set error "SMTP not accepting message data: $response"
        }
    }

    if {$error == ""} {
        # Put the header portion of "DATA" together.

        set header ""

        # First the "Date:" field.
        append header "Date: $mailDate\n"

        # Next the "From:" field.
        append header "From: [lindex $sender 0]\n"

        # Next the "Subject:" field.
        append header "Subject: $subject\n"

        # Next the "To:" field.
        if {[llength $toList] == "1"} {
            append header "To: [lindex $toList 0]\n"
        } else {
            append header "To: $toList\n"
        }

        # Next the "Cc:" field, if it exists.
        if {[string length $ccList]} {
            if {[llength $ccList] == "1"} {
                append header "Cc: [lindex $ccList 0]\n"
            } else {
                append header "Cc: $ccList\n"
            }
        }

        # Next the "X-Mailer:" field.
        append header "X-Mailer: <[getProdInfo name] Setup>\n"

        # Terminate the header with "\n"
        append header "\n"

        # Send the header.
        if {[catch {gensockPutDataBuffered $smtpSocket $header \
                      [string length $header]} response]} {

            set error "SMTP socket write error: '$response'"
        }
    }

    if {$error == ""} {
        # Put the body of the message together and send it.

        foreach line $msgContents {
            # If the line starts with a ".", make it start with *two* dots.

            if {[string index $line 0] == "."} {
                set line [format ".%s" $line]
            }

            # Substitute multiple line breaks ("\r") with single \r.
            regsub -all \r+ $line \r line

            set message "$line\n"
            if {[catch {gensockPutDataBuffered $smtpSocket $message \
                          [string length $message]} response]} {

                set error "SMTP socket write error: '$response'"
                break
            }
        }
    }

    if {$error == ""} {
        # UUEncode each attachment and send each one individually.

        foreach attachment $attachmentList {
            # UUEncode '$attachment'

            if [catch {uuencode $attachment \
                       [file tail $attachment]} tmpFilename] {
                set error $tmpFilename
                break
            }
            # Open the UUEncoded file.

            if [catch {open $tmpFilename r} tmpFile] {
                set error "unable to open temp. file $tmpfilename"
                break;
            }
            # Place a couple of blank lines before each attachment.

            if {[catch {gensockPutDataBuffered $smtpSocket \
                          "\r\n\r\n" 4} response]} {
                set error "SMTP socket write error: '$response'"
                break;
            }
            # Write the entire contents of the UUEncoded file to SMTP socket.

            set tmpFileContents [split [read $tmpFile] \n]

            foreach line $tmpFileContents {

                # If the line starts with a ".", make it start with *two* dots.

                if {[string index $line 0] == "."} {
                    set line [format ".%s" $line]
                }
                if [catch {gensockPutDataBuffered $smtpSocket "$line\n" \
                              [expr [string length $line] + 1]} response] {

                    set error "SMTP socket write error: '$response'"
                    break
                }
            }
            close $tmpFile

            file delete $tmpFilename

            gensockFlushBufferedData $smtpSocket
        }
    }

    if {$error == ""} {
        # Terminate the DATA section with a final "." surrounded by new-lines.

        set message "\r\n.\r\n"
        if {[catch {gensockPutDataBuffered $smtpSocket $message \
                      [string length $message]} response]} {

            set error "SMTP socket write error: '$response'"
        } {
            gensockFlushBufferedData $smtpSocket
        }
    }

    if {$error == ""} {
        # "Logoff" the SMTP server and response should be "250".

        set message "QUIT\r\n"

        if {[catch {gensockPutData $smtpSocket $message [string length $message]} \
             response] || [catch {gensockGetLine $smtpSocket} response] || \
            ![string match "250*" $response]} {

            set error "SMTP server error: $response"
        }
    }

    # Close away the message file handle.

    if {$msgFile != ""} {
        close $msgFile
    }

    # Close away the SMTP socket.

    if {$smtpSocket != ""} {
        gensockClose $smtpSocket
    }

    if {$error != ""} {
        error $error
    }
}

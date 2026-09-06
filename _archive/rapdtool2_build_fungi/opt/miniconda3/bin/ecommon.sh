#!/bin/sh

# ===========================================================================
#
#                            PUBLIC DOMAIN NOTICE
#            National Center for Biotechnology Information (NCBI)
#
#  This software/database is a "United States Government Work" under the
#  terms of the United States Copyright Act.  It was written as part of
#  the author's official duties as a United States Government employee and
#  thus cannot be copyrighted.  This software/database is freely available
#  to the public for use. The National Library of Medicine and the U.S.
#  Government do not place any restriction on its use or reproduction.
#  We would, however, appreciate having the NCBI and the author cited in
#  any work or product based on this material.
#
#  Although all reasonable efforts have been taken to ensure the accuracy
#  and reliability of the software and data, the NLM and the U.S.
#  Government do not and cannot warrant the performance or results that
#  may be obtained by using this software or data. The NLM and the U.S.
#  Government disclaim all warranties, express or implied, including
#  warranties of performance, merchantability or fitness for any particular
#  purpose.
#
# ===========================================================================
#
# File Name:  ecommon.sh
#
# Author:  Jonathan Kans, Aaron Ucko
#
# Version Creation Date:   04/17/2020
#
# ==========================================================================

version="16.2"

# initialize common flags

raw=false
dev=false
internal=false
external=false
api_key=""
immediate=false
express=false

email=""
emailr=""
emailx=""

tool="edirect"
toolr=""
toolx=""

debug=false
debugx=false

log=false
logx=false

timer=false
timerx=false

label=""
labels=""
labelx=""

basx=""
base="https://eutils.ncbi.nlm.nih.gov/entrez/eutils/"

argsConsumed=0

seconds_start=$(date "+%s")

# initialize database and identifier command-line variables

db=""

ids=""
input=""

needHistory=false

# initialize EDirect message fields

mssg=""
err=""
dbase=""
web_env=""
qry_key=""
num=0
empty=false
stp=0

rest=""

# set up colors for error report

ColorSetup() {

  if [ -z "$TERM" ] || [ ! -t 2 ]
  then
    RED=""
    BLUE=""
    BOLD=""
    FLIP=""
    INIT=""
  elif command -v tput >/dev/null
  then
    RED="$(tput setaf 1)"
    BLUE="$(tput setaf 4)"
    BOLD="$(tput bold)"
    FLIP="$(tput rev)"
    INIT="$(tput sgr0)"
  else
    # assume ANSI
    escape="$(printf '\033')"
    RED="${escape}[31m"
    BLUE="${escape}[34m"
    BOLD="${escape}[1m"
    FLIP="${escape}[7m"
    INIT="${escape}[0m"
  fi
  LOUD="${INIT}${RED}${BOLD}"
  INVT="${LOUD}${FLIP}"
}

ColorSetup

# parse ENTREZ_DIRECT, eSearchResult, eLinkResult, or ePostResult

ParseMessage() {

  mesg=$1
  objc=$2
  shift 2

  if [ -z "$mesg" ]
  then
    return 1
  fi

  object=$( echo "$mesg" | tr -d '\n' | sed -n "s|.*<$objc>\\(.*\\)</$objc>.*|\\1|p" )
  if [ -z "$object" ]
  then
    return 2
  fi

  err=$( echo "$object" | sed -n 's|.*<Error>\(.*\)</Error>.*|\1|p' )
  if [ -z "$err" ]
  then
    while [ $# -gt 0 ]
    do
      var=$1
      fld=$2
      shift 2
      value=$( echo "$object" | sed -n "s|.*<$fld>\\(.*\\)</$fld>.*|\\1|p" )
      eval "$var=\$value"
    done
  fi

  return 0
}

AdjustEmailAndTool() {

  # hierarchy is -email argument, then Email XML field, then calculated email

  if [ -n "$emailr" ]
  then
    emailx="$emailr"
  fi
  if [ -n "$emailx" ]
  then
    email="$emailx"
  fi

  if [ -n "$toolr" ]
  then
    toolx="$toolr"
  fi
  if [ -n "$toolx" ]
  then
    tool="$toolx"
  fi
}

# check for ENTREZ_DIRECT object, or list of UIDs, piped from stdin

ParseStdin() {

  if [ \( -e /dev/fd/0 -o ! -d /dev/fd \) -a ! -t 0 ]
  then
    mssg=$( cat )
    ParseMessage "$mssg" ENTREZ_DIRECT \
                  dbase Db web_env WebEnv qry_key QueryKey \
                  num Count stp Step toolx Tool emailx Email \
                  labelx Labels debugx Debug logx Log timerx Elapsed
    if [ "$?" = 2 ]
    then
      # if no ENTREZ_DIRECT message present, support passing raw UIDs via stdin
      rest="$mssg"
    else
      # future support for UIDs instantiated within message in lieu of Entrez History
      rest=$( echo "$mssg" | xtract -pattern ENTREZ_DIRECT -sep "\n" -element Id )
      if [ -z "$stp" ]
      then
        stp=1
      fi
      # hierarchy is -email argument, then Email XML field, then calculated email
      AdjustEmailAndTool
      if [ "$debugx" = "Y" ]
      then
        debug=true
      fi
      if [ "$logx" = "Y" ]
      then
        log=true
      fi
      if [ -n "$timerx" ]
      then
        timer=true
      fi
      if [ -n "$labelx" ]
      then
        labels="$labelx"
      fi
      cnt=$( echo "$mssg" | xtract -pattern ENTREZ_DIRECT -element Count )
      if [ -n "$cnt" ] && [ "$cnt" = "0" ]
      then
        empty=true
      fi
    fi
  fi
}

# process common control flags

ParseCommonArgs() {

  argsConsumed=0
  while [ $# -gt 0 ]
  do
    case "$1" in
      -dev )
        dev=true
        argsConsumed=$(($argsConsumed + 1))
        shift
        ;;
      -raw )
        raw=true
        argsConsumed=$(($argsConsumed + 1))
        shift
        ;;
      -internal | -int )
        internal=true
        argsConsumed=$(($argsConsumed + 1))
        shift
        ;;
      -external | -ext )
        external=true
        argsConsumed=$(($argsConsumed + 1))
        shift
        ;;
      -immediate )
        immediate=true
        argsConsumed=$(($argsConsumed + 1))
        shift
        ;;
      -express )
        express=true
        argsConsumed=$(($argsConsumed + 1))
        shift
        ;;
      -base )
        argsConsumed=$(($argsConsumed + 1))
        shift
        if [ $# -gt 0 ]
        then
          basx="$1"
          argsConsumed=$(($argsConsumed + 1))
          shift
        else
          echo "${INVT} ERROR: ${LOUD} Missing -base argument${INIT}" >&2
          exit 1
        fi
        ;;
      -input )
        argsConsumed=$(($argsConsumed + 1))
        shift
        if [ $# -gt 0 ]
        then
          input="$1"
          argsConsumed=$(($argsConsumed + 1))
          shift
        else
          echo "${INVT} ERROR: ${LOUD} Missing -input argument${INIT}" >&2
          exit 1
        fi
        ;;
      -web )
        argsConsumed=$(($argsConsumed + 1))
        shift
        if [ $# -gt 0 ]
        then
          web_env="$1"
          shift
        else
          echo "${INVT} ERROR: ${LOUD} Missing -web argument${INIT}" >&2
          exit 1
        fi
        ;;
      -step )
        argsConsumed=$(($argsConsumed + 1))
        shift
        if [ $# -gt 0 ]
        then
          stp="$1"
          shift
        else
          echo "${INVT} ERROR: ${LOUD} Missing -step argument${INIT}" >&2
          exit 1
        fi
        ;;
      -label )
        argsConsumed=$(($argsConsumed + 1))
        shift
        if [ $# -gt 0 ]
        then
          label="$1"
          argsConsumed=$(($argsConsumed + 1))
          shift
        else
          echo "${INVT} ERROR: ${LOUD} Missing -label argument${INIT}" >&2
          exit 1
        fi
        ;;
      -email )
        argsConsumed=$(($argsConsumed + 1))
        shift
        if [ $# -gt 0 ]
        then
          emailr="$1"
          argsConsumed=$(($argsConsumed + 1))
          shift
        else
          echo "${INVT} ERROR: ${LOUD} Missing -email argument${INIT}" >&2
          exit 1
        fi
        ;;
      -tool )
        argsConsumed=$(($argsConsumed + 1))
        shift
        if [ $# -gt 0 ]
        then
          toolr="$1"
          argsConsumed=$(($argsConsumed + 1))
          shift
        else
          echo "${INVT} ERROR: ${LOUD} Missing -tool argument${INIT}" >&2
          exit 1
        fi
        ;;
      -debug )
        argsConsumed=$(($argsConsumed + 1))
        shift
        if [ $# -gt 0 ]
        then
          if [ "$1" = "true" ]
          then
            argsConsumed=$(($argsConsumed + 1))
            shift
            debug=true
          elif [ "$1" = "false" ]
          then
            argsConsumed=$(($argsConsumed + 1))
            shift
            debug=false
          else
            debug=true
          fi
        else
          debug=true
        fi
        ;;
      -log )
        argsConsumed=$(($argsConsumed + 1))
        shift
        if [ $# -gt 0 ]
        then
          if [ "$1" = "true" ]
          then
            argsConsumed=$(($argsConsumed + 1))
            shift
            log=true
          elif [ "$1" = "false" ]
          then
            argsConsumed=$(($argsConsumed + 1))
            shift
            log=false
          else
            log=true
          fi
        else
          log=true
        fi
        ;;
      -timer )
        argsConsumed=$(($argsConsumed + 1))
        shift
        if [ $# -gt 0 ]
        then
          if [ "$1" = "true" ]
          then
            argsConsumed=$(($argsConsumed + 1))
            shift
            timer=true
          elif [ "$1" = "false" ]
          then
            argsConsumed=$(($argsConsumed + 1))
            shift
            timer=false
          else
            timer=true
          fi
        else
          timer=true
        fi
        ;;
      -version )
        echo "$version"
        exit 0
        ;;
      -newmode | -oldmode )
        argsConsumed=$(($argsConsumed + 1))
        shift
        ;;
      * )
        # allows while loop to check for multiple flags
        break
        ;;
    esac
  done
}

FinishSetup() {

  # adjust base URL address

  case "${EXTERNAL_EDIRECT}" in
    "" | [FfNn]* | 0 | [Oo][Ff][Ff] )
      ;;
    * )
      external=true
      ;;
  esac

  if [ "$external" = true ]
  then
    internal=false
  fi

  if [ -n "$basx" ]
  then
    base="$basx"
  elif [ "$dev" = true ]
  then
    base="https://dev.ncbi.nlm.nih.gov/entrez/eutils/"
  elif [ "$internal" = true ]
  then
    base="https://eutils-internal.ncbi.nlm.nih.gov/entrez/eutils/"
  fi

  # read API Key from environment variable

  if [ -n "${NCBI_API_KEY}" ]
  then
    api_key="${NCBI_API_KEY}"
  fi

  # determine contact email address

  os=$( uname -s | sed -e 's/_NT-.*$/_NT/; s/^MINGW[0-9]*/CYGWIN/' )

  if [ -n "${EMAIL}" ]
  then
    email="${EMAIL}"
  else
    # Failing that, try to combine the username from USER or whoami
    # with the contents of /etc/mailname if available or the system's
    # qualified host name.  (Its containing domain may be a better
    # choice in many cases, but anyone contacting abusers can extract
    # it if necessary.)
    lhs=""
    rhs=""
    if [ -n "${USER}" ]
    then
      lhs="${USER}"
    else
      lhs=$( id -un )
    fi
    if [ -s "/etc/mailname" ]
    then
      rhs=$( cat /etc/mailname )
    else
      rhs=$( hostname -f 2>/dev/null || uname -n )
      case "$rhs" in
        *.* ) # already qualified
          ;;
        * )
          output=$( host "$rhs" 2>/dev/null )
          case "$output" in
            *.*' has address '* )
              rhs=${output% has address *}
              ;;
          esac
          ;;
      esac
    fi
    if [ -n "$lhs" ] && [ -n "$rhs" ]
    then
      # convert any spaces in user name to underscores
      lhs=$( echo "$lhs" | sed -e 's/ /_/g' )
      email="${lhs}@${rhs}"
    fi
  fi

  # -email argument overrides calculated email, and Email XML field, if read later

  AdjustEmailAndTool
}

# prints query command with double quotes around multi-word arguments

PrintQuery() {

  if printf "%q" >/dev/null 2>&1
  then
    fmt="%q"
  else
    fmt="%s"
  fi
  dlm=""
  for elm in "$@"
  do
    raw="$elm"
    num=$( printf "%s" "$elm" | wc -w | tr -cd 0-9 )
    [ "$fmt" = "%s" ] || elm=$( printf "$fmt" "$elm" )
    case "$elm:$num:$fmt" in
      *[^\\][\'\"]:*:%q )
        ;;
      *:1:* )
        elm=$( printf "%s" "$raw" | LC_ALL=C sed -e 's/\([]!-*<>?[\\]\)/\\\1/g' )
        ;;
      *:%q )
        elm="\"$( printf "%s" "$elm" | sed -e 's/\\\([^\\"`$]\)/\1/g' )\""
        ;;
      * )
        elm="\"$( printf "%s" "$raw" | sed -e 's/\([\\"`$]\)/\\\1/g' )\""
        ;;
    esac
    printf "$dlm%s" "$elm"
    dlm=" "
  done >&2
  printf "\n" >&2
}

# three attempts for EUtils requests

ErrorHead() {

  wrn="$1"
  whn="$2"

  printf "${INVT} ${wrn}: ${LOUD} FAILURE ( $whn )${INIT}\n" >&2
  # display original command in blue letters
  printf "${BLUE}" >&2
}

ErrorTail() {

  msg="$1"
  whc="$2"

  printf "${INIT}" >&2
  # display reformatted result in red letters
  printf "${RED}${msg}${INIT}\n" >&2
  if [ "$goOn" = true ]
  then
    printf "${BLUE}${whc} ATTEMPT" >&2
  else
    printf "${BLUE}QUERY FAILURE" >&2
  fi
  printf "${INIT}\n" >&2
}

RequestWithRetry() {

  tries=3
  goOn=true
  when=$( date )

  # execute query
  res=$( "$@" )

  warn="WARNING"
  whch="SECOND"
  while [ "$goOn" = true ]
  do
    tries=$(( $tries - 1 ))
    if [ "$tries" -lt 1 ]
    then
      goOn=false
      warn="ERROR"
    fi
    case "$res" in
      "" )
        # empty result
        ErrorHead "$warn" "$when"
        PrintQuery "$@"
        ErrorTail "EMPTY RESULT" "$whch"
        sleep 1
        when=$( date )
        # retry query
        res=$( "$@" )
        ;;
      *\<eFetchResult\>* | *\<eSummaryResult\>*  | *\<eSearchResult\>*  | *\<eLinkResult\>* | *\<ePostResult\>* | *\<eInfoResult\>* )
        case "$res" in
          *\<ERROR\>* )
            ref=$( echo "$res" | transmute -format indent -doctype "" )
            ErrorHead "$warn" "$when"
            PrintQuery "$@"
            if [ "$goOn" = true ]
            then
              # asterisk prints entire selected XML subregion
              ref=$( echo "$res" | xtract -pattern ERROR -element "*" )
            fi
            ErrorTail "$ref" "$whch"
            sleep 1
            when=$( date )
            # retry query
            res=$( "$@" )
            ;;
          *\<error\>* )
            ref=$( echo "$res" | transmute -format indent -doctype "" )
            ErrorHead "$warn" "$when"
            PrintQuery "$@"
            if [ "$goOn" = true ]
            then
              # asterisk prints entire selected XML subregion
              ref=$( echo "$res" | xtract -pattern error -element "*" )
            fi
            ErrorTail "$ref" "$whch"
            sleep 1
            when=$( date )
            # retry query
            res=$( "$@" )
            ;;
          *\<ErrorList\>* )
            ref=$( echo "$res" | transmute -format indent -doctype "" )
            # question mark prints names of heterogeneous child objects
            errs=$( echo "$res" | xtract -pattern "ErrorList/*" -element "?" )
            if [ -n "$errs" ] && [ "$errs" = "PhraseNotFound" ]
            then
              goOn=false
            else
              ErrorHead "$warn" "$when"
              PrintQuery "$@"
              if [ "$goOn" = true ]
              then
                # reconstruct indented ErrorList XML
                ref=$( echo "$res" | xtract -head "<ErrorList>" -tail "<ErrorList>" \
                       -pattern "ErrorList/*" -pfx "  " -element "*" )
              fi
              ErrorTail "$ref" "$whch"
              sleep 1
              when=$( date )
              # retry query
              res=$( "$@" )
            fi
            ;;
          *\"error\":* )
            ref=$( echo "$res" | transmute -format indent -doctype "" )
            ErrorHead "$warn" "$when"
            PrintQuery "$@"
            ErrorTail "$ref" "$whch"
            sleep 1
            when=$( date )
            # retry query
            res=$( "$@" )
            ;;
          *"<DocumentSummarySet status=\"OK\"><!--"* )
            # 'DocSum Backend failed' message embedded in comment
            ErrorHead "$warn" "$when"
            PrintQuery "$@"
            ErrorTail "$res" "$whch"
            sleep 1
            when=$( date )
            # retry query
            res=$( "$@" )
            ;;
          * )
            # success - no error message detected
            goOn=false
            ;;
        esac
        ;;
      *"<DocumentSummarySet status=\"OK\"><!--"* )
        # docsum with comment not surrounded by wrapper
        ErrorHead "$warn" "$when"
        PrintQuery "$@"
        ErrorTail "$res" "$whch"
        sleep 1
        when=$( date )
        # retry query
        res=$( "$@" )
        ;;
      * )
        # success for non-structured or non-EUtils-XML result
        goOn=false
        ;;
    esac
    whch="LAST"
  done

  # use printf percent-s instead of echo to prevent unwanted evaluation of backslash
  printf "%s\n" "$res" | sed -e '${/^$/d;}'
}

# optionally prints command, then executes it with retry on failure

RunWithLogging() {

  if [ "$debug" = true ]
  then
    PrintQuery "$@"
  fi

  RequestWithRetry "$@"
}

# helpers for constructing argument arrays

AddIfNotEmpty() {

  if [ -n "$2" ]
  then
    ky=$1
    vl=$2
    shift 2
    "$@" "$ky" "$vl"
  else
    shift 2
    "$@"
  fi
}

FlagIfNotEmpty() {

  if [ -n "$2" ] && [ "$2" = true ]
  then
    ky=$1
    shift 2
    "$@" "$ky"
  else
    shift 2
    "$@"
  fi
}

# helper function adds common tracking arguments

RunWithCommonArgs() {

  AddIfNotEmpty -api_key "$api_key" \
  AddIfNotEmpty -tool "$tool" \
  AddIfNotEmpty -edirect "$version" \
  AddIfNotEmpty -edirect_os "$os" \
  AddIfNotEmpty -email "$email" \
  RunWithLogging "$@"
}

# break Entrez history server requests into chunks

GenerateHistoryChunks() {

  chnk="$1"
  minn="$2"
  maxx="$3"

  if [ "$minn" -gt 0 ]
  then
    minn=$(( $minn - 1 ))
  fi
  if [ "$maxx" -eq 0 ]
  then
    maxx="$num"
  fi

  fr="$minn"

  while [ "$fr" -lt "$maxx" ]
  do
    to=$(( $fr + $chnk ))
    if [ "$to" -gt "$maxx" ]
    then
      chnk=$(( $maxx - $fr ))
    fi
    echo "$fr" "$chnk"
    fr=$(( $fr + $chnk ))
  done
}

# return UID list from specified source or Entrez history server

GenerateUidList() {

  if [ "$needHistory" = true ]
  then
    dbsx="$1"
    chunk=25000
    if [ "$dbsx" = "pubmed" ]
    then
      chunk=10000
    fi
    GenerateHistoryChunks "$chunk" 0 0 |
    while read fr chnk
    do
      RunWithCommonArgs nquire -get "$base" esearch.fcgi \
        -query_key "$qry_key" -WebEnv "$web_env" -retstart "$fr" -retmax "$chnk" \
        -db "$dbsx" -rettype uilist -retmode text |
      xtract -pattern Id -element Id
    done
  else
    # otherwise obtain raw UIDs from available sources
    if [ -n "$ids" ]
    then
      echo "$ids"
    elif [ -n "$rest" ]
    then
      echo "$rest"
    elif [ -n "$input" ]
    then
      cat "$input"
    fi |
    # accn-at-a-time without case transformation
    sed 's/[^a-zA-Z0-9_.]/ /g; s/^ *//' |
    fmt -w 1 |
    grep '.'
  fi
}

# special case accession to UID lookup functions

ExtractUIDs() {

  if [ "$needHistory" = false ]
  then
    GenerateUidList "$dbase" |
    while read uid
    do
      notInteger=$( echo "$uid" | sed -e 's/[0-9.]//g' )
      if [ -z "$notInteger" ]
      then
        echo "$uid"
      fi
    done
  fi
}

ExtractAccns() {

  if [ "$needHistory" = false ]
  then
    GenerateUidList "$dbase" |
    while read uid
    do
      notInteger=$( echo "$uid" | sed -e 's/[0-9.]//g' )
      if [ -n "$notInteger" ]
      then
        echo "$uid"
      fi
    done
  fi
}

ExtractPMCIds() {

  if [ "$needHistory" = false ]
  then
    GenerateUidList "$dbase" |
    while read uid
    do
      case "$uid" in
        PMC* )
          echo "$uid" | sed -e 's/^PMC//g'
          ;;
        pmc* )
          echo "$uid" | sed -e 's/^pmc//g'
          ;;
        * )
          echo "$uid"
          ;;
      esac
    done
  fi
}

ExtractNucUids() {

  # argument value: 1 = PACC, 2 = ACCN, 3 = integer and accession
  kind="$1"

  while read uid
  do
    case "$uid" in
      *00000000 )
        notInteger=$( echo "$uid" | sed -e 's/[0-9.]//g' )
        if [ -n "$notInteger" ]
        then
          if [ "$kind" -eq 1 ]
          then
            echo "$uid"
          fi
        else
          if [ "$kind" -eq 3 ]
          then
            echo "$uid"
          fi
        fi
        ;;
      *0000000 )
        notInteger=$( echo "$uid" | sed -e 's/[0-9.]//g' )
        if [ -n "$notInteger" ]
        then
          if [ "$kind" -eq 2 ]
          then
            echo "$uid"
          fi
        else
          if [ "$kind" -eq 3 ]
          then
            echo "$uid"
          fi
        fi
        ;;
      * )
        if [ "$kind" -eq 3 ]
        then
          echo "$uid"
        fi
        ;;
    esac
  done
}

ExtractPDB() {

  if [ "$needHistory" = false ]
  then
    GenerateUidList "$dbase" |
    while read uid
    do
      case "$uid" in
        [0-9][0-9][0-9][0-9] )
          # Four-digit UID
          # peel off first to avoid mistaking for a chainless PDB ID
          ;;
        [0-9][0-9A-Za-z][0-9A-Za-z][0-9A-Za-z] | \
        [0-9][0-9A-Za-z][0-9A-Za-z][0-9A-Za-z]_[A-Za-z]* )
          # PDB ID
          # properly case-sensitive only when untagged
          echo "$uid"
          ;;
      esac
    done
  fi
}

ExtractNonPDB() {

  if [ "$needHistory" = false ]
  then
    GenerateUidList "$dbase" |
    while read uid
    do
      case "$uid" in
        [0-9][0-9][0-9][0-9] )
          # Four-digit UID
          # peel off first to avoid mistaking for a chainless PDB ID
          echo "$uid"
          ;;
        [0-9][0-9A-Za-z][0-9A-Za-z][0-9A-Za-z] | \
        [0-9][0-9A-Za-z][0-9A-Za-z][0-9A-Za-z]_[A-Za-z]* )
          # PDB ID, skip
          ;;
        *[A-Za-z]* )
          # accessions are already handled
          echo "$uid"
          ;;
        * )
          echo "$uid"
          ;;
      esac
    done
  fi
}

PrepareAccnQuery() {

  while read uid
  do
    echo "$uid+[$1]"
  done |
  join-into-groups-of "$2" |
  sed -e 's/,/ OR /g' |
  tr '+' ' '
}

RunAccnSearch() {

  while read qry
  do
    nquire -get "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi" \
      -db "$dbase" -term "$qry" -retmax "$1" < /dev/null |
    xtract -pattern eSearchResult -sep "\n" -element IdList/Id
  done
}

PreparePDBQuery() {

  while read uid
  do
    echo "$uid"
  done |
  join-into-groups-of 10000 |
  sed -e 's/,/ OR /g'
}

PrepareSnpQuery() {

  while read uid
  do
    case "$uid" in
      rs* )
        echo "$uid+[RS]"
        ;;
      ss* )
        echo "$uid+[SS]"
        ;;
    esac
  done |
  join-into-groups-of 10000 |
  sed -e 's/,/ OR /g' |
  tr '+' ' '
}

LookupSpecialAccessions() {

  if [ "$needHistory" = false ]
  then
    fld=""
    case "$dbase" in
      assembly | annotinfo )
        fld="ASAC"
        ;;
      biosample | biosystems | cdd | dbvar | ipg | medgen | proteinclusters | seqannot | sra )
        fld="ACCN"
        ;;
      bioproject | genome )
        fld="PRJA"
        ;;
      books )
        fld="AID"
        ;;
      clinvar )
        fld="VACC"
        ;;
      gds )
        fld="ALL"
        ;;
      geoprofiles )
        fld="NAME"
        ;;
      gtr )
        fld="GTRACC"
        ;;
      mesh )
        fld="MHUI"
        ;;
      pcsubstance )
        fld="SRID"
        ;;
      pmc* )
        ids=$( ExtractPMCIds | fmt -w 1 | sort -n | uniq )
        ;;
      nuc* )
        nucUidList=$( GenerateUidList "$dbase" )
        anyNonInteger=$( echo "$nucUidList" | sed -e 's/[0-9.]//g' )
        if [ -n "$anyNonInteger" ]
        then
          pacc=$( echo "$nucUidList" | ExtractNucUids "1" )
          accn=$( echo "$nucUidList" | ExtractNucUids "2" )
          lcl=$( echo "$nucUidList" | ExtractNucUids "3" )
          pacres=""
          accres=""
          if [ -n "$pacc" ]
          then
            pacres=$( echo "$pacc" |
                      PrepareAccnQuery "PACC" "100" |
                      RunAccnSearch "1000" )
          fi
          if [ -n "$accn" ]
          then
            accres=$( echo "$accn" |
                      PrepareAccnQuery "ACCN" "100" |
                      RunAccnSearch "1000" )
          fi
          if [ -n "$pacres" ] || [ -n "$accres" ]
          then
            ids=$( echo "$pacres $accres $lcl" | fmt -w 1 | sort -n | uniq )
          fi
        fi
        ;;
      protein )
        acc=$( ExtractPDB )
        lcl=$( ExtractNonPDB )
        if [ -n "$acc" ]
        then
          query=$( echo "$acc" | PreparePDBQuery "$fld" )
          rem=$( esearch -db "$dbase" -query "$query" | efetch -format uid )
          ids=$( echo "$rem $lcl" | fmt -w 1 | sort -n | uniq )
        fi
        ;;
      snp )
        acc=$( ExtractAccns )
        lcl=$( ExtractUIDs )
        if [ -n "$acc" ]
        then
          query=$( echo "$acc" | PrepareSnpQuery "$fld" )
          rem=$( esearch -db "$dbase" -query "$query" | efetch -format uid )
          ids=$( echo "$rem $lcl" | fmt -w 1 | sort -n | uniq )
        fi
        ;;
      taxonomy )
        acc=$( ExtractAccns )
        if [ -n "$acc" ]
        then
          echo "${INVT} ERROR: ${LOUD} Taxonomy database does not index sequence accession numbers${INIT}" >&2
          exit 1
        fi
        ;;
    esac
    if [ -n "$fld" ]
    then
      acc=$( ExtractAccns )
      lcl=$( ExtractUIDs )
      if [ -n "$acc" ]
      then
        newids=$( echo "$acc" |
                  PrepareAccnQuery "$fld" "1000" |
                  RunAccnSearch "10000" )
        if [ -n "$newids" ]
        then
          ids=$( echo "$newids $lcl" | fmt -w 1 | sort -n | uniq )
        fi
      fi
    fi
  fi
}

# write minimal ENTREZ_DIRECT message for intermediate processing

WriteEDirectStep() {

  dbsx="$1"
  webx="$2"
  keyx="$3"
  errx="$4"

  echo "<ENTREZ_DIRECT>"

  if [ -n "$dbsx" ]
  then
    echo "  <Db>${dbsx}</Db>"
  fi
  if [ -n "$webx" ]
  then
    echo "  <WebEnv>${webx}</WebEnv>"
  fi
  if [ -n "$keyx" ]
  then
    echo "  <QueryKey>${keyx}</QueryKey>"
  fi
  if [ -n "$errx" ]
  then
    echo "  <Error>${errx}</Error>"
  fi

  echo "</ENTREZ_DIRECT>"
}

# write ENTREZ_DIRECT data structure

WriteEDirect() {

  dbsx="$1"
  webx="$2"
  keyx="$3"
  numx="$4"
  stpx="$5"
  errx="$6"

  seconds_end=$(date "+%s")
  seconds_elapsed=$((seconds_end - seconds_start))

  echo "<ENTREZ_DIRECT>"

  if [ -n "$dbsx" ]
  then
    echo "  <Db>${dbsx}</Db>"
  fi
  if [ -n "$webx" ]
  then
    echo "  <WebEnv>${webx}</WebEnv>"
  fi
  if [ -n "$keyx" ]
  then
    echo "  <QueryKey>${keyx}</QueryKey>"
  fi
  if [ -n "$numx" ]
  then
    echo "  <Count>${numx}</Count>"
  fi

  if [ -n "$stpx" ]
  then
    # increment step value
    stpx=$(( $stpx + 1 ))
    echo "  <Step>${stpx}</Step>"
  fi
  if [ -n "$errx" ]
  then
    echo "  <Error>${errx}</Error>"
  fi
  if [ -n "$toolx" ]
  then
    echo "  <Tool>${toolx}</Tool>"
  fi
  if [ -n "$emailx" ]
  then
    echo "  <Email>${emailx}</Email>"
  fi

  if [ -n "$label" ] && [ -n "$keyx" ]
  then
    labels="<Label><Key>${label}</Key><Val>${keyx}</Val></Label>${labels}"
  fi
  if [ -n "$labels" ]
  then
    echo "  <Labels>"
    echo "$labels" |
    # xtract -pattern Label -element "*"
    xtract -pattern Label -tab "\n" \
      -fwd "    <Label>\n" -awd "\n    </Label>" \
      -pfx "      <Key>" -sfx "</Key>" -element Key \
      -pfx "      <Val>" -sfx "</Val>" -element Val
    echo "  </Labels>"
  fi

  if [ "$debug" = true ] || [ "$debugx" = "Y" ]
  then
    echo "  <Debug>Y</Debug>"
  fi
  if [ "$log" = true ] || [ "$logx" = "Y" ]
  then
    echo "  <Log>Y</Log>"
  fi

  if [ "$timer" = true ] && [ -n "$seconds_elapsed" ]
  then
    echo "  <Elapsed>${seconds_elapsed}</Elapsed>"
  fi

  echo "</ENTREZ_DIRECT>"
}

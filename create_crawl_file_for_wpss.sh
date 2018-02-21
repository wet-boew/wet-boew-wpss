#!/bin/bash
url_to_scan=$1
app_name=$2
lang=$3
len_lang=${#3}
if [ "$len_lang" == "2" ]; then
  if [ "$lang" == "en" ]; then
    lang=eng
  fi
  if [ "$lang" == "fr" ]; then
    lang=fra
  fi
fi
#set -x;
isNumeric=0
paramIsNumeric() {
  #https://stackoverflow.com/a/8743103
  isNumeric=0
  re='^[0-9]+$'
  if [[ $1 =~ $re ]]; then
    isNumeric=1;
  fi
}
valueBefore=
valueAfter=

valueAfterColon() {
  valueAfter=${1##*:}
}

valueBeforeColon() {
  #test
  beforeAndAfter=$1
  valueAfter=
  valueAfterColon $1
  len_after=${#valueAfter}
  len_beforeAndAfter=${#beforeAndAfter};
  if [ $len_beforeAndAfter -gt $len_after ] && [ $len_beforeAndAfter != 0 ]; then
    let len_before=$len_beforeAndAfter-$len_after
    let len_before=$len_before-1
    valueBefore=${beforeAndAfter:0:$len_before}
  else
    valueBefore=
    valueAfter=
    echo "exitting with error."
    echo "Error in processing before:after param , expected value pair, got $1"
    exit 1;
  fi
}
crawllimit=${4##*:}
#https://stackoverflow.com/a/3162500
# assume 1:1 where first number is crawl_depth and second number is crawllimit
isNumeric=0
paramIsNumeric $crawllimit
if [ $isNumeric == 1 ]; then
  valueAfter=
  valueBefore=
  valueBeforeColon $4
  crawl_depth=$valueBefore
  isNumeric=0
  paramIsNumeric $crawl_depth
  if [ ! $isNumeric == 1 ]; then
    crawl_depth=
    echo "crawl_depth must be an integer value."
    exit 1;
  fi
  echo ""
  echo "crawl_depth=$crawl_depth"
  echo "crawllimit=$crawllimit"
  echo ""
else
  crawllimit=
  crawl_depth=
fi


if [ -z "$5" ] && [ ! -z "$app_name" ] && [ ! -z "$url_to_scan" ] && [ ! -z "$lang" ]; then
  echo "(OPTIONAL) login params were not specified:";
  if [ ! -z "$crawllimit" ]; then
    echo "EXAMPLE1: create_crawl_file_for_wpss.sh $url_to_scan $app_name $lang $crawl_depth:$crawllimit $url_to_scan/user/login $url_to_scan/user/logout username:password username-field-name:password-field-name formID";
    echo "EXAMPLE2: create_crawl_file_for_wpss.sh http://drupal.test example-app $lang $crawl_depth:$crawllimit http://drupal.test/user/login http://drupal.test/user/logout username:password name:pass user-login";
    echo ""
  else
    echo "EXAMPLE1: create_crawl_file_for_wpss.sh $url_to_scan $app_name $lang $url_to_scan/user/login $url_to_scan/user/logout username:password username-field-name:password-field-name formID";
    echo "EXAMPLE2: create_crawl_file_for_wpss.sh http://drupal.test example-app $lang http://drupal.test/user/login http://drupal.test/user/logout username:password name:pass user-login";
  fi
else
  if [ -z "$crawllimit" ]; then
    echo "";
    echo "(OPTIONAL) crawl_limit was not specified.  To specify crawl_depth and crawllimit AND login params:"
    echo "";
    echo "EXAMPLE1: create_crawl_file_for_wpss.sh http://app.test app_name eng 1:1 http://app.test/user/login http://app.test/user/logout username:password username-field-name:password-field-name formID";
    echo "EXAMPLE2: create_crawl_file_for_wpss.sh http://drupal.test example-app eng 1:1 http://drupal.test/user/login http://drupal.test/user/logout username:password name:pass user-login";
    echo "";
    echo "(note) crawl_depth and crawllimit separated by a colon ex: 1:1";
    echo "";
  fi
fi

if [ -z "$url_to_scan" ] || [ -z "$app_name" ] || [ -z "$lang" ]; then
  echo ""
  if [ -z "$url_to_scan" ]; then
    echo "need a param for url, specify an url to scan";
  fi
  if [ -z "$lang" ]; then
    echo "";
    echo "need a param for lang , example: eng or fra";
  fi
  if [ -z "$app_name" ]; then
    echo "";
    echo "need a param for app_name , example: testapp";
  fi
  echo ""
  echo "How to use this script:"
  echo "example: create_crawl_file_for_wpss.sh https://jolstad.en.testapp testapp eng";
  echo "example: create_crawl_file_for_wpss.sh https://jolstad.en.testapp testapp eng 1:1";
  echo "the optional numerical parameters are for crawl_depth and crawllimit separated by a colon ex: 1:1";
  exit 1;
else
  if [ -e crawl/$app_name ]; then
    rm crawl/$app_name
  fi
  echo "site_url_$lang $url_to_scan" >> crawl/$app_name
  echo "output_file /opt/wpss/wpss_scan_results/$app_name" >> crawl/$app_name
  if [ ! -z "$4" ] && [ -z "$crawl_depth" ]; then
    if [ -e crawl/${app_name}_logincreds ]; then
      rm crawl/${app_name}_logincreds
    fi
    if [ "${lang:0:2}" == "en" ] && [ ! -z "$4" ]; then
      echo "loginpagee $4" >> crawl/${app_name}
      echo "logoutpagee $5" >> crawl/${app_name}
    elif [ "${lang:0:2}" == "fr" ] && [ ! -z "$4" ]; then
      echo "loginpagef $4" >> crawl/${app_name}
      echo "logoutpagef $5" >> crawl/${app_name}
    fi
    #now do username:password
    #https://stackoverflow.com/a/3162500
    valueBefore=
    valueAfter=
    password=${6##*:}
    valueBeforeColon $6
    username=$valueBefore
    echo "username $username" >> crawl/${app_name}_logincreds
    echo "password $password" >> crawl/${app_name}_logincreds
    #now do user field-username-name:field-password-name
    valueBefore=
    valueAfter=
    valueBeforeColon $7
    if [ -z "$valueBefore" ]; then
      echo "incorrect user field name, this is found in the login form input field at ${loginpagee}${loginpagef} for username."
      exit 1;
    else
      username_fieldname=$valueBefore
      echo "login $username_fieldname $username" >> crawl/$app_name
      password_fieldname=$valueAfter
      echo "login $password_fieldname $password" >> crawl/$app_name
      valueAfter=
      valueBefore=
    fi
    echo "loginformname $8" >> crawl/${app_name}
  elif [ ! -z "$5" ] && [ ! -z "$crawl_depth" ]; then
    if [ -e crawl/${app_name}_logincreds ]; then
      rm crawl/${app_name}_logincreds
    fi
    if [ "${lang:0:2}" == "en" ]; then
      echo "loginpagee $5" >> crawl/${app_name}
      echo "logoutpagee $6" >> crawl/${app_name}
    elif [ "${lang:0:2}" == "fr" ]; then
      echo "loginpagef $5" >> crawl/${app_name}
      echo "logoutpagef $6" >> crawl/${app_name}
    fi
    #now do username:password
    #https://stackoverflow.com/a/3162500
    valueBefore=
    valueAfter=
    password=${7##*:}
    valueBeforeColon $7
    username=$valueBefore
    echo "username $username" >> crawl/${app_name}_logincreds
    echo "password $password" >> crawl/${app_name}_logincreds
    valueBefore=
    valueBeforeColon $8
    if [ -z "$valueBefore" ]; then
      echo "incorrect user field name, this is found in the login form input field at ${loginpagee}${loginpagef} for username."
      exit 1;
    else
      username_fieldname=$valueBefore
      echo "login $username_fieldname $username" >> crawl/$app_name
      password_fieldname=$valueAfter
      echo "login $password_fieldname $password" >> crawl/$app_name
      valueAfter=
      valueBefore=
    fi
    echo "loginformname $9" >> crawl/${app_name}
  fi
  if [ ! -z "$crawl_depth" ]; then
    echo "crawl_depth $crawl_depth" >> crawl/$app_name
  fi
  if [ ! -z "$crawl_depth" ]; then
    echo "crawllimit $crawllimit" >> crawl/$app_name
  fi
  mkdir -p /opt/wpss/wpss_scan_results
  if [ -z "$6" ]; then
    wpss_tool_cli.pl -c /opt/wpss/crawl/$app_name
  else
    wpss_tool_cli.pl -c /opt/wpss/crawl/$app_name /opt/wpss/crawl/${app_name}_logincreds
  fi
  #site_url_eng https://jolstad.en.testapp/
  #output_file /opt/wpss/wpss_scan_results/jolstad/BaS
fi



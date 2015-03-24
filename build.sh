#!/bin/bash -x

function is_executed_in_develenv(){
   [[ -z $JENKINS_HOME ]] && echo "false" || echo "true"
}

function build(){
   echo "[INFO] Compiling and run unit testing..."
   local selenium_grid_properties=""
   if [ "$SELENIUM_HOST" != "" ]; then
      selenium_grid_properties="-Dselenium.host=$SELENIUM_HOST \
        -Dselenium.port=80"
   fi
   mvn clean install -DargLine="$selenium_grid_properties \
        -Dselenium.browser.name=$WEB_BROWSER \
        -DurlServer=$APP_URL"
}

function deploy(){
   echo "[INFO] Deploy in nexus..."
   # The tests are calculated in build function
   mvn deploy rpm:rpm -Dmaven.test.skip=true
}

function docs(){
   echo "[INFO] Generating site..."
   mvn site:site site:deploy
}

function metrics(){
   echo "[INFO] Generating source code metrics..."
   #Workaround to sonar
   rm -Rf target/reports/jacoco/
   mvn sonar:sonar -Dsonar.dynamicAnalysis=reuseReports -Dsonar.core.codeCoveragePlugin=cobertura
   error_code=$?
   dp_cloc.sh
   return $error_code
}

SELENIUM_HOST=""
WEB_BROWSER=firefox
APP_URL=http://localhost:8181/web-calculator

if [[ "$(is_executed_in_develenv)" == "true" ]]; then
   DEVELENV_SERVER="$(echo $JENKINS_URL|sed s:'/jenkins.*':'':g|sed s:'/hudson.*':'':g)"
   SELENIUM_GRID_CONSOLE=$DEVELENV_SERVER/grid/console
   grid_console_status=$(curl -s -o /dev/null -w '%{http_code}' $DEVELENV_SERVER/grid/console)
   if [ "$grid_console_status" != "200" ]; then
      echo "[ERROR] Unable to access to selenim grid console[$SELENIUM_GRID_CONSOLE]"
      echo "[ERROR] Review /var/log/develenv/selenium or $DEVELENV_SERVER/logs"
      exit 1
   fi
   SELENIUM_HOST=$(echo $DEVELENV_SERVER|cut -d'/' -f3)
   APP_URL=$DEVELENV_SERVER:8181/web-calculator
   if [ "$browser" != "" ]; then
      WEB_BROWSER=$browser
   fi
   # The web-calculator's jenkins jobs will do deploy,docs and extrac metrics
   if [[ "$JOB_NAME" == "web-calculator" ]]; then
      build && deploy && docs && metrics
   else
      build
   fi
else
   build
fi
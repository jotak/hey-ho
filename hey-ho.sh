#!/bin/bash

############################################################
# Help                                                     #
############################################################
show_help()
{
   echo "Deploys any number of Pods sending load to each other, for a given amount of time."
   echo
   echo "Syntax: hey-ho [options]"
   echo "Options:"
   echo "-c         Cleanup namespaces and exit. Combine with -n to set the number of namespaces to delete."
   echo "-n X       Number of namespaces. Default: 1"
   echo "-d X       Number of deployments per namespace. Default: 5"
   echo "-r X       Number of replicas per deployment. Default: 2"
   echo "-w X       Number of workers per replica. Default: 50"
   echo "-z time    Load sending duration, e.g. 10s or 3m. Default: 30s"
   echo "-q qps     Rate limit, in query per seconds. 0 means no limit. Default: 200"
   echo "-p         Predictable mode (no random target assignment). Default: disabled"
   echo "-y         Non-interactive mode, reply 'yes' to prompt. Default: disabled"
   echo "-b         Bip when results are received"
   echo "-f         Fake / dry run. Default: disabled"
   echo "-h         Print this help."
   echo
}

delete_namespaces () {
  for (( n=0; n<$1; n++ ))
  do
    kubectl delete namespace gallery$n
  done
}

namespaces=1
deployments=5
replicas=2
workers=50
duration=30s
qps=200

while getopts "h?cn:d:r:w:z:q:pybf" opt; do
  case $opt in
    h|\?)
      show_help
      exit 0
      ;;
    c) cleanup=1 ;;
    n) namespaces=$(( OPTARG )) ;;
    d) deployments=$(( OPTARG )) ;;
    r) replicas=$(( OPTARG )) ;;
    w) workers=$(( OPTARG )) ;;
    z) duration=$OPTARG ;;
    q) qps=$(( OPTARG )) ;;
    p) predictable=1 ;;
    y) yes=1 ;;
    b) bipcmd="printf \\a" ;;
    f) fake=1 ;;
    *) echo 'error' >&2
       exit 1
  esac
done

if [[ $cleanup -eq 1 ]]; then
  delete_namespaces ${namespaces}
  exit 0
fi

next_target=0
nb_targets=$(($deployments * $namespaces))

inc_target () {
  if [[ ${predictable} -eq 1 ]]; then
    next_target=$((($next_target+1) % $nb_targets))
  else
    next_target=$(($RANDOM % $nb_targets))
  fi
}

target () {
  ns=$(($next_target / $deployments))
  dep=$(($next_target % $deployments))
  echo "http://hey-ho-${dep}.gallery${ns}:8080"
}

export REPLICAS=${replicas}
HEY_ARGS="-c ${workers} -z ${duration}"
if [[ ${qps} -ne 0 ]]; then
  HEY_ARGS+=" -q ${qps}"
fi

echo "🪆 You asked creation of a total of ${namespaces} namespaces, $(( namespaces * deployments )) deployments, $(( namespaces * deployments * replicas )) pods, $(( namespaces * deployments * replicas * workers )) workers."
echo " ⏳ Running for ${duration}"
if [[ ${qps} -ne 0 ]]; then
  if [[ ${qps} -le 50 ]]; then
    animal="🐌"
  elif [[ ${qps} -le 100 ]]; then
    animal="🐈"
  elif [[ ${qps} -le 500 ]]; then
    animal="🐪"
  else
    animal="🐎"
  fi
  echo " ${animal} Rate-limited at ${qps} queries per second"
else
  echo " ⚡ Without any rate-limit"
fi
if [[ ${predictable} -eq 1 ]]; then
  echo " 🤖 Peers assigned in a predictable way"
else
  echo " 🧞 Peers assigned randomly"
fi
if [[ "${bipcmd}" == "" ]]; then
  echo " 🔇 No bip when finished"
else
  echo " 🔊 Bip when finished"
fi
echo "------"
echo " 📟 'hey' command arguments: ${HEY_ARGS}"
echo "------"
if [[ ${fake} -eq 1 ]]; then
  echo " 🎠 Running in dry-run mode"
else
  echo " 🧟 Running for real!"
fi
echo "------"
echo ""

if [[ ${yes} -ne 1 ]]; then
  read -p "🚀 Continue? [y/N] " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]
  then
      exit 0
  fi
fi
echo ""


# generate deployments
echo "Deploying pods"
for (( n=0; n<$namespaces; n++ ))
do
  export NAMESPACE="gallery$n"
  if [[ $fake -ne 1 ]]; then
    kubectl create namespace ${NAMESPACE}
  fi
  for (( d=0; d<$deployments; d++ )); do
    export NAME="hey-ho-$d"
    if [[ $fake -eq 1 ]]; then
      echo "DRY RUN - output:"
      echo ""
      envsubst < ./hey-ho-tpl.yaml
      echo "---"
    else
      envsubst < ./hey-ho-tpl.yaml | kubectl apply -n ${NAMESPACE} -f -
    fi
  done
done

# wait until they're all ready
echo "Waiting pods availability..."
for (( n=0; n<$namespaces; n++ )); do
  NAMESPACE="gallery$n"
  for (( d=0; d<$deployments; d++ )); do
    NAME="hey-ho-$d"
    if [[ $fake -eq 1 ]]; then
      echo "  kubectl wait deployment ${NAME} -n ${NAMESPACE} --for condition=Available=True"
    else
      kubectl wait deployment ${NAME} -n ${NAMESPACE} --for condition=Available=True
    fi
  done
done

# start sending load
echo "Start sending load"
for (( n=0; n<$namespaces; n++ )); do
  NAMESPACE="gallery$n"
  for (( d=0; d<$deployments; d++ )); do
    NAME="hey-ho-$d"
    inc_target
    TARGET=$(target)
    if [[ $fake -eq 1 ]]; then
      echo "  pods= kubectl get pods -n ${NAMESPACE} -l app=${NAME} --no-headers -o custom-columns=':metadata.name' "
      echo "  For each pod, run:"
      echo "    { kubectl -n ${NAMESPACE} exec <pod name> -- /tmp/hey ${HEY_ARGS} ${TARGET}; date; ${bipcmd}; } &"
    else
      pods=`kubectl get pods -n ${NAMESPACE} -l app=${NAME} --no-headers -o custom-columns=":metadata.name"`
      for pod in $pods; do
        echo "Starting hey on pod ${pod}"
        { kubectl -n ${NAMESPACE} exec ${pod} -- /tmp/hey ${HEY_ARGS} ${TARGET}; date; ${bipcmd}; } &
      done
    fi
  done
done
echo "It's `date`, come back in ${duration} for results."

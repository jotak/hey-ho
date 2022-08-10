# Hey-Ho

A simple script on top of [Rakyll's Hey](https://github.com/rakyll/hey) that deploys any number of Pods sending load to each other, for a given amount of time.

## Run

You need to have a kube cluster running (the script uses `kubectl`).

Just run:

```bash
./hey-ho.sh
```

Options:

```
-c         Cleanup namespaces and exit. Combine with -n to set the number of namespaces to delete.
-n X       Number of namespaces. Default: 1
-d X       Number of deployments per namespace. Default: 5
-r X       Number of replicas per deployment. Default: 2
-w X       Number of workers per replica. Default: 50
-z time    Load sending duration, e.g. 10s or 3m. Default: 30s
-q qps     Rate limit, in query per seconds. 0 means no limit. Default: 200
-p         Predictable mode (no random target assignment). Default: disabled
-y         Non-interactive mode, reply 'yes' to prompt. Default: disabled
-f         Fake / dry run. Default: disabled
-h         Print this help.
```


# Istio Quitter

In the Istio Service Mesh with Kubernetes, a sidecar is injected into containers to communicate with other services in the service mesh.  This sidecar and its primary process will not complete or terminate unless the `quitquitquit` endpoint is called or a SIGTERM is received.  When running CronJobs or utilizing operators that generate pods, this can create an issue where the pod never terminates.  To solve this problem, we create another sidecar to watch for the primary process to complete, and then send the signal to the `quitquitquit` endpoint.  In this sidecar, we use 3 primary programs:

1. `bash` - for a shell to run some basic scripts
1. `procps` - to check for a running process with `pgrep`
1. `curl` - to call the `quitquitquit` endpoint

Our primary, and current, use-case is for Airflow Kubernetes Executors not terminating.  To attach the the pod we use the python kubernetes client library and create a `executor_config` like the following:

```python
kube_exec_istio_quit = {
    "pod_override": k8s.V1Pod(
        spec=k8s.V1PodSpec(
            share_process_namespace=True,
            containers=[
                k8s.V1Container(
                    name="istio-quitter",
                    image="istio-quitter",
                    args=['-c',
                          'while pgrep airflow >/dev/null; do sleep 10; done; curl -s -f -XPOST http://127.0.0.1:15020/quitquitquit;'],
                    command=["/bin/sh"]
                ),
            ]
        )
    )
}
```

The primary control loop is in the `args` section, but is a bash while-loop (`while pgrep airflow >/dev/null; do sleep 10; done;`) that runs as long as the `airflow` process is found. Once the `airflow` process is complete, it will send the curl request to the Istio endpoint.  

> For the IstioQuitter image to watch the airflow process, you need to have `share_process_namespace` enabled.

> NOTE: This changes with the [ambient mesh](https://istio.io/v1.16/blog/2022/introducing-ambient-mesh/) that was introduced in v1.16 and with [native sidecar support in Kubernetes 1.28](https://kubernetes.io/blog/2023/08/25/native-sidecar-containers/)

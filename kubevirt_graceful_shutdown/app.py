from collections import namedtuple
from typing import List
import time

from kubernetes import client, config

VmInfo = namedtuple('VmInfo', 'namespace name phase')


def list_vms() -> List[VmInfo]:
    coreapi = client.CoreV1Api()
    crdapi = client.CustomObjectsApi()

    results = []

    namespaces = coreapi.list_namespace()
    for ns in namespaces.items:
        vmis = crdapi.list_namespaced_custom_object(
            group='kubevirt.io',
            version='v1',
            namespace=ns.metadata.name,
            plural='virtualmachineinstances'
        )
        for vmi in vmis['items']:
            results.append(
                VmInfo(ns.metadata.name, vmi['metadata']['name'], vmi['status']['phase']))
    return results


def stop_vm(vm: VmInfo):
    api = client.ApiClient()
    resource_path = f'/apis/subresources.kubevirt.io/v1alpha3/namespaces/{vm.namespace}/virtualmachines/{vm.name}/stop'
    body = dict(gracePeriod=120)

    auth_settings = ['BearerToken']

    api.call_api(
        resource_path, 'PUT',
        body=body,
        auth_settings=auth_settings,
    )


def wait_until_stopped(gracePeriod: int = 200):
    def all_stopped():
        return len(list_vms()) == 0
    
    timeout = time.time() + gracePeriod
    while True:
        curr = time.time()
        if curr > timeout:
            print('timed out waiting for vms to stop')
            return
        if all_stopped():
            return
        time.sleep(5)


def main():
    config.load_kube_config()
    vms = list_vms()
    for vm in vms:
        print(f'stopping {vm.name}')
        stop_vm(vm)
    wait_until_stopped()


if __name__ == '__main__':
    main()

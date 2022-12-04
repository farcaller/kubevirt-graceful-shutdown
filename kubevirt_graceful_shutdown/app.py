from collections import namedtuple
from typing import List
import time
import sys

from kubernetes import client, config

VmInfo = namedtuple('VmInfo', 'namespace name status')


def list_vms() -> List[VmInfo]:
    coreapi = client.CoreV1Api()
    crdapi = client.CustomObjectsApi()

    results = []

    namespaces = coreapi.list_namespace()
    for ns in namespaces.items:
        vms = crdapi.list_namespaced_custom_object(
            group='kubevirt.io',
            version='v1',
            namespace=ns.metadata.name,
            plural='virtualmachines'
        )
        for vm in vms['items']:
            results.append(
                VmInfo(ns.metadata.name, vm['metadata']['name'], vm['status']['printableStatus']))
    return results


def list_vmis() -> List[VmInfo]:
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


def start_vm(vm: VmInfo):
    api = client.ApiClient()
    resource_path = f'/apis/subresources.kubevirt.io/v1alpha3/namespaces/{vm.namespace}/virtualmachines/{vm.name}/start'

    auth_settings = ['BearerToken']

    api.call_api(
        resource_path, 'PUT',
        auth_settings=auth_settings,
    )


def stop_vmi(vm: VmInfo):
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

    args = sys.argv
    if len(args) != 2 or not args[1] in ('list', 'start', 'stop'):
        print(f'usage: kubevirt-graceful-shutdown list|start|stop')
        exit(2)
    action = args[1]

    vms = list_vms()
    vmis = list_vmis()

    if action == 'start':
        for vm in vms:
            if vm.status != 'Stopped':
                continue
            print(f'starting {vm.name}')
            start_vm(vm)
    elif action == 'stop':
        for vm in vmis:
            print(f'stopping {vm.name}')
            stop_vmi(vm)
        wait_until_stopped()
    elif action == 'list':
        for vm in vms:
            print(f'vm       {vm.namespace}/{vm.name}: {vm.status}')
        for vmi in vms:
            print(f'instance {vmi.namespace}/{vmi.name}: {vmi.status}')


if __name__ == '__main__':
    main()

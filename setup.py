from setuptools import setup, find_packages

setup(
    name='kubevirt-graceful-shutdown',
    version='0.1.0',
    packages=find_packages(
        include=['kubevirt_graceful_shutdown', 'kubevirt_graceful_shutdown.*']),
    install_requires=[
        'kubernetes',
    ],
    entry_points={
        'console_scripts': ['kubevirt-graceful-shutdown=kubevirt_graceful_shutdown.app:main']
    }
)

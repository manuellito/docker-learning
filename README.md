# Deep learning environment development

Deep learning is something extraordinary.
However, the installation is heavy and can quickly become a problem... If you also use different machines, it can quickly become a nightmare.

Testing different tools requires quite different environments for a short period of time.

This tool allows you to generate a Docker environment with Jupyter, either for your developments or for your tests.
Each container can be easily configured, created and deleted.

Tools installed:
 - Jupyter
 - Tensorflow
 - Opencv
 - Tensorflow models (Object recognition)

It is possible to specify a version, or to choose the last or latest of a major version.

## Requirements

  - PyYAML
  - bs4
  - lxml
  - GithubVersionManager (https://github.com/manuellito/GithubVersionManager). The path should be include in PYTHONPATH environment variable

## Use it
You can start it as a contener:
  - User is 'icare'
  - Expose port is '8888'
  - Workdir is '/home/icare/work'
  - For CUDA support use '--gpus all' option

Specify modules and versop,in file __Dockerfile-config.yaml__

You can configure Jupyter's plugin and aspect at the end of __Dockerfile.tpl__ file

## Restrictions

At this time, GithubVersionManager doesn't manage branches, only release. However, the script use git in order to get Tensorflow from source.
It must use specific version for checkout the correct branch. 
GithubVersionManager will be update later in order to manage branches.

Only Tensorflow from 2.2 supports CUDA 10.2


## Examples

Some Dockerfiles are provided in 'generated' folder:
  - Dockerfile_tf2.0_cv4.3.0_cuda10.1
  - Dockerfile_tf2.0_cv4.3.0_nogpus
  - Dockerfile_tf2.2_cv4.3.0_cuda10.1
  - Dockerfile_tf2.2_cv4.3.0_cuda10.2
  - Dockerfile_tf2.2_cv4.3.0_nogpus
  - Dockerfile_pytorch1.8.0_cuda10.2
  - Dockerfile_pytorch1.8.0_nogpus

# Readmap

- ~~Pytorch~~
- Yolo v4 integration
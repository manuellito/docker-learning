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
  - GithubVersionManager (https://github.com/manuellito/GithubVersionManager). The path should be include in PYTHONPATH environment variable

## Use it
You can start it as a contener:
  - User is 'icare'
  - expose port is '8888'
  - workdir is '/home/icare/work'

Specify modules and versop,in file __Dockerfile-config.yaml__

You can configure Jupyter's plugin and aspect at the end of __Dockerfile.tpl__ file

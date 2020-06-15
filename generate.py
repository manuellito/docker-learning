import os
from pathlib import  Path 
import re
import yaml
import re
import GithubVersionManager.GithubVersionManager as gv

# Declare constants
DOCKERFILE_TEMPLATE = "Dockerfile.tpl"
DOCKERFILE_VALUES = "Dockerfile-values.yaml"
DOCKERFILE_CONFIG = "Dockerfile-config.yaml"
DOCKERFILE = "Dockerfile"
CONFIG_TO_IGNORE = ["enable", "params"]
# For now, parameters work only with this pattern
#   {blabla{parameter}}
PATTERN_PARAMS_COMMAND = "(\{\S*)(\{\S*\})(\}.*)"
PATTERN_BLANK = r"(\n){2,}"
PATTERN_DOUBLE_USER = r"USER (\w+)\s*USER (\w+)"


current_path = str(Path().absolute())

# Load files
dockerfile_values = open(current_path + os.path.sep + DOCKERFILE_VALUES, "r").read()
data = yaml.full_load(dockerfile_values)

dockerfile_template = open(current_path + os.path.sep + DOCKERFILE_TEMPLATE, "r").read()
dockerfile_config = yaml.full_load(open(current_path + os.path.sep + DOCKERFILE_CONFIG, "r").read())

dockerfile_output = open(current_path + os.path.sep + DOCKERFILE, "w")

tensorflow_version = gv.GithubVersionManager("tensorflow", "tensorflow")
tensorflow_version.get_versions()
opencv_version = gv.GithubVersionManager("opencv", "opencv")
opencv_version.get_versions()
versions_list = {"tensorflow": tensorflow_version, "opencv": opencv_version}

def generate_config_file(dockerfile_template, dockerfile_config):
    """ 
        Generate a Docker from a config file which specify what to install and which version

        :param dockerfile_template: The dockerfile template
        :param dockerfile_config: Config values in order to build the dockerfile
        :type dockerfile_template: String
        :type dockerfile_config: String
        :return: The generated dockerfile
        :rtype: String
      """
    for section in data:
        # Disabled sections which are not enabled in config file
        if "enable" in dockerfile_config[section].keys() and dockerfile_config[section]["enable"] == False:
            for command in data[section]:
                dockerfile_template = replace_in_template(dockerfile_template, f"{section}_{command}", "")
        else:
            # Step 1: Get params if there are
            if "params" in dockerfile_config[section]:
                params = dockerfile_config[section]["params"]
            # Prepare pattern
            pattern = re.compile(PATTERN_PARAMS_COMMAND)
            # Step 2: Replace command by its value
            for command in data[section] :
                # Do not install the command if it's value in config file its value is "False"
                if command in dockerfile_config[section].keys() and  dockerfile_config[section][command] == False   :
                    dockerfile_template = replace_in_template(dockerfile_template, f"{section}_{command}", "")
                else:
                    command_value = data[section][command]
                    #It is possible there are several parameter in a command string
                    while True:                    
                        parameters_in_command = pattern.search(command_value) 
                        #The paramter {param} return 2 tokens
                        if parameters_in_command and len(parameters_in_command.groups()) > 2:
                            # The slicing if for delete {} of the parameter
                            print(f"commande avant:\n{command_value}")
                            parameter_value = params[parameters_in_command.group(2)[1:-1]]
                            command_value = pattern.sub(f"\g<1>{parameter_value}\g<3>", command_value) 
                            print(f"commande après:\n{command_value}")
                        else:
                            break
                    dockerfile_template = replace_in_template(dockerfile_template, f"{section}_{command}", command_value)
        dockerfile_template = replace_section_variables(dockerfile_template, dockerfile_config, section)
    return clean_dockerfile(dockerfile_template)

def replace_in_template(template, install_command_name, install_command):
    """ 
        Insert command into template Dockerfile

        :param template: The dockerfile template
        :param install_command_name: Command name to replace in Dockerfile template
        :param install_command: Command value to replace in Dockerfile template
        :type template: String
        :type install_command_name: String
        :type install_command: String
        :return: The generated dockerfile with command replacement
        :rtype: String
    """
    install_command_name_to_replace = f"{{{install_command_name}}}"
    template = template.replace(install_command_name_to_replace, install_command)
    return template

def replace_section_variables(template_file, config_file, section):
    """ 
        Replace values in commands for each ection

        :param template_file: The dockerfile template
        :param config_file: Config file whick contains values replacement
        :param section: Section for which the variables are to be replace
        :type template_file: String
        :type config_file: String
        :type section: String
        :return: The generated dockerfile with variables replacement for one section
        :rtype: String
    """
    if section in config_file.keys():
        for variable in config_file[section]:
            variable_name = f"{{{section}_{variable}}}"
            # We're checking if the variable we're interested in
            if variable in CONFIG_TO_IGNORE:
                continue
            # We manage the versions differently
            if variable_name == f"{{{section}_type_version}}":
                version_type = config_file[section]["type_version"]
                if version_type == "lastest":
                    value = versions_list[section].get_lastest_version()
                elif version_type == "major":
                    value = str(versions_list[section].get_last_major_version(str(config_file[section]["version"])))          
                else:
                    value = config_file[section]["version"]
                # Update the version
                variable_name = f"{{{section}_version}}"
            else:
                value = config_file[section][variable]
            if value is not None:
                # Only str or int variable. Ignore bool values for instance
                if not isinstance(value, bool):
                    template_file = template_file.replace(variable_name, str(value))
    return template_file

def clean_dockerfile(dockerfile):
    """ 
        Clean the dockerfile with some templates

        :param dockerfile: The dockerfile to clean
        :type dockerfile: String
        :return: The cleaned dockerfile 
        :rtype: String
    """
    while True:
        pattern = re.compile(PATTERN_DOUBLE_USER)
        groups = pattern.search(dockerfile)
        if groups == None:
            break
        if groups.group(1) == groups.group(2):
            dockerfile = pattern.sub(r"USER \g<1>", dockerfile)
    pattern = re.compile(PATTERN_BLANK)
    dockerfile = pattern.sub("\n\n", dockerfile)

    return dockerfile


dockerfile_template = generate_config_file(dockerfile_template, dockerfile_config)

dockerfile_output.write(dockerfile_template)
dockerfile_output.close()


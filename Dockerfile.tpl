ARG BASE_CONTAINER=ubuntu:bionic-20200112@sha256:bc025862c3e8ec4a8754ea4756e33da6c41cba38330d7e324abd25c8e0b93300
FROM $BASE_CONTAINER

# Build on Jupyter stack

LABEL maintainer="Emmanuel Farcy <manu.farcy@gmail.com>"

ARG NB_USER="icare"
ARG NB_UID="1000"
ARG NB_GID="100"

USER root

# Install all OS dependencies for notebook server that starts but lacks all
# features (e.g., download as all possible file formats)

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && \
    apt-get upgrade -yq && \
    apt-get install -yq --no-install-recommends \
    wget \
    bzip2 \
    ca-certificates \
    sudo \
    locales \
    fonts-liberation \
    run-one \
    git \
    jed \
    libsm6 \
    libxext-dev \
    libxrender1 \ 
    lmodern \ 
    netcat \
    pandoc \ 
    python-dev \
    tzdata \
    nano \
    g++ \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen

# Configure environment
ENV CONDA_DIR=/opt/conda \
    SHELL=/bin/bash \
    NB_USER=$NB_USER \
    NB_UID=$NB_UID \
    NB_GID=$NB_GID \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8
ENV PATH=$CONDA_DIR/bin:$PATH \
    HOME=/home/$NB_USER \
    DL_LIBS=/home/$NB_USER/libs

RUN echo $DL_LIBS

# Add a script that we will use to correct permissions after running certain commands
ADD fix-permissions /usr/local/bin/fix-permissions
RUN chmod a+rx /usr/local/bin/fix-permissions

# Enable prompt color in the skeleton .bashrc before creating the default NB_USER
RUN sed -i 's/^#force_color_prompt=yes/force_color_prompt=yes/' /etc/skel/.bashrc


# Create NB_USER wtih name icare user with UID=1000 and in the 'users' group
# and make sure these dirs are writable by the `users` group.
RUN echo "auth requisite pam_deny.so" >> /etc/pam.d/su && \
    sed -i.bak -e 's/^%admin/#%admin/' /etc/sudoers && \
    sed -i.bak -e 's/^%sudo/#%sudo/' /etc/sudoers && \
    useradd -m -s /bin/bash -N -u $NB_UID $NB_USER && \
    mkdir -p $CONDA_DIR && \
    chown $NB_USER:$NB_GID $CONDA_DIR && \
    chmod g+w /etc/passwd && \
    fix-permissions $HOME && \
    fix-permissions "$(dirname $CONDA_DIR)"

USER $NB_UID
ARG PYTHON_VERSION=default

# Setup work directory for backward-compatibility
RUN mkdir $HOME/work && \
    fix-permissions /home/$NB_USER

# Install conda as jovyan and check the md5 sum provided on the download site
ENV MINICONDA_VERSION=4.7.12.1 \
    MINICONDA_MD5=81c773ff87af5cfac79ab862942ab6b3 \
    CONDA_VERSION=4.7.12 

RUN cd /tmp && \
    wget --quiet https://repo.continuum.io/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    echo "${MINICONDA_MD5} *Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh" | md5sum -c - && \
    /bin/bash Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh -f -b -p $CONDA_DIR && \
    rm Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    echo "conda ${CONDA_VERSION}" >> $CONDA_DIR/conda-meta/pinned && \
    conda config --system --prepend channels conda-forge && \
    conda config --system --set auto_update_conda false && \
    conda config --system --set show_channel_urls true && \
    if [ ! $PYTHON_VERSION = 'default' ]; then conda install --yes python=$PYTHON_VERSION; fi && \
    conda list python | grep '^python ' | tr -s ' ' | cut -d '.' -f 1,2 | sed 's/$/.*/' >> $CONDA_DIR/conda-meta/pinned && \
    conda install --quiet --yes conda && \    
    conda install --quiet --yes pip && \ 
    conda update --all --quiet --yes && \
    conda clean --all -f -y && \ 
    rm -rf /home/$NB_USER/.cache/yarn && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# Install Tini 
RUN conda install --quiet --yes 'tini=0.18.0' && \
    conda list tini | grep tini | tr -s ' ' | cut -d ' ' -f 1,2 >> $CONDA_DIR/conda-meta/pinned && \
    conda clean --all -f -y && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# Install Jupyter Notebook, Lab, and Hub
# Generate a notebook server config
# Cleanup temporary files
# Correct permissions
# Do all this in a single RUN command to avoid duplicating all of the
# files across image layers when the permissions change
RUN conda install --quiet --yes \
    'notebook=6.0.3' \
    'jupyterhub=1.1.0' \ 
    'jupyterlab=1.2.5' \ 
    'jupyter_dashboards' \
    # Install Python 3 packages
    'beautifulsoup4=4.8.*' \
    'conda-forge::blas=*=openblas' \
    'bokeh=1.4*' \
    'cloudpickle=1.2*' \
    'cython=0.29*' \
    'dask=2.9.*' \
    'dill=0.3*' \
    'h5py=2.10*' \
    'hdf5=1.10*' \
    'ipywidgets=7.5*' \
    'matplotlib-base=3.1.*' \
    'numba=0.45*' \
    'numexpr=2.6*' \
    'pandas=0.25*' \
    'patsy=0.5*' \
    'protobuf=3.9.*' \
    'scikit-image=0.15*' \
    'scikit-learn=0.21*' \
    'scipy=1.3*' \
    'seaborn=0.9*' \
    'sqlalchemy=1.3*' \
    'statsmodels=0.10*' \
    'sympy=1.4*' \
    'vincent=0.4.*' \
    'xlrd' \
    'jupyterthemes' \
    'qgrid' \
    # contrib extensions for jupyter
    'jupyter_contrib_nbextensions' \
    && \    
    conda clean --all -f -y && \
    # Activate ipywidgets extension in the environment that runs the notebook server
    jupyter nbextension enable --py widgetsnbextension --sys-prefix && \
    # Also activate ipywidgets extension for JupyterLab
    # Check this URL for most recent compatibilities
    # https://github.com/jupyter-widgets/ipywidgets/tree/master/packages/jupyterlab-manager
    jupyter labextension install @jupyter-widgets/jupyterlab-manager@^1.0.1 --no-build && \
    jupyter labextension install jupyterlab_bokeh@1.0.0 --no-build && \
    jupyter lab build && \    
    # Install contrib extensions for jupyter 
    jupyter contrib nbextension install --user && \
    npm cache clean --force && \
    jupyter notebook --generate-config && \
    rm -rf $CONDA_DIR/share/jupyter/lab/staging && \
    rm -rf /home/$NB_USER/.cache/yarn && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER && \
    mkdir -p /home/icare/libs


# Installation of tensorflow
{tensorflow_command_install}

# Installation opencv
{opencv_command_user_to_root}
# Opencv enviromment creation
{opencv_command_install}

{object_detection_command_user_to_root}
{object_detection_command_install}
{object_detection_command_install_ssd_mobilenet_v1_coco}
{object_detection_command_install_ssd_mobilenet_v1_0.75_depth_coco}
{object_detection_command_install_ssd_mobilenet_v1_quantized_coco}
{object_detection_command_install_ssd_mobilenet_v1_0.75_depth_quantized_coco}
{object_detection_command_install_ssd_mobilenet_v1_ppn_coco}
{object_detection_command_install_ssd_mobilenet_v1_fpn_coco}
{object_detection_command_install_ssd_resnet_50_fpn_coco}
{object_detection_command_install_ssd_mobilenet_v2_coco}
{object_detection_command_install_ssd_mobilenet_v2_quantized_coco}
{object_detection_command_install_ssdlite_mobilenet_v2_coco}
{object_detection_command_install_ssd_inception_v2_coco}
{object_detection_command_install_faster_rcnn_inception_v2_coco}
{object_detection_command_install_faster_rcnn_resnet50_coco}
{object_detection_command_install_faster_rcnn_resnet50_lowproposals_coco}
{object_detection_command_install_rfcn_resnet101_coco}
{object_detection_command_install_faster_rcnn_resnet101_coco}
{object_detection_command_install_faster_rcnn_resnet101_lowproposals_coco}
{object_detection_command_install_faster_rcnn_inception_resnet_v2_atrous_coco}
{object_detection_command_install_faster_rcnn_inception_resnet_v2_atrous_lowproposals_coco}
{object_detection_command_install_faster_rcnn_nas}
{object_detection_command_install_faster_rcnn_nas_lowproposals_coco}
{object_detection_command_install_mask_rcnn_inception_resnet_v2_atrous_coco}
{object_detection_command_install_mask_rcnn_inception_v2_coco}
{object_detection_command_install_mask_rcnn_resnet101_atrous_coco}
{object_detection_command_install_mask_rcnn_resnet50_atrous_coco}
{object_detection_command_install_ssd_mobilenet_v3_large_coco}
{object_detection_command_install_ssd_mobilenet_v3_small_coco}
{object_detection_command_install_ssd_mobilenet_edgetpu_coco}
{object_detection_command_install_faster_rcnn_resnet101_kitti}
{object_detection_command_install_faster_rcnn_inception_resnet_v2_atrous_oidv2}
{object_detection_command_install_faster_rcnn_inception_resnet_v2_atrous_lowproposals_oidv2}
{object_detection_command_install_facessd_mobilenet_v2_quantized_open_image_v4}
{object_detection_command_install_faster_rcnn_inception_resnet_v2_atrous_oidv4}
{object_detection_command_install_ssd_mobilenetv2_oidv4}
{object_detection_command_install_ssd_resnet_101_fpn_oidv4}
{object_detection_command_install_faster_rcnn_resnet101_fgvc}
{object_detection_command_install_faster_rcnn_resnet50_fgvc}
{object_detection_command_install_faster_rcnn_resnet101_ava_v2.1}

EXPOSE 8888

# Configure container startup
ENTRYPOINT ["tini", "-g", "--"]
CMD ["start-notebook.sh"]

# Add local files as late as possible to avoid cache busting
COPY start-notebook.sh /usr/local/bin/
COPY start-singleuser.sh /usr/local/bin/
COPY jupyter_notebook_config.py /etc/jupyter/

# Fix permissions on /etc/jupyter as root
USER root
RUN fix-permissions /etc/jupyter/

USER $NB_UID

WORKDIR $HOME

RUN jupyter nbextension enable hinterland/hinterland


RUN jupyter nbextension enable varInspector/main 
RUN jupyter nbextension enable toc2/main 
RUN jupyter nbextension enable execute_time/ExecuteTime
RUN jupyter nbextension enable addbefore/main
RUN jupyter nbextension enable snippets_menu/main
RUN jupyter nbextension enable collapsible_headings/main
RUN jupyter nbextension enable comment-uncomment/main

RUN jt -t monokai -f fira -fs 13 -nf ptsans -nfs 11 -N -kl -cursw 5 -cursc r -cellw 95% -T


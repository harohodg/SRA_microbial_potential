FROM fluxrm/flux-sched:bookworm

LABEL maintainer="Harold Hodgins"

USER root

# Download Miniconda installer
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-py312_24.11.1-0-Linux-x86_64.sh -O /tmp/miniconda.sh

# Install Miniconda
RUN bash /tmp/miniconda.sh -b -p /opt/miniconda

# Update the PATH environment variable
ENV PATH=/opt/miniconda/bin:$PATH

# Clean up installer
RUN rm /tmp/miniconda.sh

# Install nextflow
RUN conda install bioconda::nextflow=25.04.6

# Clean up apt data
RUN set -ex \  
    && rm -rf /var/lib/apt/lists/*

# Copy the code into the container    
COPY . /opt/SRAminer

# Initialize the cache / conda environments
RUN cd /opt/SRAminer/ \
    && sed -i "s|mode: 'link'|mode: 'copy'|g" /opt/SRAminer/modules/*.nf \
    && ./init_cache.sh
    

# Update the system path
ENV PATH="$PATH:/opt/SRAminer"
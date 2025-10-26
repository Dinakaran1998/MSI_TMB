FROM pengjia1110/msisensor-pro:latest

# Install AWS CLI and htslib
RUN apt-get update && apt-get install -y wget unzip build-essential zlib1g-dev samtools \
    && wget "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -O "awscliv2.zip" \
    && unzip awscliv2.zip && ./aws/install && rm -rf awscliv2.zip aws

# Verify
RUN msisensor-pro --version && samtools --version && aws --version

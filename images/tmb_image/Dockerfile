FROM python:3.11-slim

# Install AWS CLI
RUN apt-get update && apt-get install -y wget unzip gzip && \
    pip install --no-cache-dir awscli

# Copy TMB script
COPY calc_tmb.py /usr/local/bin/calc_tmb.py
RUN chmod +x /usr/local/bin/calc_tmb.py

# Use root to avoid permission issues
USER root

# Default command
CMD ["bash"]

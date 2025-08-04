  FROM python:3.11-slim
  
  ENV DEBIAN_FRONTEND=noninteractive
  ENV PIPX_HOME=/root/.local/pipx
  ENV PATH=/root/.local/bin:\$PIPX_HOME/venvs/impacket/bin:\$PIPX_HOME/venvs/ldapdomaindump/bin:\$PIPX_HOME/venvs/crackmapexec/bin:\$PATH
  
  RUN apt-get update && \\
      apt-get install -y --no-install-recommends \\
          build-essential git gcc libldap2-dev libkrb5-dev libsasl2-dev libssl-dev \\
          python3-dev python3-pip pipx \\
      && apt-get clean && rm -rf /var/lib/apt/lists/*
  
  RUN pip install --no-cache-dir pipx && \
      pipx ensurepath && \
      pipx install autobloody && \
      pipx install git+https://github.com/fortra/impacket.git && \
      pipx install git+https://github.com/Pennyw0rth/NetExec
  
  WORKDIR /loot
  CMD ["/bin/bash"]

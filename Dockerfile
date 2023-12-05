FROM nvcr.io/nvidia/pytorch:23.09-py3

# NOTE: @garrett.goon - Work around Zscalar. Copy the original ca-certificates.crt, append the
# zscalar info to there and point the REQUESTS_CA_BUNDLE env var at this file (needed for pip),
# and at the end reset REQUESTS_CA_BUNDLE.
COPY ZscalerRootCerts/ZscalerRootCertificate-2048-SHA256.crt .
RUN cp /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates_with_zscaler.crt
RUN cat ZscalerRootCertificate-2048-SHA256.crt >> /etc/ssl/certs/ca-certificates_with_zscaler.crt
ENV REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates_with_zscaler.crt

RUN rm -f /etc/apt/sources.list.d/*
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 PIP_NO_CACHE_DIR=1

RUN mkdir -p /var/run/sshd
RUN apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
		autoconf \
		automake \
		autotools-dev \
		build-essential \
		ca-certificates \
		curl \
		daemontools \
		ibverbs-providers \
		libibverbs1 \
		libkrb5-dev \
		librdmacm1 \
		libssl-dev \
		libtool \
        libaio-dev \
        pdsh \
		git \
		krb5-user \
		cmake \
		g++ \
		make \
		openssh-client \
		openssh-server \
		pkg-config \
		wget \
		nfs-common \
		unattended-upgrades \
	&& unattended-upgrade \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm /etc/ssh/ssh_host_ecdsa_key \
	&& rm /etc/ssh/ssh_host_ed25519_key \
	&& rm /etc/ssh/ssh_host_rsa_key


COPY dockerfile_scripts /tmp/det_dockerfile_scripts
RUN /tmp/det_dockerfile_scripts/install_google_cloud_sdk.sh


# Install determined dependencies
RUN /tmp/det_dockerfile_scripts/add_det_nobody_user.sh
RUN /tmp/det_dockerfile_scripts/install_libnss_determined.sh

# We uninstall these packages after installing. This ensures that we can
# successfully install these packages into containers running as non-root.
# `pip` does not uninstall dependencies, so we still have all the dependencies
# installed.
ARG DET_VERSION
RUN python -m pip install determined==0.26.2 && python -m pip uninstall -y determined

# Make sure environment works with our notebooks.
RUN python -m pip install -r /tmp/det_dockerfile_scripts/notebook-requirements.txt
ENV JUPYTER_CONFIG_DIR=/run/determined/jupyter/config
ENV JUPYTER_DATA_DIR=/run/determined/jupyter/data
ENV JUPYTER_RUNTIME_DIR=/run/determined/jupyter/runtime

# Make sure permissions are okay for nonroot and cleanup.
RUN rm -r /tmp/*
# LL_NOTE: need to figure out why nvidia sets user to 1000 for the ngc container
# that we are building from and whether there are any issues to us not doing the same
# when building this container.
RUN chown root /usr/lib && chgrp root /usr/lib


# Unset the env var for zscalar and delete.
# NOTE: @garrett.goon - RUN unset ... is _not_ the right thing to do: https://stackoverflow.com/questions/55789409/how-to-unset-env-in-dockerfile
ENV REQUESTS_CA_BUNDLE=
RUN rm /etc/ssl/certs/ca-certificates_with_zscaler.crt


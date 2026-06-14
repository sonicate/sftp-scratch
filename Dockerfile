FROM almalinux:9-minimal

# Packages:
#   openssh-server : sshd + the internal-sftp subsystem
#   openssh        : ssh-keygen (host-key generation at runtime)
#   shadow-utils   : useradd/usermod/groupadd/chpasswd (not in the minimal base)
# bash and getent (glibc-common) are already present in the minimal base.
RUN microdnf makecache \
    && microdnf upgrade -y \
    && microdnf install -y openssh-server openssh shadow-utils \
    && microdnf clean all \
    && mkdir -p /var/run/sshd /etc/sftp.d \
    && rm -f /etc/ssh/ssh_host_*_key*

COPY files/sshd_config /etc/ssh/sshd_config
COPY files/create-sftp-user /usr/local/bin/create-sftp-user
COPY files/entrypoint /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/create-sftp-user /usr/local/bin/entrypoint

EXPOSE 22

ENTRYPOINT ["/usr/local/bin/entrypoint"]

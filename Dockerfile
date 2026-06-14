FROM alpine:3.21

# Packages:
#   openssh-server : sshd, the internal-sftp subsystem, and ssh-keygen
#   shadow         : full useradd/usermod/groupadd/chpasswd (BusyBox's are too limited)
#   bash           : entrypoint and create-sftp-user rely on bash regex + arrays
RUN apk add --no-cache bash openssh-server shadow \
    && mkdir -p /var/run/sshd /etc/sftp.d \
    && rm -f /etc/ssh/ssh_host_*_key*

COPY files/sshd_config /etc/ssh/sshd_config
COPY files/create-sftp-user /usr/local/bin/create-sftp-user
COPY files/entrypoint /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/create-sftp-user /usr/local/bin/entrypoint

EXPOSE 22

ENTRYPOINT ["/usr/local/bin/entrypoint"]

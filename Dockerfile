FROM mcchae/sshd-x
MAINTAINER MoonChang Chae mcchae@gmail.com
LABEL Description="alpine desktop env over xfce with novnc, xrdp and openssh server"

ENV LANG=ko_KR.UTF-8 \
    LANGUAGE=ko_KR.UTF-8 \
    LC_CTYPE=ko_KR.UTF-8 \
    LC_ALL=ko_KR.UTF-8

# ADD chroot  /
ADD chroot/tmp /tmp
RUN cp /tmp/apk/.abuild/-57cfc5fa.rsa.pub /etc/apk/keys

# to suppress: so:libcrypto.so.1.0.0 (missing):
RUN cp -f /etc/apk/repositories /etc/apk/repositories.org \
    && echo 'http://dl-cdn.alpinelinux.org/alpine/v3.8/main' >> /etc/apk/repositories \
    && apk add libssl1.0

# for hangul using uim from source
WORKDIR /tmp/src
RUN apk --update add --virtual build-dependencies \
        alpine-sdk  gtk+2.0-dev gtk+3.0-dev \
    && tar xvfj uim-1.8.6.tar.bz2 \
    && cd uim-1.8.6 \
    &&    ./configure --prefix=/usr \
    &&    make \
    &&    make install \
    && cd .. \
    && apk del build-dependencies

WORKDIR /
RUN apk --update --no-cache add \
        vim git \
        xrdp xvfb xfce4 slim \
        xf86-input-synaptics xf86-input-mouse xf86-input-keyboard \
        setxkbmap sudo util-linux dbus udev xauth supervisor \
        firefox-esr \
        wget curl tmux \
    && rm -f /usr/bin/vi && ln -s /usr/bin/vim /usr/bin/vi \
    && apk add /tmp/apk/ossp-uuid-1.6.2-r0.apk \
    && apk add /tmp/apk/ossp-uuid-dev-1.6.2-r0.apk \
    && apk add /tmp/apk/x11vnc-0.9.13-r0.apk \
    && cp -f /tmp/bin/tini-static-amd64 /bin/tini \
    && chmod  +x /bin/tini \
    && rm -rf /tmp/* /var/cache/apk/*

ADD chroot/etc /etc
ADD chroot/usr /usr

## if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
#ENV PYTHON_PIP_VERSION 9.0.1
ENV PYTHON_PIP_VERSION 19.1.1
RUN set -ex; \
    apk add --no-cache --virtual .fetch-deps libressl; \
    wget -O get-pip.py 'https://bootstrap.pypa.io/get-pip.py'; \
    apk del .fetch-deps; \
    python get-pip.py \
        --disable-pip-version-check \
        --no-cache-dir \
        "pip==$PYTHON_PIP_VERSION" \
    ; \
    pip --version; \
    find /usr/local -depth \
        \( \
            \( -type d -a \( -name test -o -name tests \) \) \
            -o \
            \( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
        \) -exec rm -rf '{}' +; \
    rm -f get-pip.py
RUN pip install virtualenv

RUN for ic in `find /usr/share/icons/* -type d -maxdepth 0`;do gtk-update-icon-cache -ft $ic; done

RUN xrdp-keygen xrdp auto
RUN sed -i '/TerminalServerUsers/d' /etc/xrdp/sesman.ini \
    && sed -i '/TerminalServerAdmins/d' /etc/xrdp/sesman.ini

EXPOSE 3389 22

# ADD chroot  /
WORKDIR /
# Todo: next is for nginx proxy setting for noVNC but does not work for now
# RUN apk --update --no-cache add \
#         nginx \
#     && rm -rf /tmp/* /var/cache/apk/*


RUN mv -f /etc/apk/repositories.org /etc/apk/repositories \
    && apk --update add --virtual build-dependencies \
        python-dev build-base linux-headers \
    && pip install setuptools wheel && pip install -r /usr/lib/web/requirements.txt \
    && apk del build-dependencies \
    && apk --update add grep

RUN sed -i -e 's/\/ash/\/bash/g' /etc/passwd

EXPOSE 6081

ADD chroot/startup.sh /
ENTRYPOINT ["bash", "/startup.sh"]

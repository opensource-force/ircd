FROM archlinux

RUN pacman -Sy --noconfirm gcc nim

WORKDIR /

COPY ./src/ ./

RUN nim --hints:off -d:danger --app:console c /irc.nim

CMD ["/osfircd"]
FROM archlinux

RUN pacman -Sy --noconfirm gcc nim

WORKDIR /

COPY src/ ./src
COPY osfircd.nim ./

RUN nim --hints:off -d:danger --app:console c /osfircd.nim

EXPOSE 6667

CMD ["/osfircd"]

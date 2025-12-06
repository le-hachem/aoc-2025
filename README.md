# Advent of Code - 2025
Yes, I started late.
Yes, I wrote it in x86_64 assembly.
No, there is no absolutely no good reason for this.
No, I'm not okay.

### Why assembly?
Because I was really bored and I wanted more of an excuse to procrastinate.

also: **aura**.

## Building & Running
```sh
$ make run-day[1-12]
# example:
$ make run-day1
$ make run-day2
```
If you just want to build the binaries without running them do `make day[1-12]`.

## Docker
If you do not have `nasm`/`ld` locally, build the container:
```sh
$ docker build -t aoc-2025 .
```
Run a specific puzzle directly
```sh
$ docker run aoc-2025 day4
$ docker run aoc-2025 day5
```
Running with no arguments (`docker run aoc-2025`) will list the available targets. If you only want to build a binary, use `build-day[1-12]`.
When you're done, delete the image:
```sh
$ docker rmi aoc-2025
```

## License
[MIT](LICENSE), because you want this code, you need more help than permission.

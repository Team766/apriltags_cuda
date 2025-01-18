# Camerascanner
A helper function by Segen to read the serial number of a camera and the index 0 id of the camera as the /dev/video device. It is structured as ${serial}:${videoid}.

## building
```bash
go build -o scanner_${arch} main
```
To just run the file:
```bash
go run main
```

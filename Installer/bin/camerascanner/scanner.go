package main

import (
	"fmt"
	"os/exec"
	"strings"
	//"log"
)

func main() {
	out, err := exec.Command("ls", "-l", "/dev/v4l/by-id/").Output()
	if err != nil {}

	devices := strings.Split(string(out), "lrwxr")
	devices = devices[1:]

	var sNums []string
	serial := ""

	for _, e := range devices {
		start := strings.Index(e, "Camera") + 5
		for j := 2; j < 100; j++ {
			if string(e[strings.Index(e, "index") + 5]) == "1" {
				break
			}
			if string(e[start + j]) == "-" {
				sNums = append(sNums, serial + ":" + string(e[len(e) - 2]))
				serial = ""
				break
			} else {
				serial += string(e[start + j])
			}
		}
	}
	fmt.Print(sNums)

}

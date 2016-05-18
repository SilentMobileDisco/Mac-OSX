#!/bin/bash

gcc -Wall server-alsasrc-PCMA.c -o server $(pkg-config --cflags --libs gstreamer-1.0) -lgstnet-1.0

gcc -Wall client-PCMA.c -o client $(pkg-config --cflags --libs gstreamer-1.0) -lgstnet-1.0

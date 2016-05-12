MULTICAST_IP_ADDR=224.1.1.1
AUDIO_UDP_PORT=3000

gst-launch-1.0 udpsrc address=$MULTICAST_IP_ADDR auto-multicast=true port=$AUDIO_UDP_PORT \
caps="application/x-rtp" ! \
queue ! rtppcmadepay ! alawdec ! audioconvert! autoaudiosink


# gst-launch udpsrc port=5555 caps="application/x-rtp" ! queue ! rtppcmudepay ! mulawdec ! audioconvert ! alsasink